from __future__ import annotations

import hashlib
from datetime import UTC, datetime
from uuid import NAMESPACE_URL, uuid5

from sqlalchemy import select

from app.infrastructure.persistence.models import (
    CityModel,
    HomeStoryPublicationModel,
    RouteModel,
    StoryArcModel,
    StoryCatalogItemModel,
    StoryCatalogVariantModel,
    StoryNarrationTrackModel,
    StoryPlacementModel,
)


def _stable_id(kind: str, identity: str) -> str:
    return str(uuid5(NAMESPACE_URL, f"jiandi:{kind}:{identity}"))


class CityStoryMigrationService:
    """Maps legacy home publications to catalog identities without copying content."""

    def __init__(self, session_factory):
        self.session_factory = session_factory

    def migrate(self, *, dry_run: bool = False) -> dict:
        report: dict[str, object] = {
            "dry_run": dry_run,
            "ready": [],
            "created": [],
            "reused": [],
            "blocked": [],
            "conflicted": [],
        }
        with self.session_factory() as session:
            publications = list(
                session.scalars(
                    select(HomeStoryPublicationModel).order_by(HomeStoryPublicationModel.id)
                )
            )
            try:
                for publication in publications:
                    result = self._plan(session, publication)
                    report[result["state"]].append(result)
                    if dry_run or result["state"] in {"blocked", "conflicted"}:
                        continue
                    state = self._apply(session, publication, result)
                    report[state].append(report["ready"].pop())
                if dry_run:
                    session.rollback()
                else:
                    session.commit()
            except Exception:
                session.rollback()
                raise
        report["counts"] = {
            key: len(report[key]) for key in ("ready", "created", "reused", "blocked", "conflicted")
        }
        return report

    def _plan(self, session, publication) -> dict:
        arc = session.get(StoryArcModel, publication.arc_id)
        track = (
            session.get(StoryNarrationTrackModel, publication.selected_track_id)
            if publication.selected_track_id
            else None
        )
        route = session.get(RouteModel, arc.route_id) if arc else None
        city = session.get(CityModel, route.city_id) if route else None
        blockers: list[str] = []
        expected_hash = hashlib.sha256(
            (arc.complete_story.strip() if arc else "").encode()
        ).hexdigest()
        if publication.status != "published" or publication.published_at is None:
            blockers.append("legacy_not_published")
        if arc is None or route is None or city is None:
            blockers.append("canonical_source_missing")
        if track is None or not publication.selected_track_id:
            blockers.append("approved_track_missing")
        elif (
            track.arc_id != publication.arc_id
            or track.status != "published"
            or track.published_at is None
            or track.transcript_hash != expected_hash
            or (arc is not None and track.script_version != arc.script_version)
            or track.size_bytes <= 0
            or track.duration_ms <= 0
            or not track.media_path.strip()
        ):
            blockers.append("approved_track_stale")
        if route is not None and (
            route.content_status != "published" or route.published_at is None
        ):
            blockers.append("route_not_published")
        existing = session.scalar(
            select(StoryCatalogItemModel).where(
                StoryCatalogItemModel.source_kind == "story_arc",
                StoryCatalogItemModel.source_id == publication.arc_id,
            )
        )
        desired_id = publication.id
        id_owner = session.get(StoryCatalogItemModel, desired_id)
        if id_owner is not None and id_owner is not existing:
            return {
                "state": "conflicted",
                "publication_id": publication.id,
                "source_id": publication.arc_id,
                "reasons": ["catalog_id_owned_by_other_source"],
            }
        return {
            "state": "blocked" if blockers else "ready",
            "publication_id": publication.id,
            "source_id": publication.arc_id,
            "catalog_id": existing.id if existing else desired_id,
            "track_id": publication.selected_track_id,
            "canonical_revision": expected_hash,
            "reasons": blockers,
            "existing": existing is not None,
        }

    def _apply(self, session, publication, plan: dict) -> str:
        now = datetime.now(UTC)
        arc = session.get(StoryArcModel, publication.arc_id)
        route = session.get(RouteModel, arc.route_id)
        item = session.get(StoryCatalogItemModel, plan["catalog_id"])
        created = item is None
        if item is None:
            item = StoryCatalogItemModel(
                id=plan["catalog_id"],
                city_id=route.city_id,
                source_kind="story_arc",
                source_id=arc.id,
                canonical_revision=plan["canonical_revision"],
                title=publication.title,
                summary=publication.introduction,
                cover_image=publication.cover_image,
                district=None,
                themes_json=[route.theme] if route.theme else [],
                point_ids_json=[],
                related_stories_json=[],
                content_type="city_story",
                place_context=route.title,
                observable_detail=publication.introduction,
                attention_hint=None,
                sources_json=[
                    {
                        "kind": "legacy_home_publication",
                        "id": publication.id,
                    }
                ],
                fact_status="legacy_reviewed",
                review_status="reviewed",
                status="published",
                version=1,
                reviewed_by=publication.reviewed_by,
                reviewed_at=publication.reviewed_at or now,
                published_at=publication.published_at,
                created_at=publication.created_at,
                updated_at=now,
            )
            session.add(item)
            session.flush()
        variant = session.scalar(
            select(StoryCatalogVariantModel).where(
                StoryCatalogVariantModel.catalog_item_id == item.id,
                StoryCatalogVariantModel.role == "short_preview",
            )
        )
        if variant is None:
            variant = StoryCatalogVariantModel(
                id=_stable_id("legacy-home-variant", publication.id),
                catalog_item_id=item.id,
                role="short_preview",
                source_kind="story_arc",
                source_id=arc.id,
                track_kind="story",
                track_id=publication.selected_track_id,
                transcript_hash=plan["canonical_revision"],
                script_version=arc.script_version,
                status="published",
                reviewed_at=publication.reviewed_at or now,
                published_at=publication.published_at,
                created_at=now,
                updated_at=now,
            )
            session.add(variant)
        placement = session.scalar(
            select(StoryPlacementModel).where(
                StoryPlacementModel.catalog_item_id == item.id,
                StoryPlacementModel.channel == "home",
                StoryPlacementModel.module_key == "today_city_story",
                StoryPlacementModel.route_id.is_(None),
            )
        )
        if placement is None:
            placement = StoryPlacementModel(
                id=_stable_id("legacy-home-placement", publication.id),
                catalog_item_id=item.id,
                channel="home",
                module_key="today_city_story",
                route_id=None,
                variant_role="short_preview",
                display_order=0,
                weight=max(1, publication.selection_weight),
                status="published",
                reviewed_at=publication.reviewed_at or now,
                published_at=publication.published_at,
                created_at=now,
                updated_at=now,
            )
            session.add(placement)
        return "created" if created else "reused"
