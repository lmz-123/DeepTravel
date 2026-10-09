"""Standalone community browsing for published places."""

from datetime import UTC, date, datetime
from uuid import uuid4
from zoneinfo import ZoneInfo

from sqlalchemy import and_, or_, select
from sqlalchemy.exc import IntegrityError

from app.domain.errors import FragmentOperationError, ValidationError
from app.infrastructure.persistence.models import (
    CityModel,
    CommunityPostModel,
    RouteModel,
    StopModel,
    StoryArcModel,
    StoryFragmentModel,
    TravelerFavoriteModel,
)


class CommunityDiscovery:
    @staticmethod
    def _place_query():
        return (
            select(StoryFragmentModel, RouteModel, CityModel, StopModel)
            .join(StoryArcModel, StoryArcModel.id == StoryFragmentModel.arc_id)
            .join(RouteModel, RouteModel.id == StoryArcModel.route_id)
            .join(CityModel, CityModel.id == RouteModel.city_id)
            .outerjoin(StopModel, StopModel.id == StoryFragmentModel.stop_id)
        )

    @staticmethod
    def _place_payload(row):
        fragment, route, city, stop = row
        return {
            "fragment_id": fragment.id,
            "name": stop.title if stop else fragment.title,
            "route_id": route.id,
            "route_slug": route.slug,
            "route_title": route.title,
            "city_slug": city.slug,
            "city_name": city.name,
            "theme": route.theme,
        }

    def places(self, user_id):
        self._require_enabled()
        with self.session_factory() as session:
            rows = session.execute(
                self._place_query()
                .where(RouteModel.content_status == "published")
                .order_by(CityModel.name, RouteModel.title, StoryFragmentModel.position)
            )
            return [self._place_payload(row) for row in rows]

    def discover(self, user_id, *, city_slug=None, cursor=None, limit=12):
        self._require_enabled()
        limit = self._limit(limit)
        scope = f"discover:{city_slug or 'all'}"
        boundary = self._decode_cursor(cursor, scope) if cursor else None
        with self.session_factory() as session:
            query = (
                select(CommunityPostModel)
                .join(StoryFragmentModel, StoryFragmentModel.id == CommunityPostModel.fragment_id)
                .join(StoryArcModel, StoryArcModel.id == StoryFragmentModel.arc_id)
                .join(RouteModel, RouteModel.id == StoryArcModel.route_id)
                .join(CityModel, CityModel.id == RouteModel.city_id)
                .where(
                    RouteModel.content_status == "published",
                    CommunityPostModel.status == "visible",
                    ~self._reported_exists(user_id, "post", CommunityPostModel.id),
                )
            )
            if city_slug:
                query = query.where(CityModel.slug == city_slug)
            if boundary:
                created_at, item_id = boundary
                query = query.where(
                    or_(
                        CommunityPostModel.created_at < created_at,
                        and_(
                            CommunityPostModel.created_at == created_at,
                            CommunityPostModel.id < item_id,
                        ),
                    )
                )
            rows = list(
                session.scalars(
                    query.order_by(
                        CommunityPostModel.created_at.desc(), CommunityPostModel.id.desc()
                    ).limit(limit + 1)
                )
            )
            has_more = len(rows) > limit
            rows = rows[:limit]
            return {
                "items": self._post_payloads(session, rows, user_id, summary=True),
                "next_cursor": self._encode_cursor(scope, rows[-1].created_at, rows[-1].id)
                if has_more
                else None,
            }

    def _published_place(self, session, fragment_id):
        row = session.execute(
            self._place_query().where(
                StoryFragmentModel.id == fragment_id, RouteModel.content_status == "published"
            )
        ).first()
        if row is None:
            raise FragmentOperationError(
                "community_place_unavailable", "地点暂不可用", status_code=404
            )
        return row

    @staticmethod
    def _visit_date(value):
        if not value:
            return None
        try:
            parsed = date.fromisoformat(value)
        except (TypeError, ValueError) as exc:
            raise ValidationError("到访日期格式不正确") from exc
        if parsed > datetime.now(ZoneInfo("Asia/Shanghai")).date():
            raise ValidationError("到访日期不能晚于今天")
        return parsed.isoformat()

    def set_saved(self, user_id, post_id, saved):
        self._require_enabled()
        with self.session_factory() as session:
            if saved:
                self._visible_post(session, user_id, post_id)
            item = session.scalar(
                select(TravelerFavoriteModel).where(
                    TravelerFavoriteModel.user_id == user_id,
                    TravelerFavoriteModel.target_kind == "community_post",
                    TravelerFavoriteModel.target_id == post_id,
                )
            )
            if saved and item is None:
                session.add(
                    TravelerFavoriteModel(
                        id=str(uuid4()),
                        user_id=user_id,
                        target_kind="community_post",
                        target_id=post_id,
                        created_at=datetime.now(UTC),
                    )
                )
            elif not saved and item is not None:
                session.delete(item)
            try:
                session.commit()
            except IntegrityError:
                session.rollback()
                # Only an overlapping save is an idempotent success.
                exists = (
                    session.scalar(
                        select(TravelerFavoriteModel.id).where(
                            TravelerFavoriteModel.user_id == user_id,
                            TravelerFavoriteModel.target_kind == "community_post",
                            TravelerFavoriteModel.target_id == post_id,
                        )
                    )
                    is not None
                )
                if not saved or not exists:
                    raise
            return {"viewer_has_saved": saved}
