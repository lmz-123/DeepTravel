from __future__ import annotations

import hashlib
from datetime import UTC, datetime, timedelta
from pathlib import Path
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.domain.content_graph import (
    normalize_experience_tags,
    normalize_reconstruction_items,
    reconstruction_ids,
    shuffled_reconstruction_items,
)
from app.domain.errors import FragmentOperationError, JourneyNotFoundError
from app.domain.fragment_rules import evaluate_trigger, playback_state, reconstruction_feedback
from app.infrastructure.persistence.models import (
    ActiveTourModel,
    ClaimSourceModel,
    EvidenceModel,
    FragmentClaimModel,
    FragmentDependencyModel,
    FragmentNarrationTrackModel,
    HistoricalClaimModel,
    HistoricalSourceModel,
    IdempotencyRecordModel,
    JourneyFragmentModel,
    JourneyModel,
    MediaAssetModel,
    NarrationVoiceProfileModel,
    PhotoMissionModel,
    ReconstructionModel,
    RouteModel,
    StoryArcModel,
    StoryFragmentModel,
    TriggerRegionModel,
)


def _iso(value: datetime | None) -> str | None:
    return value.isoformat() if value else None


def _is_expired(value: datetime) -> bool:
    expires_at = value if value.tzinfo else value.replace(tzinfo=UTC)
    return expires_at <= datetime.now(UTC)


