from __future__ import annotations

import hashlib
import random

from sqlalchemy import select

from app.domain.errors import CityNotFoundError, FragmentOperationError
from app.infrastructure.persistence.models import (
    CityModel,
    HomeStoryPublicationModel,
    NarrationVoiceProfileModel,
    RouteModel,
    StoryArcModel,
    StoryNarrationTrackModel,
)


class StoryListeningService:
    def __init__(self, session_factory, asset_url_builder, *, chooser=None):
        self.session_factory = session_factory
        self.asset_url_builder = asset_url_builder
        self.chooser = chooser or random.choices

    def random_story(self, city_slug: str, exclude_id: str | None = None) -> dict:
        city_slug = city_slug.strip()
        if not city_slug:
            raise CityNotFoundError()
        with self.session_factory() as session:
            city_exists = session.scalar(select(CityModel.id).where(CityModel.slug == city_slug))
            if city_exists is None:
                raise CityNotFoundError()
            candidates = self._eligible(session, city_slug=city_slug)
            if exclude_id and len(candidates) > 1:
                without_previous = [row for row in candidates if row[0].id != exclude_id]
                if without_previous:
                    candidates = without_previous
            if not candidates:
                raise FragmentOperationError(
                    "story_pool_empty", "这座城市的故事还在准备中", status_code=404
                )
            selected = self.chooser(
                candidates,
                weights=[row[0].selection_weight for row in candidates],
                k=1,
            )[0]
            return self._payload(*selected)

    def get(self, publication_id: str) -> dict:
        with self.session_factory() as session:
            rows = self._eligible(session, publication_id=publication_id)
            if not rows:
                raise FragmentOperationError(
                    "story_not_found", "故事不存在", status_code=404
                )
            return self._payload(*rows[0])

    def _eligible(
        self,
        session,
        *,
        city_slug: str | None = None,
        publication_id: str | None = None,
    ):
        query = (
            select(
                HomeStoryPublicationModel,
                StoryNarrationTrackModel,
                StoryArcModel,
                RouteModel,
                CityModel,
                NarrationVoiceProfileModel,
            )
            .join(StoryArcModel, StoryArcModel.id == HomeStoryPublicationModel.arc_id)
            .join(RouteModel, RouteModel.id == StoryArcModel.route_id)
            .join(CityModel, CityModel.id == RouteModel.city_id)
            .join(
                StoryNarrationTrackModel,
                StoryNarrationTrackModel.id == HomeStoryPublicationModel.selected_track_id,
            )
            .join(
                NarrationVoiceProfileModel,
                NarrationVoiceProfileModel.id == StoryNarrationTrackModel.profile_id,
            )
            .where(
                HomeStoryPublicationModel.status == "published",
                HomeStoryPublicationModel.published_at.is_not(None),
                HomeStoryPublicationModel.selection_weight > 0,
                StoryNarrationTrackModel.status == "published",
                StoryNarrationTrackModel.published_at.is_not(None),
                StoryNarrationTrackModel.size_bytes > 0,
                StoryNarrationTrackModel.duration_ms > 0,
                RouteModel.content_status == "published",
                RouteModel.published_at.is_not(None),
                NarrationVoiceProfileModel.status == "published",
            )
        )
        if city_slug is not None:
            query = query.where(CityModel.slug == city_slug)
        if publication_id is not None:
            query = query.where(HomeStoryPublicationModel.id == publication_id)
        rows = session.execute(query).all()
        return [
            row
            for row in rows
            if row[1].transcript_hash
            == hashlib.sha256(row[2].complete_story.strip().encode()).hexdigest()
            and row[1].script_version == row[2].script_version
            and bool(row[1].media_path.strip())
        ]

    def _payload(self, publication, track, arc, route, city, profile) -> dict:
        return {
            "id": publication.id,
            "story_arc_id": arc.id,
            "title": publication.title,
            "introduction": publication.introduction,
            "cover_image": self.asset_url_builder(publication.cover_image),
            "duration_ms": track.duration_ms,
            "transcript": arc.complete_story,
            "audio_url": self.asset_url_builder(track.media_path),
            "city": {"slug": city.slug, "name": city.name},
            "route": {"slug": route.slug, "title": route.title},
            "narration_profile": {
                "id": profile.id,
                "display_name": profile.display_name,
                "description": profile.description,
            },
        }
