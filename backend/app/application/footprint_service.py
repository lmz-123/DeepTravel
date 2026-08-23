from __future__ import annotations

import base64
import json
from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import and_, func, or_, select
from sqlalchemy.orm import joinedload

from app.domain.errors import FragmentOperationError, ValidationError
from app.infrastructure.persistence.models import (
    CityModel,
    EvidenceModel,
    FootprintEntryModel,
    FootprintPhotoModel,
    FootprintThemeModel,
    JourneyAnswerModel,
    JourneyFragmentModel,
    JourneyModel,
    PhotoMissionModel,
    RouteModel,
    StopModel,
    StoryArcModel,
    StoryCatalogItemModel,
    StoryFragmentModel,
)

REVEALED_FRAGMENT_STATES = {
    "triggered",
    "playing",
    "played",
    "evidence_pending",
    "collected",
    "reconstructed",
}
REVIEWED_STATES = {"reviewed", "approved", "verified", "published"}
OBSERVATION_MAX = 280
SENTENCE_MAX = 160


class FootprintService:
    """Owns private, voice-independent snapshots of a traveler's city memories."""

    def __init__(self, session_factory, photo_storage):
        self.session_factory = session_factory
        self.photo_storage = photo_storage

    def reconcile_journey(self, user_id: str, journey_id: str) -> dict:
        with self.session_factory() as session:
            journey = session.scalar(
                select(JourneyModel).where(
                    JourneyModel.id == journey_id,
                    JourneyModel.user_id == user_id,
                )
            )
            if journey is None:
                raise self._not_found()
            created = self._reconcile_journey(session, journey)
            session.commit()
            return {"journey_id": journey_id, "created": created}

    def list(
        self,
        user_id: str,
        *,
        city_slug: str | None = None,
        theme: str | None = None,
        journey_state: str | None = None,
        organization_state: str | None = None,
        month: str | None = None,
        order: str = "recent",
        cursor: str | None = None,
        limit: int = 20,
    ) -> dict:
        if order not in {"recent", "oldest"}:
            raise ValidationError("order 仅支持 recent 或 oldest")
        if journey_state not in {None, "partial", "completed"}:
            raise ValidationError("journey_state 仅支持 partial 或 completed")
        if organization_state not in {None, "draft", "organized"}:
            raise ValidationError("organization_state 仅支持 draft 或 organized")
        if limit < 1 or limit > 50:
            raise ValidationError("limit 必须在 1 到 50 之间")
        cursor_value = self._decode_cursor(cursor)
        with self.session_factory() as session:
            self._reconcile_user(session, user_id)
            session.commit()
            query = select(FootprintEntryModel).where(FootprintEntryModel.user_id == user_id)
            if city_slug:
                query = query.where(FootprintEntryModel.city_slug == city_slug.strip())
            if theme:
                query = query.join(
                    FootprintThemeModel,
                    FootprintThemeModel.footprint_id == FootprintEntryModel.id,
                ).where(FootprintThemeModel.theme == theme.strip())
            if journey_state == "partial":
                query = query.where(FootprintEntryModel.journey_completed_at.is_(None))
            elif journey_state == "completed":
                query = query.where(FootprintEntryModel.journey_completed_at.is_not(None))
            if organization_state:
                query = query.where(FootprintEntryModel.organization_state == organization_state)
            if month:
                start, end = self._month_bounds(month)
                query = query.where(
                    FootprintEntryModel.created_at >= start,
                    FootprintEntryModel.created_at < end,
                )
            ordering = (
                (FootprintEntryModel.created_at.asc(), FootprintEntryModel.id.asc())
                if order == "oldest"
                else (FootprintEntryModel.created_at.desc(), FootprintEntryModel.id.desc())
            )
            total = session.scalar(select(func.count()).select_from(query.subquery())) or 0
            if cursor_value is not None:
                cursor_time, cursor_id = cursor_value
                if order == "oldest":
                    query = query.where(
                        or_(
                            FootprintEntryModel.created_at > cursor_time,
                            and_(
                                FootprintEntryModel.created_at == cursor_time,
                                FootprintEntryModel.id > cursor_id,
                            ),
                        )
                    )
                else:
                    query = query.where(
                        or_(
                            FootprintEntryModel.created_at < cursor_time,
                            and_(
                                FootprintEntryModel.created_at == cursor_time,
                                FootprintEntryModel.id < cursor_id,
                            ),
                        )
                    )
            rows = list(
                session.scalars(
                    query.options(joinedload(FootprintEntryModel.photo))
                    .order_by(*ordering)
                    .limit(limit + 1)
                ).unique()
            )
            has_more = len(rows) > limit
            page = rows[:limit]
            last = page[-1] if has_more and page else None
            return {
                "items": [self._payload(row) for row in page],
                "next_cursor": self._encode_cursor(last.created_at, last.id)
                if last is not None
                else None,
                "total": total,
                "facets": self._facets(session, user_id),
            }

    def resume_candidate(self, user_id: str) -> dict | None:
        with self.session_factory() as session:
            self._reconcile_user(session, user_id)
            session.commit()
            row = session.scalar(
                select(FootprintEntryModel)
                .join(JourneyModel, JourneyModel.id == FootprintEntryModel.journey_id)
                .where(
                    FootprintEntryModel.user_id == user_id,
                    or_(
                        FootprintEntryModel.organization_state == "draft",
                        JourneyModel.status == "active",
                    ),
                )
                .options(joinedload(FootprintEntryModel.photo))
                .order_by(FootprintEntryModel.updated_at.desc(), FootprintEntryModel.id.desc())
            )
            return self._payload(row) if row is not None else None

    def detail(self, user_id: str, footprint_id: str) -> dict:
        with self.session_factory() as session:
            row = self._owned(session, user_id, footprint_id)
            return self._payload(row)

    def update(self, user_id: str, footprint_id: str, payload: dict) -> dict:
        allowed = {
            "selected_summary_id",
            "user_observation",
            "user_sentence",
            "defer_organization",
        }
        unknown = set(payload) - allowed
        if unknown:
            raise ValidationError(f"不支持的足迹字段：{', '.join(sorted(unknown))}")
        with self.session_factory() as session:
            row = self._owned(session, user_id, footprint_id)
            if "selected_summary_id" in payload:
                selected_id = payload["selected_summary_id"]
                if selected_id is not None and not isinstance(selected_id, str):
                    raise ValidationError("selected_summary_id 必须是字符串或 null")
                option = next(
                    (
                        item
                        for item in row.summary_options_json or []
                        if isinstance(item, dict) and item.get("id") == selected_id
                    ),
                    None,
                )
                if selected_id and option is None:
                    raise ValidationError("概括选项不存在")
                row.selected_summary_id = selected_id or None
                row.selected_summary_text = str(option.get("text")) if option else None
            if "user_observation" in payload:
                row.user_observation = self._optional_text(
                    payload["user_observation"], "user_observation", OBSERVATION_MAX
                )
            if "user_sentence" in payload:
                row.user_sentence = self._optional_text(
                    payload["user_sentence"], "user_sentence", SENTENCE_MAX
                )
            defer = payload.get("defer_organization")
            if defer is not None and not isinstance(defer, bool):
                raise ValidationError("defer_organization 必须是布尔值")
            has_personal_content = bool(
                row.selected_summary_text or row.user_observation or row.user_sentence
            )
            row.organization_state = (
                "draft" if defer is True or not has_personal_content else "organized"
            )
            row.updated_at = datetime.now(UTC)
            session.commit()
            session.refresh(row)
            return self._payload(row)

    def related_content(self, user_id: str, footprint_id: str) -> list[dict]:
        with self.session_factory() as session:
            row = self._owned(session, user_id, footprint_id)
            items = list(
                session.scalars(
                    select(StoryCatalogItemModel)
                    .where(
                        StoryCatalogItemModel.city_id == row.city_id,
                        StoryCatalogItemModel.status == "published",
                        StoryCatalogItemModel.published_at.is_not(None),
                    )
                    .order_by(
                        StoryCatalogItemModel.published_at.desc(),
                        StoryCatalogItemModel.id,
                    )
                )
            )
            themes = set(row.themes_json or [])
            items.sort(
                key=lambda item: (
                    0 if themes.intersection(item.themes_json or []) else 1,
                    -(item.published_at.timestamp() if item.published_at else 0),
                )
            )
            return [
                {
                    "id": item.id,
                    "city_slug": row.city_slug,
                    "title": item.title,
                    "summary": item.summary,
                    "cover_image": item.cover_image,
                    "themes": list(item.themes_json or []),
                    "content_type": item.content_type,
                }
                for item in items[:6]
            ]

    def upload_photo(self, user_id: str, footprint_id: str, file, idempotency_key: str) -> dict:
        idempotency_key = idempotency_key.strip()
        if not idempotency_key or len(idempotency_key) > 80:
            raise ValidationError("idempotency_key 为必填字符串，且不能超过 80 个字符")
        with self.session_factory() as session:
            row = self._owned(session, user_id, footprint_id)
            old = row.photo
            if (
                old is not None
                and old.deleted_at is None
                and old.idempotency_key == idempotency_key
            ):
                return self._photo_payload(row.id, old)
            stored = self.photo_storage.put(
                file.stream,
                file.mimetype or "application/octet-stream",
                scope=f"{user_id}/{footprint_id}",
            )
            now = datetime.now(UTC)
            try:
                if old is None:
                    photo = FootprintPhotoModel(id=str(uuid4()), footprint_id=row.id)
                    session.add(photo)
                else:
                    photo = old
                old_key = old.object_key if old is not None else None
                photo.object_key = stored.object_key
                photo.storage_provider = self.photo_storage.provider
                photo.canonical_reference = self.photo_storage.canonical_reference(
                    stored.object_key
                )
                photo.mime_type = stored.mime_type
                photo.size_bytes = stored.size_bytes
                photo.sha256 = stored.sha256
                photo.width = stored.width
                photo.height = stored.height
                photo.idempotency_key = idempotency_key
                photo.created_at = photo.created_at if old is not None else now
                photo.updated_at = now
                photo.deleted_at = None
                row.updated_at = now
                session.commit()
            except Exception:
                self.photo_storage.delete(stored.object_key)
                raise
            if old_key and old_key != stored.object_key:
                self.photo_storage.delete(old_key)
            return self._photo_payload(row.id, photo)

    def open_photo(self, user_id: str, footprint_id: str):
        with self.session_factory() as session:
            row = self._owned(session, user_id, footprint_id)
            if row.photo is None or row.photo.deleted_at is not None:
                raise self._not_found("足迹照片不存在")
            return self.photo_storage.open(row.photo.object_key), row.photo.mime_type

    def delete_photo(self, user_id: str, footprint_id: str) -> dict:
        with self.session_factory() as session:
            row = self._owned(session, user_id, footprint_id)
            if row.photo is None or row.photo.deleted_at is not None:
                return {"deleted": False}
            object_key = row.photo.object_key
            row.photo.deleted_at = datetime.now(UTC)
            row.photo.updated_at = row.photo.deleted_at
            row.updated_at = row.photo.deleted_at
            session.commit()
            self.photo_storage.delete(object_key)
            return {"deleted": True}

    def backfill(self, *, dry_run: bool = False, copy_photos: bool = True) -> dict:
        with self.session_factory() as session:
            users = list(session.scalars(select(JourneyModel.user_id).distinct()))
            before = session.query(FootprintEntryModel).count()
            for user_id in users:
                self._reconcile_user(session, user_id)
            session.flush()
            copied = 0
            failures: list[dict] = []
            staged_keys: list[str] = []
            if copy_photos and not dry_run:
                copied, failures, staged_keys = self._copy_legacy_photos(session)
            after = session.query(FootprintEntryModel).count()
            if dry_run:
                session.rollback()
            else:
                try:
                    session.commit()
                except Exception:
                    session.rollback()
                    for object_key in staged_keys:
                        self.photo_storage.delete(object_key)
                    raise
            return {
                "created": after - before,
                "photos_copied": copied,
                "failures": failures,
                "dry_run": dry_run,
            }

    def _reconcile_user(self, session, user_id: str) -> int:
        journeys = list(
            session.scalars(select(JourneyModel).where(JourneyModel.user_id == user_id))
        )
        return sum(self._reconcile_journey(session, journey) for journey in journeys)

    def _reconcile_journey(self, session, journey: JourneyModel) -> int:
        created = 0
        fragment_rows = session.execute(
            select(
                JourneyFragmentModel,
                StoryFragmentModel,
                StoryArcModel,
                RouteModel,
                CityModel,
                StopModel,
            )
            .join(StoryFragmentModel, StoryFragmentModel.id == JourneyFragmentModel.fragment_id)
            .join(StoryArcModel, StoryArcModel.id == StoryFragmentModel.arc_id)
            .join(RouteModel, RouteModel.id == StoryArcModel.route_id)
            .join(CityModel, CityModel.id == RouteModel.city_id)
            .outerjoin(StopModel, StopModel.id == StoryFragmentModel.stop_id)
            .where(
                JourneyFragmentModel.journey_id == journey.id,
                JourneyFragmentModel.state.in_(REVEALED_FRAGMENT_STATES),
            )
        ).all()
        for progress, fragment, _arc, route, city, stop in fragment_rows:
            occurred_at = progress.triggered_at or journey.started_at
            created += self._upsert_snapshot(
                session,
                journey,
                source_kind="story_fragment",
                source_id=fragment.id,
                city=city,
                scene_id=stop.id if stop is not None else fragment.id,
                scene_title=stop.title if stop is not None else route.title,
                story_title=fragment.title,
                editorial_summary=self._fragment_summary(fragment),
                summary_options=self._summary_options(
                    fragment.footprint_summary_options_json,
                    self._fragment_summary(fragment),
                ),
                themes=list(fragment.experience_tags_json or [route.theme]),
                source_revision=fragment.script_version,
                occurred_at=occurred_at,
            )
        answer_rows = session.execute(
            select(JourneyAnswerModel, StopModel, RouteModel, CityModel)
            .join(StopModel, StopModel.id == JourneyAnswerModel.stop_id)
            .join(RouteModel, RouteModel.id == StopModel.route_id)
            .join(CityModel, CityModel.id == RouteModel.city_id)
            .where(JourneyAnswerModel.journey_id == journey.id)
        ).all()
        for answer, stop, route, city in answer_rows:
            created += self._upsert_snapshot(
                session,
                journey,
                source_kind="legacy_stop",
                source_id=stop.id,
                city=city,
                scene_id=stop.id,
                scene_title=stop.title,
                story_title=stop.story_title,
                editorial_summary=stop.insight or stop.story_body,
                summary_options=self._summary_options(None, stop.insight or stop.story_body),
                themes=list(stop.experience_tags_json or [route.theme]),
                source_revision=route.managed_package_version or "legacy",
                occurred_at=answer.answered_at,
            )
        session.flush()
        session.query(FootprintEntryModel).filter(
            FootprintEntryModel.user_id == journey.user_id,
            FootprintEntryModel.journey_id == journey.id,
        ).update({FootprintEntryModel.journey_completed_at: journey.completed_at})
        return created

    def _upsert_snapshot(
        self,
        session,
        journey: JourneyModel,
        *,
        source_kind: str,
        source_id: str,
        city: CityModel,
        scene_id: str,
        scene_title: str,
        story_title: str,
        editorial_summary: str,
        summary_options: list[dict],
        themes: list[str],
        source_revision: str | None,
        occurred_at: datetime,
    ) -> int:
        existing = session.scalar(
            select(FootprintEntryModel).where(
                FootprintEntryModel.user_id == journey.user_id,
                FootprintEntryModel.journey_id == journey.id,
                FootprintEntryModel.source_kind == source_kind,
                FootprintEntryModel.source_id == source_id,
            )
        )
        if existing is not None:
            return 0
        clean_themes = list(
            dict.fromkeys(value.strip() for value in themes if value and value.strip())
        )
        now = datetime.now(UTC)
        entry = FootprintEntryModel(
            id=str(uuid4()),
            user_id=journey.user_id,
            journey_id=journey.id,
            source_kind=source_kind,
            source_id=source_id,
            city_id=city.id,
            city_slug=city.slug,
            city_name=city.name,
            scene_id=scene_id,
            scene_title=scene_title,
            story_title=story_title,
            editorial_summary=editorial_summary.strip(),
            source_revision=source_revision,
            summary_options_json=summary_options,
            themes_json=clean_themes,
            organization_state="draft",
            journey_completed_at=journey.completed_at,
            created_at=occurred_at or now,
            updated_at=now,
        )
        session.add(entry)
        session.flush()
        session.add_all(
            FootprintThemeModel(
                footprint_id=entry.id,
                user_id=journey.user_id,
                theme=theme,
            )
            for theme in clean_themes
        )
        return 1

    def _copy_legacy_photos(self, session) -> tuple[int, list[dict], list[str]]:
        copied = 0
        failures: list[dict] = []
        staged_keys: list[str] = []
        now = datetime.now(UTC)
        entries = list(
            session.scalars(
                select(FootprintEntryModel)
                .where(FootprintEntryModel.source_kind == "story_fragment")
                .options(joinedload(FootprintEntryModel.photo))
            ).unique()
        )
        for entry in entries:
            if entry.photo is not None:
                continue
            evidence = session.scalar(
                select(EvidenceModel)
                .join(PhotoMissionModel, PhotoMissionModel.id == EvidenceModel.mission_id)
                .where(
                    EvidenceModel.journey_id == entry.journey_id,
                    PhotoMissionModel.fragment_id == entry.source_id,
                    EvidenceModel.deleted_at.is_(None),
                    EvidenceModel.expires_at > now,
                )
                .order_by(EvidenceModel.uploaded_at, EvidenceModel.id)
            )
            if evidence is None:
                continue
            try:
                with self.photo_storage.open(evidence.object_key) as stream:
                    stored = self.photo_storage.put(
                        stream,
                        evidence.mime_type,
                        scope=f"{entry.user_id}/{entry.id}",
                    )
            except Exception:
                failures.append(
                    {
                        "footprint_id": entry.id,
                        "evidence_id": evidence.id,
                        "code": "photo_copy_failed",
                    }
                )
                continue
            staged_keys.append(stored.object_key)
            session.add(
                FootprintPhotoModel(
                    id=str(uuid4()),
                    footprint_id=entry.id,
                    object_key=stored.object_key,
                    storage_provider=self.photo_storage.provider,
                    canonical_reference=self.photo_storage.canonical_reference(stored.object_key),
                    mime_type=stored.mime_type,
                    size_bytes=stored.size_bytes,
                    sha256=stored.sha256,
                    width=stored.width,
                    height=stored.height,
                    idempotency_key=f"backfill:{evidence.id}"[:80],
                    created_at=now,
                    updated_at=now,
                    deleted_at=None,
                )
            )
            copied += 1
        return copied, failures, staged_keys

    def _owned(self, session, user_id: str, footprint_id: str) -> FootprintEntryModel:
        row = session.scalar(
            select(FootprintEntryModel)
            .where(
                FootprintEntryModel.id == footprint_id,
                FootprintEntryModel.user_id == user_id,
            )
            .options(joinedload(FootprintEntryModel.photo))
        )
        if row is None:
            raise self._not_found()
        return row

    def _facets(self, session, user_id: str) -> dict:
        rows = list(
            session.scalars(
                select(FootprintEntryModel).where(FootprintEntryModel.user_id == user_id)
            )
        )
        cities: dict[str, dict] = {}
        themes: dict[str, int] = {}
        months: dict[str, int] = {}
        for row in rows:
            city = cities.setdefault(
                row.city_slug,
                {"slug": row.city_slug, "name": row.city_name, "count": 0},
            )
            city["count"] += 1
            for theme in row.themes_json or []:
                themes[theme] = themes.get(theme, 0) + 1
            month = row.created_at.strftime("%Y-%m")
            months[month] = months.get(month, 0) + 1
        return {
            "cities": sorted(cities.values(), key=lambda item: (-item["count"], item["slug"])),
            "themes": [
                {"name": name, "count": count}
                for name, count in sorted(themes.items(), key=lambda item: (-item[1], item[0]))
            ],
            "months": [
                {
                    "key": key,
                    "label": f"{key[:4]}年{int(key[5:])}月",
                    "count": count,
                }
                for key, count in sorted(months.items(), reverse=True)
            ],
        }

    def _payload(self, row: FootprintEntryModel) -> dict:
        return {
            "id": row.id,
            "journey_id": row.journey_id,
            "source": {"kind": row.source_kind, "id": row.source_id},
            "city": {"id": row.city_id, "slug": row.city_slug, "name": row.city_name},
            "scene": {"id": row.scene_id, "title": row.scene_title},
            "story_title": row.story_title,
            "jian_di_narrative": {
                "editorial_summary": row.editorial_summary,
                "summary_options": list(row.summary_options_json or []),
            },
            "what_i_saw": {
                "observation": row.user_observation,
                "photo": self._photo_payload(row.id, row.photo)
                if row.photo and row.photo.deleted_at is None
                else None,
            },
            "what_i_left": {
                "selected_summary_id": row.selected_summary_id,
                "selected_summary_text": row.selected_summary_text,
                "sentence": row.user_sentence,
            },
            "themes": list(row.themes_json or []),
            "organization_state": row.organization_state,
            "journey_state": "completed" if row.journey_completed_at else "partial",
            "created_at": row.created_at.isoformat(),
            "updated_at": row.updated_at.isoformat(),
        }

    @staticmethod
    def _photo_payload(footprint_id: str, photo: FootprintPhotoModel) -> dict:
        return {
            "id": photo.id,
            "url": f"/api/v1/footprints/{footprint_id}/photo",
            "mime_type": photo.mime_type,
            "width": photo.width,
            "height": photo.height,
            "created_at": photo.created_at.isoformat(),
            "private": True,
        }

    @staticmethod
    def _fragment_summary(fragment: StoryFragmentModel) -> str:
        if fragment.footprint_editorial_summary and fragment.review_state in REVIEWED_STATES:
            return fragment.footprint_editorial_summary
        return fragment.key_claim or fragment.safe_preview

    @staticmethod
    def _summary_options(raw: list[dict] | None, fallback: str) -> list[dict]:
        result: list[dict] = []
        for index, item in enumerate(raw or []):
            if isinstance(item, str):
                item_id, text = f"option-{index + 1}", item
            elif isinstance(item, dict):
                item_id = str(item.get("id") or f"option-{index + 1}").strip()
                text = str(item.get("text") or "").strip()
            else:
                continue
            if item_id and text and len(text) <= SENTENCE_MAX:
                result.append({"id": item_id, "text": text})
        if not result and fallback.strip():
            result.append({"id": "editorial", "text": fallback.strip()[:SENTENCE_MAX]})
        return result[:8]

    @staticmethod
    def _optional_text(value, field: str, max_length: int) -> str | None:
        if value is None:
            return None
        if not isinstance(value, str):
            raise ValidationError(f"{field} 必须是字符串或 null")
        clean = value.strip()
        if len(clean) > max_length:
            raise ValidationError(f"{field} 不能超过 {max_length} 个字符")
        return clean or None

    @staticmethod
    def _encode_cursor(created_at: datetime, footprint_id: str) -> str:
        raw = json.dumps(
            {"created_at": created_at.isoformat(), "id": footprint_id},
            separators=(",", ":"),
        )
        return base64.urlsafe_b64encode(raw.encode()).decode().rstrip("=")

    @staticmethod
    def _decode_cursor(cursor: str | None) -> tuple[datetime, str] | None:
        if not cursor:
            return None
        try:
            padded = cursor + "=" * (-len(cursor) % 4)
            value = json.loads(base64.urlsafe_b64decode(padded.encode()).decode())
            created_at = datetime.fromisoformat(str(value["created_at"]))
            footprint_id = str(value["id"])
            if not footprint_id:
                raise ValueError
            return created_at, footprint_id
        except (
            KeyError,
            TypeError,
            ValueError,
            json.JSONDecodeError,
            UnicodeDecodeError,
        ) as exc:
            raise ValidationError("cursor 无效") from exc

    @staticmethod
    def _month_bounds(value: str) -> tuple[datetime, datetime]:
        try:
            start = datetime.strptime(value, "%Y-%m").replace(tzinfo=UTC)
        except ValueError as exc:
            raise ValidationError("month 必须为 YYYY-MM") from exc
        end = (
            start.replace(year=start.year + 1, month=1)
            if start.month == 12
            else start.replace(month=start.month + 1)
        )
        return start, end

    @staticmethod
    def _not_found(message: str = "足迹不存在") -> FragmentOperationError:
        return FragmentOperationError("footprint_not_found", message, status_code=404)