class FragmentTourService:
    def __init__(
        self,
        session_factory,
        evidence_storage,
        *,
        enabled: bool,
        allow_demo: bool,
        evidence_enabled: bool,
        evidence_retention_days: int,
        media_root: str,
        asset_url_builder,
    ):
        self.session_factory = session_factory
        self.evidence_storage = evidence_storage
        self.enabled = enabled
        self.allow_demo = allow_demo
        self.evidence_enabled = evidence_enabled
        self.evidence_retention_days = evidence_retention_days
        self.media_root = Path(media_root)
        self.asset_url_builder = asset_url_builder

    def _session(self) -> Session:
        return self.session_factory()

    def public_manifest(self, route_id: str) -> dict | None:
        if not self.enabled:
            return None
        with self._session() as session:
            arc = session.scalar(
                select(StoryArcModel)
                .where(StoryArcModel.route_id == route_id)
                .options(
                    selectinload(StoryArcModel.fragments).joinedload(
                        StoryFragmentModel.trigger_region
                    ),
                    selectinload(StoryArcModel.fragments).joinedload(
                        StoryFragmentModel.photo_mission
                    ),
                )
            )
            if arc is None:
                return None
            dependency_rows = session.execute(
                select(
                    FragmentDependencyModel.fragment_id,
                    FragmentDependencyModel.required_fragment_id,
                ).where(
                    FragmentDependencyModel.fragment_id.in_([item.id for item in arc.fragments])
                )
            ).all()
            dependency_map: dict[str, list[str]] = {}
            for fragment_id, required_id in dependency_rows:
                dependency_map.setdefault(fragment_id, []).append(required_id)
            narration = self._narration_context(session, arc)
            fragments = [
                {
                    **self._public_fragment(item, session, narration),
                    "dependency_ids": dependency_map.get(item.id, []),
                }
                for item in arc.fragments
            ]
            total_bytes = sum(item.audio_size_bytes for item in arc.fragments)
            assets_exist = all(
                self._asset_exists(session, item.audio_path) for item in arc.fragments
            )
            production_ready = (
                arc.review_state == "reviewed"
                and arc.field_audit_state == "reviewed"
                and assets_exist
                and all(item.review_state == "reviewed" for item in arc.fragments)
            )
            return {
                "capability": "fragment_audio_tour_v1",
                "title": arc.title,
                "central_question": arc.central_question,
                "script_version": arc.script_version,
                "review_state": arc.review_state,
                "field_audit_state": arc.field_audit_state,
                "production_ready": production_ready,
                "demo_label": "研究预览 · 史实与现场关系待人工复核"
                if not production_ready
                else None,
                "content_method": (
                    "事实、编辑推断与现场解释分层标注；每段线索关联政府或博物馆来源。"
                ),
                "fictional_framing": False,
                "supports": {
                    "hands_free": True,
                    "offline_preparation": True,
                    "photo_missions": True,
                    "background_location": True,
                },
                "permissions": ["location_always", "notifications", "camera"],
                "download_size_bytes": total_bytes,
                "default_narration_profile_id": narration["default_profile_id"],
                "narration_profiles": narration["profiles"],
                "fragment_count": len(fragments),
                "photo_mission_count": sum(
                    1 for item in arc.fragments if item.photo_mission is not None
                ),
                "fragments": fragments,
            }

    def initialize_journey(self, journey_id: str, route_id: str) -> None:
        if not self.enabled:
            return
        with self._session() as session:
            arc = session.scalar(
                select(StoryArcModel)
                .where(StoryArcModel.route_id == route_id)
                .options(selectinload(StoryArcModel.fragments))
            )
            if arc is None:
                return
            existing_ids = set(
                session.scalars(
                    select(JourneyFragmentModel.fragment_id).where(
                        JourneyFragmentModel.journey_id == journey_id
                    )
                )
            )
            for fragment in arc.fragments:
                if fragment.id not in existing_ids:
                    session.add(
                        JourneyFragmentModel(
                            id=str(uuid4()),
                            journey_id=journey_id,
                            fragment_id=fragment.id,
                            state="undiscovered",
                            playback_progress=0.0,
                        )
                    )
            session.commit()

    def start_active_tour(self, user_id: str, journey_id: str) -> dict:
        with self._session() as session:
            journey = self._owned_journey(session, user_id, journey_id)
            now = datetime.now(UTC)
            active = session.get(ActiveTourModel, journey_id)
            if active is None:
                active = ActiveTourModel(
                    journey_id=journey_id, status="monitoring", started_at=now, updated_at=now
                )
                session.add(active)
            else:
                active.status = "monitoring"
                active.updated_at = now
            session.commit()
            return {
                "journey_id": journey.id,
                "status": active.status,
                "started_at": _iso(active.started_at),
                "updated_at": _iso(active.updated_at),
            }

    def stop_active_tour(self, user_id: str, journey_id: str) -> dict:
        with self._session() as session:
            self._owned_journey(session, user_id, journey_id)
            active = session.get(ActiveTourModel, journey_id)
            if active is not None:
                active.status = "stopped"
                active.updated_at = datetime.now(UTC)
                session.commit()
            return {"journey_id": journey_id, "status": "stopped"}

    def trigger(self, user_id: str, journey_id: str, fragment_id: str, payload: dict) -> dict:
        key = str(payload.get("idempotency_key") or "")
        if not key:
            raise FragmentOperationError(
                "validation_error", "idempotency_key 为必填字符串", status_code=422
            )
        scope = f"trigger:{journey_id}:{fragment_id}"
        with self._session() as session:
            journey = self._owned_journey(session, user_id, journey_id)
            self._reconcile_optional_photo_states(session, journey_id)
            duplicate = self._idempotent(session, scope, key)
            if duplicate is not None:
                return duplicate
            fragment, state = self._fragment_state(session, journey, fragment_id)
            method = str(payload.get("method") or "location")
            if method == "location":
                route = session.get(RouteModel, journey.route_id)
                if (
                    route is None
                    or route.content_status != "published"
                    or route.published_at is None
                ):
                    raise FragmentOperationError(
                        "fragment_unavailable",
                        "该故事点当前不可用于新的现场触发",
                        status_code=409,
                    )
            if method == "demo":
                dependencies = set(
                    session.scalars(
                        select(FragmentDependencyModel.required_fragment_id).where(
                            FragmentDependencyModel.fragment_id == fragment_id
                        )
                    )
                )
                collected = set(
                    session.scalars(
                        select(JourneyFragmentModel.fragment_id).where(
                            JourneyFragmentModel.journey_id == journey_id,
                            JourneyFragmentModel.state == "collected",
                        )
                    )
                )
                missing = dependencies - collected
                if missing:
                    raise FragmentOperationError(
                        "fragment_locked",
                        "上一段故事尚未收集，请先沿路线寻找前一条线索",
                        details={"missing_count": len(missing)},
                    )
            region = session.scalar(
                select(TriggerRegionModel).where(TriggerRegionModel.fragment_id == fragment_id)
            )
            if region is None:
                raise FragmentOperationError("fragment_locked", "该线索没有可用触发区域")
            decision = evaluate_trigger(
                method=method,
                allow_demo=self.allow_demo,
                latitude=self._float(payload.get("latitude")),
                longitude=self._float(payload.get("longitude")),
                accuracy_m=self._float(payload.get("accuracy_m")),
                region_latitude=region.latitude,
                region_longitude=region.longitude,
                entry_radius_m=region.entry_radius_m,
                max_accuracy_m=region.max_accuracy_m,
            )
            if not decision.accepted:
                messages = {
                    "demo_trigger_disabled": "当前环境未启用演示触发",
                    "location_accuracy_insufficient": "定位精度不足，请走到开阔处稍候",
                    "trigger_too_far": "尚未进入故事触发范围",
                    "location_evidence_required": "需要有效的定位证据",
                }
                status = 403 if decision.code == "demo_trigger_disabled" else 409
                raise FragmentOperationError(
                    decision.code or "trigger_rejected",
                    messages.get(decision.code, "无法触发线索"),
                    status_code=status,
                    details={
                        "distance_m": round(decision.distance_m, 1)
                        if decision.distance_m is not None
                        else None,
                        "max_accuracy_m": region.max_accuracy_m,
                    },
                )
            if state.triggered_at is None:
                state.triggered_at = datetime.now(UTC)
                state.trigger_method = method
                state.state = "triggered"
            response = {
                "fragment": self._revealed_fragment(session, fragment, state),
                "distance_m": round(decision.distance_m, 1)
                if decision.distance_m is not None
                else None,
            }
            self._record_idempotency(session, scope, key, response)
            session.commit()
            return response

    def playback(self, user_id: str, journey_id: str, fragment_id: str, payload: dict) -> dict:
        key = str(payload.get("idempotency_key") or "")
        if not key:
            raise FragmentOperationError(
                "validation_error", "idempotency_key 为必填字符串", status_code=422
            )
        scope = f"playback:{journey_id}:{fragment_id}"
        with self._session() as session:
            journey = self._owned_journey(session, user_id, journey_id)
            duplicate = self._idempotent(session, scope, key)
            if duplicate is not None:
                return duplicate
            fragment, state = self._fragment_state(session, journey, fragment_id)
            if state.triggered_at is None:
                raise FragmentOperationError("fragment_locked", "线索尚未触发")
            progress = min(1.0, max(0.0, float(payload.get("progress", 0.0))))
            now = datetime.now(UTC)
            state.playback_started_at = state.playback_started_at or now
            state.playback_progress = max(state.playback_progress, progress)
            state.state = playback_state(
                fragment.interaction_type, state.playback_progress, fragment.completion_threshold
            )
            if progress >= fragment.completion_threshold:
                state.playback_completed_at = state.playback_completed_at or now
                state.collected_at = state.collected_at or now
            response = {"fragment": self._revealed_fragment(session, fragment, state)}
            self._record_idempotency(session, scope, key, response)
            session.commit()
            return response

    def upload_evidence(
        self,
        user_id: str,
        journey_id: str,
        fragment_id: str,
        file,
        idempotency_key: str,
        captured_at: datetime | None,
    ) -> dict:
        if not self.evidence_enabled:
            raise FragmentOperationError(
                "evidence_upload_disabled", "当前环境未启用照片证据", status_code=503
            )
        with self._session() as session:
            journey = self._owned_journey(session, user_id, journey_id)
            fragment, state = self._fragment_state(session, journey, fragment_id)
            mission = session.scalar(
                select(PhotoMissionModel).where(PhotoMissionModel.fragment_id == fragment_id)
            )
            if mission is None:
                raise FragmentOperationError(
                    "evidence_invalid", "该线索没有拍照任务", status_code=422
                )
            duplicate = session.scalar(
                select(EvidenceModel).where(
                    EvidenceModel.journey_id == journey_id,
                    EvidenceModel.idempotency_key == idempotency_key,
                    EvidenceModel.deleted_at.is_(None),
                )
            )
            if duplicate:
                return self._evidence_dict(duplicate)
            if state.playback_completed_at is None:
                raise FragmentOperationError(
                    "journey_state_conflict", "请先听完这段故事再提交线索照片"
                )
            stored = self.evidence_storage.put(
                file.stream,
                file.mimetype or "application/octet-stream",
                scope=f"{user_id}/{journey_id}",
            )
            now = datetime.now(UTC)
            evidence = EvidenceModel(
                id=str(uuid4()),
                journey_id=journey_id,
                mission_id=mission.id,
                object_key=stored.object_key,
                storage_provider=self.evidence_storage.provider,
                canonical_reference=self.evidence_storage.canonical_reference(stored.object_key),
                mime_type=stored.mime_type,
                size_bytes=stored.size_bytes,
                sha256=stored.sha256,
                width=stored.width,
                height=stored.height,
                captured_at=captured_at,
                uploaded_at=now,
                expires_at=now + timedelta(days=self.evidence_retention_days),
                idempotency_key=idempotency_key,
            )
            try:
                session.add(evidence)
                state.evidence_id = evidence.id
                state.state = "collected"
                state.collected_at = state.collected_at or now
                session.commit()
            except Exception:
                session.rollback()
                self.evidence_storage.delete(stored.object_key)
                raise
            return self._evidence_dict(evidence)

    def open_evidence(self, user_id: str, journey_id: str, evidence_id: str):
        with self._session() as session:
            self._owned_journey(session, user_id, journey_id)
            evidence = session.scalar(
                select(EvidenceModel).where(
                    EvidenceModel.id == evidence_id,
                    EvidenceModel.journey_id == journey_id,
                    EvidenceModel.deleted_at.is_(None),
                )
            )
            if evidence is None:
                raise FragmentOperationError(
                    "evidence_not_found", "照片证据不存在", status_code=404
                )
            if _is_expired(evidence.expires_at):
                raise FragmentOperationError(
                    "evidence_expired", "照片证据已按保留期清理", status_code=410
                )
            return self.evidence_storage.open(evidence.object_key), evidence.mime_type

    def list_evidence(self, user_id: str, journey_id: str) -> list[dict]:
        with self._session() as session:
            self._owned_journey(session, user_id, journey_id)
            rows = session.execute(
                select(EvidenceModel, PhotoMissionModel.fragment_id)
                .join(PhotoMissionModel, PhotoMissionModel.id == EvidenceModel.mission_id)
                .where(
                    EvidenceModel.journey_id == journey_id,
                    EvidenceModel.deleted_at.is_(None),
                )
                .order_by(EvidenceModel.uploaded_at.desc())
            ).all()
            return [
                self._evidence_dict(evidence, fragment_id=fragment_id)
                for evidence, fragment_id in rows
            ]

    def delete_evidence(self, user_id: str, journey_id: str, evidence_id: str) -> dict:
        with self._session() as session:
            self._owned_journey(session, user_id, journey_id)
            evidence = session.scalar(
                select(EvidenceModel).where(
                    EvidenceModel.id == evidence_id,
                    EvidenceModel.journey_id == journey_id,
                    EvidenceModel.deleted_at.is_(None),
                )
            )
            if evidence is None:
                return {"id": evidence_id, "deleted": True}
            mission = session.get(PhotoMissionModel, evidence.mission_id)
            state = session.scalar(
                select(JourneyFragmentModel).where(
                    JourneyFragmentModel.journey_id == journey_id,
                    JourneyFragmentModel.fragment_id == mission.fragment_id,
                )
            )
            evidence.deleted_at = datetime.now(UTC)
            if state and state.evidence_id == evidence.id:
                state.evidence_id = None
            session.commit()
            self.evidence_storage.delete(evidence.object_key)
            return {"id": evidence_id, "deleted": True}

    def ledger(self, user_id: str, journey_id: str) -> dict:
        with self._session() as session:
            journey = self._owned_journey(session, user_id, journey_id)
            if self._reconcile_optional_photo_states(session, journey_id):
                session.commit()
            arc = session.scalar(
                select(StoryArcModel)
                .where(StoryArcModel.route_id == journey.route_id)
                .options(selectinload(StoryArcModel.fragments))
            )
            if arc is None:
                raise FragmentOperationError(
                    "unsupported_route", "该路线不是碎片叙事路线", status_code=422
                )
            states = {
                item.fragment_id: item
                for item in session.scalars(
                    select(JourneyFragmentModel).where(
                        JourneyFragmentModel.journey_id == journey_id
                    )
                )
            }
            entries = []
            narration = self._narration_context(session, arc)
            for fragment in arc.fragments:
                state = states[fragment.id]
                if state.state in {"triggered", "playing", "mission_pending", "collected"}:
                    entries.append(self._revealed_fragment(session, fragment, state, narration))
                else:
                    entries.append(
                        {
                            **self._public_fragment(fragment, session, narration),
                            "state": state.state,
                        }
                    )
            collected = sum(1 for item in states.values() if item.state == "collected")
            reconstruction_unlocked = collected == len(entries)
            return {
                "journey_id": journey_id,
                "central_question": arc.central_question,
                "collected_count": collected,
                "total_count": len(entries),
                "reconstruction_unlocked": reconstruction_unlocked,
                "reconstruction_items": shuffled_reconstruction_items(
                    arc.causal_model_json, journey_id=journey_id
                )
                if reconstruction_unlocked
                else [],
                "default_narration_profile_id": narration["default_profile_id"],
                "narration_profiles": narration["profiles"],
                "entries": entries,
            }

    def reconstruct(self, user_id: str, journey_id: str, submitted: list[str]) -> dict:
        with self._session() as session:
            journey = self._owned_journey(session, user_id, journey_id)
            self._reconcile_optional_photo_states(session, journey_id)
            arc = session.scalar(
                select(StoryArcModel).where(StoryArcModel.route_id == journey.route_id)
            )
            states = list(
                session.scalars(
                    select(JourneyFragmentModel).where(
                        JourneyFragmentModel.journey_id == journey_id
                    )
                )
            )
            if arc is None or not states or any(item.state != "collected" for item in states):
                raise FragmentOperationError(
                    "reconstruction_incomplete",
                    "收集全部五条线索后才能重构故事",
                    details={
                        "collected_count": sum(1 for item in states if item.state == "collected"),
                        "total_count": len(states),
                    },
                )
            items = normalize_reconstruction_items(arc.causal_model_json)
            expected = reconstruction_ids(arc.causal_model_json)
            text_to_id = {item["text"]: item["id"] for item in items}
            submitted_ids = [text_to_id.get(value, value) for value in submitted]
            correct, feedback = reconstruction_feedback(expected, submitted_ids)
            record = session.scalar(
                select(ReconstructionModel).where(ReconstructionModel.journey_id == journey_id)
            )
            now = datetime.now(UTC)
            if record is None:
                record = ReconstructionModel(
                    id=str(uuid4()),
                    journey_id=journey_id,
                    submitted_model_json=submitted_ids,
                    is_correct=correct,
                    attempt_count=1,
                    completed_at=now if correct else None,
                )
                session.add(record)
            else:
                record.submitted_model_json = submitted_ids
                record.is_correct = correct
                record.attempt_count += 1
                record.completed_at = now if correct else record.completed_at
            if correct:
                journey.status = "completed"
                journey.completed_at = now
                journey.updated_at = now
                for state in states:
                    state.reconstructed_at = now
            session.commit()
            return {
                "correct": correct,
                "feedback": feedback,
                "attempt_count": record.attempt_count,
                "complete_story_unlocked": correct,
            }

    def recap(self, user_id: str, journey_id: str) -> dict:
        with self._session() as session:
            journey = self._owned_journey(session, user_id, journey_id)
            reconstruction = session.scalar(
                select(ReconstructionModel).where(
                    ReconstructionModel.journey_id == journey_id,
                    ReconstructionModel.is_correct.is_(True),
                )
            )
            if reconstruction is None:
                raise FragmentOperationError(
                    "reconstruction_incomplete", "完成故事重构后才会生成完整回顾"
                )
            arc = session.scalar(
                select(StoryArcModel)
                .where(StoryArcModel.route_id == journey.route_id)
                .options(selectinload(StoryArcModel.fragments))
            )
            evidence = list(
                session.scalars(
                    select(EvidenceModel).where(
                        EvidenceModel.journey_id == journey_id, EvidenceModel.deleted_at.is_(None)
                    )
                )
            )
            return {
                "journey_id": journey_id,
                "title": arc.title,
                "central_question": arc.central_question,
                "complete_story": arc.complete_story,
                "causal_model": [
                    item["text"] for item in normalize_reconstruction_items(arc.causal_model_json)
                ],
                "review_state": arc.review_state,
                "fragments": [
                    self._revealed_fragment(
                        session, item, self._state_for(session, journey_id, item.id)
                    )
                    for item in arc.fragments
                ],
                "evidence": [self._evidence_dict(item) for item in evidence],
            }

    def health(self) -> dict:
        assets = list((self.media_root / "audio").glob("*.m4a"))
        with self._session() as session:
            cloud_assets = list(
                session.scalars(
                    select(MediaAssetModel).where(
                        MediaAssetModel.mime_type.like("audio/%"),
                        MediaAssetModel.object_key.is_not(None),
                    )
                )
            )
        count = max(len(assets), len(cloud_assets))
        return {
            "evidence_storage": "up" if self.evidence_storage.healthy() else "down",
            "narration_assets": "up" if count >= 5 else "down",
            "narration_asset_count": count,
        }

    @staticmethod
    def _owned_journey(session: Session, user_id: str, journey_id: str) -> JourneyModel:
        journey = session.scalar(
            select(JourneyModel).where(
                JourneyModel.id == journey_id, JourneyModel.user_id == user_id
            )
        )
        if journey is None:
            raise JourneyNotFoundError()
        return journey

    @staticmethod
    def _float(value) -> float | None:
        if isinstance(value, bool) or value is None:
            return None
        try:
            return float(value)
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _reconcile_optional_photo_states(session: Session, journey_id: str) -> bool:
        legacy_states = list(
            session.scalars(
                select(JourneyFragmentModel).where(
                    JourneyFragmentModel.journey_id == journey_id,
                    JourneyFragmentModel.state == "mission_pending",
                    JourneyFragmentModel.playback_completed_at.is_not(None),
                )
            )
        )
        for state in legacy_states:
            state.state = "collected"
            state.collected_at = state.collected_at or state.playback_completed_at
        if legacy_states:
            session.flush()
        return bool(legacy_states)

    @staticmethod
    def _idempotent(session: Session, scope: str, key: str) -> dict | None:
        record = session.scalar(
            select(IdempotencyRecordModel).where(
                IdempotencyRecordModel.scope == scope, IdempotencyRecordModel.idempotency_key == key
            )
        )
        return dict(record.response_json) if record else None

    @staticmethod
    def _record_idempotency(session: Session, scope: str, key: str, response: dict) -> None:
        session.add(
            IdempotencyRecordModel(
                scope=scope,
                idempotency_key=key,
                response_json=response,
                created_at=datetime.now(UTC),
            )
        )

    @staticmethod
    def _fragment_state(
        session: Session, journey: JourneyModel, fragment_id: str
    ) -> tuple[StoryFragmentModel, JourneyFragmentModel]:
        fragment = session.get(StoryFragmentModel, fragment_id)
        if fragment is None or fragment.arc.route_id != journey.route_id:
            raise FragmentOperationError("fragment_not_found", "故事碎片不存在", status_code=404)
        state = session.scalar(
            select(JourneyFragmentModel).where(
                JourneyFragmentModel.journey_id == journey.id,
                JourneyFragmentModel.fragment_id == fragment_id,
            )
        )
        if state is None:
            raise FragmentOperationError("journey_state_conflict", "旅程碎片状态尚未初始化")
        return fragment, state

    @staticmethod
    def _state_for(session: Session, journey_id: str, fragment_id: str) -> JourneyFragmentModel:
        return session.scalar(
            select(JourneyFragmentModel).where(
                JourneyFragmentModel.journey_id == journey_id,
                JourneyFragmentModel.fragment_id == fragment_id,
            )
        )

    def _asset_reference(self, session: Session, value: str) -> str:
        if value.startswith(("http://", "https://")):
            return value
        asset = session.scalar(
            select(MediaAssetModel).where(
                (MediaAssetModel.storage_path == value)
                | (MediaAssetModel.object_key == value)
                | (MediaAssetModel.key == value)
            )
        )
        return asset.canonical_url if asset and asset.canonical_url else value

    def _asset_exists(self, session: Session, value: str) -> bool:
        if value.startswith(("http://", "https://")):
            return True
        asset = session.scalar(
            select(MediaAssetModel).where(
                (MediaAssetModel.storage_path == value)
                | (MediaAssetModel.object_key == value)
                | (MediaAssetModel.key == value)
            )
        )
        return (
            bool(asset and (asset.canonical_url or asset.object_key))
            or (self.media_root / value).is_file()
        )

    def _public_fragment(
        self,
        fragment: StoryFragmentModel,
        session: Session,
        narration: dict | None = None,
    ) -> dict:
        region = fragment.trigger_region
        mission = fragment.photo_mission
        narration = narration or self._narration_context(session, fragment.arc)
        experience_tags = normalize_experience_tags(fragment.experience_tags_json or [])
        route_theme = fragment.arc.route.theme if fragment.arc.route is not None else ""
        return {
            "id": fragment.id,
            "position": fragment.position,
            "safe_preview": fragment.safe_preview,
            "interaction_type": fragment.interaction_type,
            "review_state": fragment.review_state,
            "experience_tags": experience_tags,
            "display_theme": experience_tags[0] if experience_tags else route_theme,
            "expected_duration_seconds": max(30, round(len(fragment.narration_script.strip()) / 4)),
            "trigger_region": {
                "latitude": region.latitude,
                "longitude": region.longitude,
                "entry_radius_m": region.entry_radius_m,
                "exit_radius_m": region.exit_radius_m,
                "max_accuracy_m": region.max_accuracy_m,
                "qualifying_samples": region.qualifying_samples,
                "sample_window_seconds": region.sample_window_seconds,
                "cooldown_seconds": region.cooldown_seconds,
                "audit_state": region.audit_state,
            },
            "audio": {
                "url": self.asset_url_builder(self._asset_reference(session, fragment.audio_path)),
                "mime_type": fragment.audio_mime_type,
                "size_bytes": fragment.audio_size_bytes,
                "script_version": fragment.script_version,
            },
            "narration_tracks": narration["tracks_by_fragment"].get(fragment.id, {}),
            "mission_preview": {"required": mission.required, "audit_state": mission.audit_state}
            if mission
            else None,
        }

    def _revealed_fragment(
        self,
        session: Session,
        fragment: StoryFragmentModel,
        state: JourneyFragmentModel,
        narration: dict | None = None,
    ) -> dict:
        data = self._public_fragment(fragment, session, narration)
        mission = fragment.photo_mission
        claims = list(
            session.scalars(
                select(HistoricalClaimModel)
                .join(FragmentClaimModel, FragmentClaimModel.claim_id == HistoricalClaimModel.id)
                .where(FragmentClaimModel.fragment_id == fragment.id)
            )
        )
        source_rows = session.execute(
            select(HistoricalSourceModel, ClaimSourceModel.support_note)
            .join(ClaimSourceModel, ClaimSourceModel.source_id == HistoricalSourceModel.id)
            .join(FragmentClaimModel, FragmentClaimModel.claim_id == ClaimSourceModel.claim_id)
            .where(FragmentClaimModel.fragment_id == fragment.id)
        ).all()
        data.update(
            {
                "title": fragment.title,
                "transcript": fragment.transcript,
                "key_claim": fragment.key_claim,
                "answers_question": fragment.answers_question,
                "raises_question": fragment.raises_question,
                "authenticity_label": fragment.authenticity_label,
                "completion_threshold": fragment.completion_threshold,
                "state": state.state,
                "trigger_method": state.trigger_method,
                "playback_progress": state.playback_progress,
                "triggered_at": _iso(state.triggered_at),
                "playback_completed_at": _iso(state.playback_completed_at),
                "collected_at": _iso(state.collected_at),
                "evidence_id": state.evidence_id,
                "mission": {
                    "id": mission.id,
                    "prompt": mission.prompt,
                    "field_subject": mission.field_subject,
                    "vantage_point": mission.vantage_point or mission.field_subject,
                    "shooting_direction": mission.shooting_direction or mission.prompt,
                    "composition_tip": mission.composition_tip or mission.prompt,
                    "safety_copy": mission.safety_copy,
                    "accessibility_alternative": mission.accessibility_alternative,
                    "authenticity_label": mission.authenticity_label,
                    "required": mission.required,
                    "audit_state": mission.audit_state,
                }
                if mission
                else None,
                "claims": [
                    {
                        "text": claim.canonical_text,
                        "kind": claim.claim_kind,
                        "certainty": claim.certainty,
                        "review_state": claim.review_state,
                        "boundary_note": claim.boundary_note,
                    }
                    for claim in claims
                ],
                "sources": [
                    {
                        "title": source.title,
                        "publisher": source.publisher,
                        "url": source.url,
                        "summary": source.summary,
                        "review_state": source.review_state,
                        "support_note": note,
                    }
                    for source, note in source_rows
                ],
            }
        )
        return data

    def _narration_context(self, session: Session, arc: StoryArcModel) -> dict:
        fragments = list(arc.fragments)
        fragment_ids = [item.id for item in fragments]
        profiles = list(
            session.scalars(
                select(NarrationVoiceProfileModel)
                .where(
                    NarrationVoiceProfileModel.status == "published",
                    NarrationVoiceProfileModel.published_at.is_not(None),
                )
                .order_by(
                    NarrationVoiceProfileModel.display_order,
                    NarrationVoiceProfileModel.display_name,
                )
            )
        )
        if not fragment_ids or not profiles:
            return {"profiles": [], "default_profile_id": None, "tracks_by_fragment": {}}
        tracks = list(
            session.scalars(
                select(FragmentNarrationTrackModel).where(
                    FragmentNarrationTrackModel.fragment_id.in_(fragment_ids),
                    FragmentNarrationTrackModel.profile_id.in_([item.id for item in profiles]),
                    FragmentNarrationTrackModel.published_at.is_not(None),
                )
            )
        )
        matching: dict[tuple[str, str], FragmentNarrationTrackModel] = {}
        fragment_by_id = {item.id: item for item in fragments}
        for track in tracks:
            fragment = fragment_by_id[track.fragment_id]
            transcript_hash = hashlib.sha256(fragment.narration_script.strip().encode()).hexdigest()
            if (
                track.transcript_hash == transcript_hash
                and track.script_version == fragment.script_version
            ):
                matching[(track.profile_id, track.fragment_id)] = track
        complete_profiles = [
            profile
            for profile in profiles
            if all((profile.id, fragment_id) in matching for fragment_id in fragment_ids)
        ]
        profile_payload = [
            {
                "id": item.id,
                "slug": item.slug,
                "name": item.display_name,
                "description": item.description,
                "preview_audio_url": self.asset_url_builder(
                    self._asset_reference(session, item.preview_media_path)
                )
                if item.preview_media_path
                else None,
                "is_default": item.is_default,
            }
            for item in complete_profiles
        ]
        tracks_by_fragment: dict[str, dict[str, dict]] = {
            fragment_id: {} for fragment_id in fragment_ids
        }
        for profile in complete_profiles:
            for fragment_id in fragment_ids:
                track = matching[(profile.id, fragment_id)]
                tracks_by_fragment[fragment_id][profile.id] = {
                    "audio_url": self.asset_url_builder(
                        self._asset_reference(session, track.media_path)
                    ),
                    "mime_type": track.mime_type,
                    "size_bytes": track.size_bytes,
                    "transcript_hash": track.transcript_hash,
                    "script_version": track.script_version,
                }
        default_profile = next(
            (item for item in complete_profiles if item.is_default),
            complete_profiles[0] if complete_profiles else None,
        )
        return {
            "profiles": profile_payload,
            "default_profile_id": default_profile.id if default_profile else None,
            "tracks_by_fragment": tracks_by_fragment,
        }

    @staticmethod
    def _evidence_dict(evidence: EvidenceModel, *, fragment_id: str | None = None) -> dict:
        data = {
            "id": evidence.id,
            "journey_id": evidence.journey_id,
            "mission_id": evidence.mission_id,
            "mime_type": evidence.mime_type,
            "size_bytes": evidence.size_bytes,
            "width": evidence.width,
            "height": evidence.height,
            "captured_at": _iso(evidence.captured_at),
            "uploaded_at": _iso(evidence.uploaded_at),
            "expires_at": _iso(evidence.expires_at),
            "is_expired": _is_expired(evidence.expires_at),
            "url": f"/journeys/{evidence.journey_id}/evidence/{evidence.id}",
        }
        if fragment_id is not None:
            data["fragment_id"] = fragment_id
        return data
