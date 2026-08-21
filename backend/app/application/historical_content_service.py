from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import func, select

from app.domain.errors import FragmentOperationError
from app.domain.historical_content import can_transition, publication_blockers
from app.infrastructure.persistence.models import (
    ClaimSourceModel,
    FragmentClaimModel,
    HistoricalClaimModel,
    HistoricalSourceModel,
    StoryArcModel,
    StoryFragmentModel,
)


class HistoricalContentService:
    def __init__(self, session_factory):
        self.session_factory = session_factory

    def claim_traceability(self, claim_id: str) -> dict:
        with self.session_factory() as session:
            claim = session.get(HistoricalClaimModel, claim_id)
            if claim is None:
                raise FragmentOperationError("claim_not_found", "史实条目不存在", status_code=404)
            sources = list(
                session.scalars(
                    select(HistoricalSourceModel)
                    .join(ClaimSourceModel, ClaimSourceModel.source_id == HistoricalSourceModel.id)
                    .where(ClaimSourceModel.claim_id == claim_id)
                )
            )
            return {
                "claim": claim.canonical_text,
                "certainty": claim.certainty,
                "review_state": claim.review_state,
                "boundary_note": claim.boundary_note,
                "sources": [{"title": item.title, "url": item.url} for item in sources],
            }

    def transition_claim(self, claim_id: str, target: str, reviewer: str) -> None:
        with self.session_factory() as session:
            claim = session.get(HistoricalClaimModel, claim_id)
            if claim is None:
                raise FragmentOperationError("claim_not_found", "史实条目不存在", status_code=404)
            if not can_transition(claim.review_state, target):
                raise FragmentOperationError("review_transition_invalid", "不允许该审查状态转换")
            if target == "reviewed":
                source_count = session.scalar(
                    select(func.count(ClaimSourceModel.id)).where(
                        ClaimSourceModel.claim_id == claim_id
                    )
                )
                if not source_count:
                    raise FragmentOperationError(
                        "claim_source_missing", "没有来源的史实不能通过审核"
                    )
            claim.review_state = target
            claim.reviewed_by = reviewer
            claim.reviewed_at = datetime.now(UTC)
            session.commit()

    def supersede_claim(self, old_claim_id: str, new_claim: HistoricalClaimModel) -> None:
        with self.session_factory() as session:
            old = session.get(HistoricalClaimModel, old_claim_id)
            if old is None:
                raise FragmentOperationError("claim_not_found", "史实条目不存在", status_code=404)
            new_claim.supersedes_claim_id = old.id
            old.review_state = "retired"
            session.add(new_claim)
            session.commit()

    def publication_report(self, arc_id: str) -> dict:
        with self.session_factory() as session:
            arc = session.get(StoryArcModel, arc_id)
            if arc is None:
                raise FragmentOperationError(
                    "story_arc_not_found", "故事主线不存在", status_code=404
                )
            fragments = list(
                session.scalars(
                    select(StoryFragmentModel).where(StoryFragmentModel.arc_id == arc_id)
                )
            )
            claims = list(
                session.scalars(
                    select(HistoricalClaimModel)
                    .join(
                        FragmentClaimModel, FragmentClaimModel.claim_id == HistoricalClaimModel.id
                    )
                    .where(FragmentClaimModel.fragment_id.in_([item.id for item in fragments]))
                    .distinct()
                )
            )
            source_counts = [
                session.scalar(
                    select(func.count(ClaimSourceModel.id)).where(
                        ClaimSourceModel.claim_id == claim.id
                    )
                )
                or 0
                for claim in claims
            ]
            blockers = publication_blockers(
                arc_review_state=arc.review_state,
                field_audit_state=arc.field_audit_state,
                claim_states=[item.review_state for item in claims],
                source_counts=source_counts,
                fragment_states=[item.review_state for item in fragments],
                asset_sizes=[item.audio_size_bytes for item in fragments],
                transcript_matches=[item.transcript == item.narration_script for item in fragments],
            )
            return {"publication_ready": not blockers, "blockers": blockers}
