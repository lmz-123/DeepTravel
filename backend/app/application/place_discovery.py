"""SQL-paged public place browsing, independent of narration manifests."""

import hashlib
import math

from itsdangerous import BadData, URLSafeSerializer
from sqlalchemy import and_, case, func, or_, select

from app.domain.errors import RouteNotFoundError, ValidationError
from app.infrastructure.persistence.models import (
    CityModel,
    RouteModel,
    StopModel,
    StoryArcModel,
    StoryCatalogItemModel,
    StoryFragmentModel,
    TriggerRegionModel,
)

CATEGORIES = {
    "coast": "海边",
    "nature": "山野",
    "streets": "街巷",
    "architecture": "建筑",
    "park": "公园",
    "other": "其他",
}
KEYWORDS = [
    ("coast", "海边 海岸 海滨 滨海 海岛 海滩 沙滩 大梅沙"),
    ("nature", "山 自然 森林 郊野"),
    ("streets", "街 巷 古城 老城 历史 南头 西关 永庆坊"),
    ("architecture", "建筑 设计 艺术 商业 万象"),
    ("park", "公园 园林 花园 绿地"),
]


class PlaceDiscovery:
    def __init__(self, session_factory, secret):
        self.session_factory = session_factory
        self.cursors = URLSafeSerializer(secret, salt="public-place-page-v1")

    @staticmethod
    def _projection():
        # Aggregate only geographic columns: no stop text, audio or ticket payloads.
        stops = (
            select(
                StopModel.route_id,
                ((func.min(StopModel.latitude) + func.max(StopModel.latitude)) / 2).label("lat"),
                ((func.min(StopModel.longitude) + func.max(StopModel.longitude)) / 2).label("lon"),
                func.count().label("count"),
            )
            .where(
                StopModel.latitude.between(-85, 85),
                StopModel.longitude.between(-180, 180),
                or_(StopModel.latitude != 0, StopModel.longitude != 0),
            )
            .group_by(StopModel.route_id)
            .subquery()
        )
        fragments = (
            select(
                StoryArcModel.route_id,
                (
                    (func.min(TriggerRegionModel.latitude) + func.max(TriggerRegionModel.latitude))
                    / 2
                ).label("lat"),
                (
                    (
                        func.min(TriggerRegionModel.longitude)
                        + func.max(TriggerRegionModel.longitude)
                    )
                    / 2
                ).label("lon"),
                func.count(StoryFragmentModel.id).label("count"),
            )
            .join(StoryFragmentModel, StoryFragmentModel.arc_id == StoryArcModel.id)
            .outerjoin(
                TriggerRegionModel,
                and_(
                    TriggerRegionModel.fragment_id == StoryFragmentModel.id,
                    TriggerRegionModel.latitude.between(-85, 85),
                    TriggerRegionModel.longitude.between(-180, 180),
                    or_(TriggerRegionModel.latitude != 0, TriggerRegionModel.longitude != 0),
                ),
            )
            .group_by(StoryArcModel.route_id)
            .subquery()
        )
        district = (
            select(StoryCatalogItemModel.district)
            .join(
                StoryArcModel,
                and_(
                    StoryCatalogItemModel.source_kind == "story_arc",
                    StoryCatalogItemModel.source_id == StoryArcModel.id,
                ),
            )
            .where(
                StoryArcModel.route_id == RouteModel.id, StoryCatalogItemModel.status == "published"
            )
            .limit(1)
            .scalar_subquery()
        )

        def classify(column):
            return case(
                *[
                    (or_(*(column.contains(w) for w in words.split())), key)
                    for key, words in KEYWORDS
                ],
                else_=None,
            )

        category = case(
            (RouteModel.map_category.in_(list(CATEGORIES)), RouteModel.map_category),
            else_=func.coalesce(classify(RouteModel.theme), classify(RouteModel.title), "other"),
        )
        return (
            select(
                RouteModel.id,
                RouteModel.city_id,
                RouteModel.slug,
                RouteModel.title,
                RouteModel.subtitle,
                func.substr(RouteModel.description, 1, 600).label("description"),
                RouteModel.duration_minutes,
                RouteModel.distance_km,
                RouteModel.difficulty,
                RouteModel.theme,
                category.label("map_category"),
                RouteModel.hero_image,
                RouteModel.is_featured,
                RouteModel.content_status,
                func.coalesce(district, "").label("district"),
                func.coalesce(fragments.c.lat, stops.c.lat).label("latitude"),
                func.coalesce(fragments.c.lon, stops.c.lon).label("longitude"),
                func.coalesce(fragments.c.count, stops.c.count, 0).label("stop_count"),
                (func.coalesce(fragments.c.count, 0) > 0).label("supports_companion"),
                RouteModel.travel_preparation["admission"].as_string().label("admission"),
                RouteModel.travel_preparation["enabled"].as_boolean().label("preparation_enabled"),
                CityModel.name.label("city_name"),
                CityModel.slug.label("city_slug"),
            )
            .join(CityModel, CityModel.id == RouteModel.city_id)
            .outerjoin(stops, stops.c.route_id == RouteModel.id)
            .outerjoin(fragments, fragments.c.route_id == RouteModel.id)
            .where(RouteModel.content_status == "published")
            .subquery()
        )

    @staticmethod
    def _query_options(city, args):
        q = str(args.get("q", "")).strip()
        region = str(args.get("district", "")).strip()
        category = args.get("category", "")
        order = args.get("order", "recommended")
        if len(q) > 120 or len(region) > 120 or category not in ["", *CATEGORIES]:
            raise ValidationError("景点筛选条件无效")
        if order not in {"recommended", "nearest"}:
            raise ValidationError("排序方式无效")
        lat, lon = args.get("latitude"), args.get("longitude")
        try:
            if lat is not None or lon is not None:
                lat, lon = float(lat), float(lon)
                if not (
                    math.isfinite(lat)
                    and math.isfinite(lon)
                    and -85 <= lat <= 85
                    and -180 <= lon <= 180
                ):
                    raise ValueError
        except (TypeError, ValueError) as exc:
            raise ValidationError("位置无效") from exc
        if order == "nearest" and lat is None:
            raise ValidationError("请先开启定位")
        return [city, q, region, category, order, lat, lon]

    def browse(self, city, args, *, markers=False, directory=False):
        options = self._query_options(city, args)
        _, text, district, category, order, lat, lon = options
        try:
            limit = min(int(args.get("limit", 12)), 20)
            if limit < 1:
                raise ValueError
        except (ValueError, TypeError) as exc:
            raise ValidationError("limit 必须为正整数") from exc
        scope = hashlib.sha256(repr(options).encode()).hexdigest()
        boundary = None
        if args.get("cursor"):
            try:
                boundary = self.cursors.loads(args["cursor"])
                if boundary["scope"] != scope or not isinstance(boundary["id"], str):
                    raise ValueError
                if not math.isfinite(float(boundary["key"])):
                    raise ValueError
            except (BadData, ValueError, TypeError, KeyError) as exc:
                raise ValidationError("cursor 无效或与当前筛选条件不匹配") from exc
        p = self._projection().c
        distance = func.coalesce(
            1
            - (
                math.sin(math.radians(lat or 0)) * func.sin(p.latitude * math.pi / 180)
                + math.cos(math.radians(lat or 0))
                * func.cos(p.latitude * math.pi / 180)
                * func.cos((p.longitude - (lon or 0)) * math.pi / 180)
            ),
            3.0,
        )
        rank = distance if order == "nearest" else case((p.is_featured.is_(True), 0), else_=1)
        base = select(*p, rank.label("sort_key")).where(p.city_slug == city)
        filtered = base
        if text:
            filtered = filtered.where(
                or_(
                    p.title.contains(text, autoescape=True),
                    p.subtitle.contains(text, autoescape=True),
                    p.district.contains(text, autoescape=True),
                )
            )
        if district:
            filtered = filtered.where(p.district == district)
        if category:
            filtered = filtered.where(p.map_category == category)
        with self.session_factory() as session:
            if session.scalar(select(CityModel.id).where(CityModel.slug == city)) is None:
                raise RouteNotFoundError("城市不存在")
            total = session.scalar(select(func.count()).select_from(filtered.subquery()))
            facets = session.execute(
                select(p.map_category, p.district).where(p.city_slug == city).distinct()
            ).all()
            if boundary and not (markers or directory):
                filtered = filtered.where(
                    or_(
                        rank > boundary["key"], and_(rank == boundary["key"], p.id > boundary["id"])
                    )
                )
            if markers:
                # Only the coordinates and identity needed by the map cross the wire.
                query = filtered.with_only_columns(
                    p.id, p.slug, p.title, p.map_category, p.district, p.latitude, p.longitude
                )
                rows = session.execute(query.order_by(p.id)).mappings().all()
            else:
                query = filtered.order_by(rank, p.id)
                rows = session.execute(query if directory else query.limit(limit + 1))
                rows = rows.mappings().all()
            more = not (directory or markers) and len(rows) > limit
            rows = rows[:limit] if more else rows
            cursor = (
                self.cursors.dumps(
                    {"scope": scope, "key": rows[-1]["sort_key"], "id": rows[-1]["id"]}
                )
                if more
                else None
            )
            return {
                "items": [self._payload(row, markers) for row in rows],
                "total": total,
                "next_cursor": cursor,
                "categories": [k for k in CATEGORIES if any(c == k for c, _ in facets)],
                "districts": sorted({d for _, d in facets if d}),
            }

    def place(self, slug):
        p = self._projection()
        with self.session_factory() as session:
            row = session.execute(select(p).where(p.c.slug == slug)).mappings().first()
            if row is None:
                raise RouteNotFoundError()
            return self._payload(row, False)

    @staticmethod
    def _payload(row, marker):
        value = dict(row)
        lat, lon = value.pop("latitude"), value.pop("longitude")
        value["center"] = {"latitude": lat, "longitude": lon} if lat is not None else None
        value.pop("sort_key", None)
        if not marker:
            value["city"] = {"name": value.pop("city_name"), "slug": value.pop("city_slug")}
            value["travel_preparation"] = {
                "enabled": bool(value.pop("preparation_enabled")),
                "admission": value.pop("admission") or "unknown",
            }
        return value
