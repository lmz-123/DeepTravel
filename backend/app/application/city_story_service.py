from __future__ import annotations

import hashlib
from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import or_, select

from app.domain.errors import (
    CityNotFoundError,
    FragmentOperationError,
    RouteNotFoundError,
    ValidationError,
)
from app.infrastructure.persistence.models import (
    CityModel,
    FragmentNarrationTrackModel,
    NarrationVoiceProfileModel,
    RouteModel,
    RoutePretripGuidanceModel,
    StopModel,
    StoryArcModel,
    StoryCatalogItemModel,
    StoryFragmentModel,
    StoryNarrationTrackModel,
    StoryPlacementModel,
    TravelerFavoriteModel,
)

HOME_MODULES = (
    ("today_city_story", "今天听一段城市故事", True),
    ("street_corner_3min", "3 分钟了解一个街角", False),
    ("city_small_thing", "一座城市的一件小事", False),
    ("overlooked_detail", "你路过但没注意的细节", False),
    ("today_destination", "今天适合去哪儿", False),
)
PUBLIC_STATUSES = {"published"}
REVIEWED_STATES = {"reviewed", "approved", "verified", "published"}


def _hash(value: str) -> str:
    return hashlib.sha256(value.strip().encode()).hexdigest()


def _as_utc(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    return value if value.tzinfo else value.replace(tzinfo=UTC)


class CityStoryService:
    def __init__(self, session_factory, asset_url_builder):
        self.session_factory = session_factory
        self.asset_url_builder = asset_url_builder

    def home(self, city_slug: str) -> dict:
        with self.session_factory() as session:
            city = session.scalar(select(CityModel).where(CityModel.slug == city_slug.strip()))
            if city is None:
                raise CityNotFoundError()
            now = datetime.now(UTC)
            rows = session.execute(
                select(StoryPlacementModel, StoryCatalogItemModel)
                .join(
                    StoryCatalogItemModel,
                    StoryCatalogItemModel.id == StoryPlacementModel.catalog_item_id,
                )
                .where(
                    StoryCatalogItemModel.city_id == city.id,
                    StoryCatalogItemModel.status == "published",
                    StoryCatalogItemModel.published_at.is_not(None),
                    StoryPlacementModel.channel == "home",
                    StoryPlacementModel.status == "published",
                    StoryPlacementModel.published_at.is_not(None),
                    StoryPlacementModel.weight > 0,
                    or_(
                        StoryPlacementModel.starts_at.is_(None),
                        StoryPlacementModel.starts_at <= now,
                    ),
                    or_(StoryPlacementModel.ends_at.is_(None), StoryPlacementModel.ends_at > now),
                )
                .order_by(
                    StoryPlacementModel.module_key,
                    StoryPlacementModel.display_order,
                    StoryPlacementModel.id,
                )
            ).all()
            by_module: dict[str, list[dict]] = {key: [] for key, _, _ in HOME_MODULES}
            for placement, item in rows:
                if placement.module_key not in by_module:
                    continue
                payload = self._public_story(
                    session, item, placement.variant_role, placement=placement
                )
                if payload is not None:
                    by_module[placement.module_key].append(payload)
            modules = [
                {
                    "key": key,
                    "title": title,
                    "primary": primary,
                    "items": by_module[key],
                }
                for key, title, primary in HOME_MODULES
            ]
            has_content = any(module["items"] for module in modules)
            fallback = [] if has_content else self._fallback_cities(session, city.id)
            return {
                "city": {"id": city.id, "slug": city.slug, "name": city.name},
                "modules": modules,
                "empty": not has_content,
                "empty_reason": None if has_content else "这座城市的故事还在准备中",
                "actions": {"switch_city": True},
                "fallback_cities": fallback,
            }

    def get_story(self, catalog_id: str, variant_role: str | None = None) -> dict:
        with self.session_factory() as session:
            item = session.get(StoryCatalogItemModel, catalog_id)
            if item is None or item.status != "published" or item.published_at is None:
                raise FragmentOperationError("city_story_not_found", "故事不存在", status_code=404)
            payload = self._public_story(session, item, variant_role or "short_preview")
            if payload is None:
                raise FragmentOperationError("city_story_not_found", "故事不存在", status_code=404)
            return payload

    def pretrip(self, route_slug: str) -> dict:
        with self.session_factory() as session:
            route = session.scalar(
                select(RouteModel).where(
                    RouteModel.slug == route_slug,
                    RouteModel.content_status == "published",
                    RouteModel.published_at.is_not(None),
                )
            )
            if route is None:
                raise RouteNotFoundError()
            guidance = session.get(RoutePretripGuidanceModel, route.id)
            if guidance is None or guidance.status != "published" or guidance.published_at is None:
                return self._empty_pretrip(route)
            theme_story = None
            if guidance.theme_story_catalog_id:
                item = session.get(StoryCatalogItemModel, guidance.theme_story_catalog_id)
                if item is not None:
                    theme_story = self._public_story(session, item, "short_preview")
            directions: list[dict] = []
            resources: list[dict] = []
            for index, raw in enumerate(guidance.story_directions_json or []):
                if not isinstance(raw, dict):
                    continue
                catalog_id = str(raw.get("catalog_id") or "")
                item = session.get(StoryCatalogItemModel, catalog_id)
                story = (
                    self._public_story(session, item, "short_preview") if item is not None else None
                )
                if story is None:
                    continue
                direction = {
                    "catalog_id": catalog_id,
                    "title": str(raw.get("title") or story["title"]),
                    "summary": str(raw.get("summary") or story["introduction"]),
                    "order": int(raw.get("order", index)),
                    "advisory": True,
                    "story": story,
                }
                directions.append(direction)
                resources.extend(self._offline_resources(story, guidance.offline_roles_json))
            directions.sort(key=lambda item: (item["order"], item["catalog_id"]))
            if theme_story is not None:
                resources.extend(self._offline_resources(theme_story, guidance.offline_roles_json))
            unique_resources = {
                (item["kind"], item["id"], item["version"]): item for item in resources
            }
            return {
                "available": bool(theme_story or directions),
                "route": {
                    "id": route.id,
                    "slug": route.slug,
                    "theme": route.theme,
                    "duration_minutes": route.duration_minutes,
                    "distance_km": route.distance_km,
                },
                "theme_story": theme_story,
                "story_directions": directions,
                "companion_tags": list(guidance.companion_tags_json or []),
                "tips": {
                    "safety": list(guidance.safety_tips_json or []),
                    "rest": list(guidance.rest_tips_json or []),
                    "accessibility": list(guidance.accessibility_tips_json or []),
                    "weather_adaptation": list(guidance.weather_tips_json or []),
                },
                "offline_resources": list(unique_resources.values()),
                "advisory_order": True,
                "requires_arrival": False,
                "quiz": None,
                "version": guidance.version,
            }

    def list_favorites(self, user_id: str) -> list[dict]:
        with self.session_factory() as session:
            rows = session.scalars(
                select(TravelerFavoriteModel)
                .where(TravelerFavoriteModel.user_id == user_id)
                .order_by(TravelerFavoriteModel.created_at.desc())
            ).all()
            return [self._favorite_payload(session, item) for item in rows]

    def add_favorite(self, user_id: str, target_kind: str, target_id: str) -> dict:
        target_kind, target_id = self._validate_favorite_input(target_kind, target_id)
        with self.session_factory() as session:
            target = self._resolve_favorite_target(session, target_kind, target_id)
            if target is None:
                raise ValidationError("只能收藏已发布的城市、景点或主题")
            item = session.scalar(
                select(TravelerFavoriteModel).where(
                    TravelerFavoriteModel.user_id == user_id,
                    TravelerFavoriteModel.target_kind == target_kind,
                    TravelerFavoriteModel.target_id == target_id,
                )
            )
            if item is None:
                item = TravelerFavoriteModel(
                    id=str(uuid4()),
                    user_id=user_id,
                    target_kind=target_kind,
                    target_id=target_id,
                    created_at=datetime.now(UTC),
                )
                session.add(item)
                session.commit()
            return self._favorite_payload(session, item)

    def remove_favorite(self, user_id: str, target_kind: str, target_id: str) -> dict:
        target_kind, target_id = self._validate_favorite_input(target_kind, target_id)
        with self.session_factory() as session:
            item = session.scalar(
                select(TravelerFavoriteModel).where(
                    TravelerFavoriteModel.user_id == user_id,
                    TravelerFavoriteModel.target_kind == target_kind,
                    TravelerFavoriteModel.target_id == target_id,
                )
            )
            if item is not None:
                session.delete(item)
                session.commit()
            return {"target_kind": target_kind, "target_id": target_id, "favorite": False}

    def _public_story(
        self,
        session,
        item: StoryCatalogItemModel,
        variant_role: str,
        *,
        placement: StoryPlacementModel | None = None,
    ) -> dict | None:
        if (
            item.status not in PUBLIC_STATUSES
            or item.published_at is None
            or item.review_status not in REVIEWED_STATES
            or not item.sources_json
            or not item.place_context.strip()
            or not item.observable_detail.strip()
            or not item.cover_image.strip()
        ):
            return None
        variants = sorted(
            item.variants,
            key=lambda value: (value.role != variant_role, value.role, value.id),
        )
        for variant in variants:
            resolved = self._resolve_variant(session, item, variant)
            if resolved is None:
                continue
            transcript, audio_url, duration_ms, route, profile, checksum, size_bytes = resolved
            city = session.get(CityModel, item.city_id)
            if city is None:
                return None
            arc_id = item.source_id if item.source_kind == "story_arc" else route.story_arc.id
            return {
                "id": item.id,
                "catalog_id": item.id,
                "arc_id": arc_id,
                "story_arc_id": arc_id,
                "canonical_revision": item.canonical_revision,
                "variant_role": variant.role,
                "title": item.title,
                "introduction": item.summary,
                "summary": item.summary,
                "cover_image": self.asset_url_builder(item.cover_image),
                "cover_image_url": self.asset_url_builder(item.cover_image),
                "duration_ms": duration_ms,
                "transcript": transcript,
                "audio_url": self.asset_url_builder(audio_url),
                "audio_checksum_sha256": checksum,
                "audio_size_bytes": size_bytes,
                "city": {"id": city.id, "slug": city.slug, "name": city.name},
                "district": item.district,
                "route": {"id": route.id, "slug": route.slug, "title": route.title},
                "themes": list(item.themes_json or []),
                "related_point_ids": list(item.point_ids_json or []),
                "related_stories": list(item.related_stories_json or []),
                "content_type": item.content_type,
                "place_context": item.place_context,
                "observable_detail": item.observable_detail,
                "attention_hint": item.attention_hint,
                "sources": list(item.sources_json or []),
                "fact_status": item.fact_status,
                "narration_profile": {
                    "id": profile.id,
                    "display_name": profile.display_name,
                    "description": profile.description,
                },
                "placement": (
                    {
                        "channel": placement.channel,
                        "module_key": placement.module_key,
                        "display_order": placement.display_order,
                    }
                    if placement is not None
                    else None
                ),
                "quiz": None,
            }
        return None

    def _resolve_variant(self, session, item, variant):
        if variant.status != "published" or variant.published_at is None:
            return None
        if variant.source_kind == "story_arc" and variant.track_kind == "story":
            arc = session.get(StoryArcModel, variant.source_id)
            track = session.get(StoryNarrationTrackModel, variant.track_id)
            if arc is None or track is None or track.arc_id != arc.id:
                return None
            route = session.get(RouteModel, arc.route_id)
            profile = session.get(NarrationVoiceProfileModel, track.profile_id)
            transcript = arc.complete_story.strip()
            expected_hash = _hash(transcript)
            eligible = (
                arc.review_state in REVIEWED_STATES
                and track.status == "published"
                and track.published_at is not None
                and track.transcript_hash == expected_hash == variant.transcript_hash
                and track.script_version == arc.script_version == variant.script_version
                and track.size_bytes > 0
                and track.duration_ms > 0
            )
            duration_ms = track.duration_ms
        elif variant.source_kind == "story_fragment" and variant.track_kind == "fragment":
            fragment = session.get(StoryFragmentModel, variant.source_id)
            track = session.get(FragmentNarrationTrackModel, variant.track_id)
            if fragment is None or track is None or track.fragment_id != fragment.id:
                return None
            arc = session.get(StoryArcModel, fragment.arc_id)
            route = session.get(RouteModel, arc.route_id) if arc else None
            profile = session.get(NarrationVoiceProfileModel, track.profile_id)
            transcript = fragment.transcript.strip() or fragment.narration_script.strip()
            expected_hash = _hash(fragment.narration_script)
            eligible = (
                fragment.review_state in REVIEWED_STATES
                and arc is not None
                and arc.review_state in REVIEWED_STATES
                and track.approved_at is not None
                and track.published_at is not None
                and track.transcript_hash == expected_hash == variant.transcript_hash
                and track.script_version == fragment.script_version == variant.script_version
                and track.size_bytes > 0
            )
            duration_ms = max(1000, len(transcript) * 230)
        else:
            return None
        if (
            not eligible
            or route is None
            or route.content_status != "published"
            or route.published_at is None
            or profile is None
            or profile.status != "published"
            or item.canonical_revision != self._canonical_revision(session, item)
        ):
            return None
        return (
            transcript,
            track.media_path,
            duration_ms,
            route,
            profile,
            track.checksum_sha256,
            track.size_bytes,
        )

    def _canonical_revision(self, session, item) -> str:
        if item.source_kind == "story_arc":
            source = session.get(StoryArcModel, item.source_id)
            return _hash(source.complete_story) if source else ""
        if item.source_kind == "story_fragment":
            source = session.get(StoryFragmentModel, item.source_id)
            return _hash(source.narration_script) if source else ""
        return ""

    def _fallback_cities(self, session, excluded_city_id: str) -> list[dict]:
        city_ids = session.scalars(
            select(StoryCatalogItemModel.city_id)
            .join(
                StoryPlacementModel,
                StoryPlacementModel.catalog_item_id == StoryCatalogItemModel.id,
            )
            .where(
                StoryCatalogItemModel.city_id != excluded_city_id,
                StoryCatalogItemModel.status == "published",
                StoryCatalogItemModel.published_at.is_not(None),
                StoryPlacementModel.channel == "home",
                StoryPlacementModel.status == "published",
                StoryPlacementModel.published_at.is_not(None),
            )
            .distinct()
            .limit(4)
        ).all()
        cities = (
            session.scalars(
                select(CityModel).where(CityModel.id.in_(city_ids)).order_by(CityModel.name)
            ).all()
            if city_ids
            else []
        )
        return [
            {
                "id": city.id,
                "slug": city.slug,
                "name": city.name,
                "hero_image": self.asset_url_builder(city.hero_image),
            }
            for city in cities
        ]

    def _empty_pretrip(self, route) -> dict:
        return {
            "available": False,
            "route": {
                "id": route.id,
                "slug": route.slug,
                "theme": route.theme,
                "duration_minutes": route.duration_minutes,
                "distance_km": route.distance_km,
            },
            "theme_story": None,
            "story_directions": [],
            "companion_tags": [],
            "tips": {"safety": [], "rest": [], "accessibility": [], "weather_adaptation": []},
            "offline_resources": [],
            "advisory_order": True,
            "requires_arrival": False,
            "quiz": None,
            "version": 0,
        }

    def _offline_resources(self, story: dict, roles: list[str] | None) -> list[dict]:
        configured = set(roles or [])
        resource_kinds = configured & {"audio", "transcript"}
        variant_roles = configured - resource_kinds
        if variant_roles and story["variant_role"] not in variant_roles:
            return []
        enabled = resource_kinds or {"audio", "transcript"}
        resources = []
        if "audio" in enabled and story.get("audio_url"):
            resources.append(
                {
                    "id": f"{story['id']}:{story['variant_role']}:audio",
                    "kind": "audio",
                    "url": story["audio_url"],
                    "version": story["canonical_revision"],
                    "checksum_sha256": story.get("audio_checksum_sha256"),
                    "size_bytes": story.get("audio_size_bytes") or 0,
                }
            )
        if "transcript" in enabled:
            resources.append(
                {
                    "id": f"{story['id']}:{story['variant_role']}:transcript",
                    "kind": "transcript",
                    "url": f"/city-stories/{story['id']}?variant_role={story['variant_role']}",
                    "version": story["canonical_revision"],
                    "checksum_sha256": _hash(story["transcript"]),
                    "size_bytes": len(story["transcript"].encode()),
                }
            )
        return resources

    def _validate_favorite_input(self, target_kind: str, target_id: str) -> tuple[str, str]:
        target_kind = str(target_kind).strip()
        target_id = str(target_id).strip()
        if target_kind not in {"city", "point", "theme"} or not target_id or len(target_id) > 120:
            raise ValidationError("收藏目标必须是有效的城市、景点或主题")
        return target_kind, target_id

    def _resolve_favorite_target(self, session, kind: str, target_id: str) -> dict | None:
        if kind == "city":
            city = session.scalar(
                select(CityModel)
                .join(RouteModel, RouteModel.city_id == CityModel.id)
                .where(
                    or_(CityModel.id == target_id, CityModel.slug == target_id),
                    RouteModel.content_status == "published",
                    RouteModel.published_at.is_not(None),
                )
                .limit(1)
            )
            return (
                {
                    "label": city.name,
                    "slug": city.slug,
                    "cover_image": self.asset_url_builder(city.hero_image),
                }
                if city
                else None
            )
        if kind == "point":
            stop = session.scalar(
                select(StopModel)
                .join(RouteModel, RouteModel.id == StopModel.route_id)
                .where(
                    StopModel.id == target_id,
                    RouteModel.content_status == "published",
                    RouteModel.published_at.is_not(None),
                )
            )
            if stop:
                return {"label": stop.title}
            fragment = session.scalar(
                select(StoryFragmentModel)
                .join(StoryArcModel, StoryArcModel.id == StoryFragmentModel.arc_id)
                .join(RouteModel, RouteModel.id == StoryArcModel.route_id)
                .where(
                    StoryFragmentModel.id == target_id,
                    StoryFragmentModel.review_state.in_(REVIEWED_STATES),
                    RouteModel.content_status == "published",
                    RouteModel.published_at.is_not(None),
                )
            )
            return {"label": fragment.title} if fragment else None
        route_theme = session.scalar(
            select(RouteModel.theme).where(
                RouteModel.theme == target_id,
                RouteModel.content_status == "published",
                RouteModel.published_at.is_not(None),
            )
        )
        catalog_theme = session.scalar(
            select(StoryCatalogItemModel.id).where(
                StoryCatalogItemModel.status == "published",
                StoryCatalogItemModel.published_at.is_not(None),
                StoryCatalogItemModel.themes_json.is_not(None),
            )
        )
        if (
            route_theme
            or catalog_theme
            and any(
                target_id in (item.themes_json or [])
                for item in session.scalars(
                    select(StoryCatalogItemModel).where(
                        StoryCatalogItemModel.status == "published",
                        StoryCatalogItemModel.published_at.is_not(None),
                    )
                )
            )
        ):
            return {"label": target_id}
        return None

    def _favorite_payload(self, session, item: TravelerFavoriteModel) -> dict:
        target = self._resolve_favorite_target(session, item.target_kind, item.target_id)
        return {
            "id": item.id,
            "target_kind": item.target_kind,
            "target_id": item.target_id,
            "favorite": True,
            "available": target is not None,
            "target": target,
            "created_at": item.created_at.isoformat(),
        }
