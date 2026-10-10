"""Standalone community browsing for published places."""

import json
import math
from datetime import UTC, date, datetime
from uuid import uuid4
from zoneinfo import ZoneInfo

from sqlalchemy import and_, func, or_, select
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
    TriggerRegionModel,
)


class CommunityDiscovery:
    @staticmethod
    def _place_query():
        return (
            select(StoryFragmentModel, RouteModel, CityModel, StopModel, TriggerRegionModel)
            .join(StoryArcModel, StoryArcModel.id == StoryFragmentModel.arc_id)
            .join(RouteModel, RouteModel.id == StoryArcModel.route_id)
            .join(CityModel, CityModel.id == RouteModel.city_id)
            .outerjoin(StopModel, StopModel.id == StoryFragmentModel.stop_id)
            .outerjoin(TriggerRegionModel, TriggerRegionModel.fragment_id == StoryFragmentModel.id)
        )

    @staticmethod
    def _place_payload(row):
        fragment, route, city, stop, trigger = row
        return {
            "fragment_id": fragment.id,
            "name": stop.title if stop else fragment.title,
            "route_id": route.id,
            "route_slug": route.slug,
            "route_title": route.title,
            "city_slug": city.slug,
            "city_name": city.name,
            "theme": route.theme,
            "latitude": trigger.latitude if trigger else stop.latitude if stop else None,
            "longitude": trigger.longitude if trigger else stop.longitude if stop else None,
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

    def discover(
        self,
        user_id,
        *,
        city_slug=None,
        category=None,
        latitude=None,
        longitude=None,
        radius_km=None,
        order="latest",
        saved_only=False,
        cursor=None,
        limit=12,
    ):
        self._require_enabled()
        limit = self._limit(limit)
        if category and category not in {"viewpoint", "on_site", "experience", "fact_supplement"}:
            raise ValidationError("见闻类型无效")
        if order not in {"latest", "nearest"}:
            raise ValidationError("排序方式无效")
        try:
            if latitude is not None or longitude is not None:
                latitude, longitude = float(latitude), float(longitude)
                if not (
                    math.isfinite(latitude)
                    and math.isfinite(longitude)
                    and -90 <= latitude <= 90
                    and -180 <= longitude <= 180
                ):
                    raise ValueError
            if radius_km is not None:
                radius_km = float(radius_km)
                if not math.isfinite(radius_km) or not 0 < radius_km <= 20000:
                    raise ValueError
        except (ValueError, TypeError) as exc:
            raise ValidationError("位置或距离范围无效") from exc
        if (radius_km is not None or order == "nearest") and latitude is None:
            raise ValidationError("请先开启定位")
        scope = "discover:" + json.dumps(
            [user_id, city_slug, category, latitude, longitude, radius_km, order, saved_only]
        )
        boundary = self._decode_cursor(cursor, scope) if cursor else None
        with self.session_factory() as session:
            # 1-cos(angle) is monotonic in geographic distance. Using this key
            # avoids inverse trigonometry and works in both SQLite and MySQL.
            lat = func.coalesce(TriggerRegionModel.latitude, StopModel.latitude)
            lon = func.coalesce(TriggerRegionModel.longitude, StopModel.longitude)
            distance_key = 1 - (
                math.sin(math.radians(latitude or 0)) * func.sin(lat * math.pi / 180)
                + math.cos(math.radians(latitude or 0))
                * func.cos(lat * math.pi / 180)
                * func.cos((lon - (longitude or 0)) * math.pi / 180)
            )
            query = (
                select(CommunityPostModel, distance_key.label("distance_key"))
                .join(StoryFragmentModel, StoryFragmentModel.id == CommunityPostModel.fragment_id)
                .join(StoryArcModel, StoryArcModel.id == StoryFragmentModel.arc_id)
                .join(RouteModel, RouteModel.id == StoryArcModel.route_id)
                .join(CityModel, CityModel.id == RouteModel.city_id)
                .outerjoin(StopModel, StopModel.id == StoryFragmentModel.stop_id)
                .outerjoin(
                    TriggerRegionModel, TriggerRegionModel.fragment_id == StoryFragmentModel.id
                )
                .where(
                    RouteModel.content_status == "published",
                    CommunityPostModel.status == "visible",
                    ~self._reported_exists(user_id, "post", CommunityPostModel.id),
                )
            )
            if city_slug:
                query = query.where(CityModel.slug == city_slug)
            if category:
                query = query.where(CommunityPostModel.category == category)
            if saved_only:
                query = query.where(
                    select(TravelerFavoriteModel.id)
                    .where(
                        TravelerFavoriteModel.user_id == user_id,
                        TravelerFavoriteModel.target_kind == "community_post",
                        TravelerFavoriteModel.target_id == CommunityPostModel.id,
                    )
                    .exists()
                )
            if radius_km is not None:
                query = query.where(distance_key <= 1 - math.cos(radius_km / 6371.0088))
            if order == "nearest":
                query = query.where(distance_key.is_not(None))
            total = session.scalar(select(func.count()).select_from(query.subquery()))
            if boundary:
                created_at, item_id = boundary
                if order == "nearest":
                    try:
                        key, item_id = item_id.split("|", 1)
                        key = float(key)
                    except (ValueError, TypeError) as exc:
                        raise ValidationError("cursor 无效") from exc
                older = or_(
                    CommunityPostModel.created_at < created_at,
                    and_(
                        CommunityPostModel.created_at == created_at, CommunityPostModel.id < item_id
                    ),
                )
                query = query.where(
                    or_(distance_key > key, and_(distance_key == key, older))
                    if order == "nearest"
                    else older
                )
            ordering = [CommunityPostModel.created_at.desc(), CommunityPostModel.id.desc()]
            if order == "nearest":
                ordering.insert(0, distance_key.asc())
            rows = list(session.execute(query.order_by(*ordering).limit(limit + 1)))
            has_more = len(rows) > limit
            rows = rows[:limit]
            posts = [row[0] for row in rows]
            next_cursor = None
            if has_more:
                last, key = rows[-1]
                item_id = f"{key:.17g}|{last.id}" if order == "nearest" else last.id
                next_cursor = self._encode_cursor(scope, last.created_at, item_id)
            return {
                "items": self._post_payloads(session, posts, user_id, summary=True),
                "next_cursor": next_cursor,
                "total": total,
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
