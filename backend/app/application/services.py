from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from typing import Protocol
from uuid import uuid4

from app.domain.errors import (
    CityNotFoundError,
    DemoArrivalDisabledError,
    JourneyConflictError,
    JourneyNotFoundError,
    RouteNotFoundError,
    TooFarFromStopError,
    UnauthorizedError,
    ValidationError,
)
from app.domain.models import (
    GuestSession,
    Journey,
    JourneyAnswer,
    JourneyStatus,
    Route,
    Stop,
    distance_meters,
)
from app.domain.ports import UnitOfWork


class TokenCodec(Protocol):
    def encode(self, session_id: str, expires_at: datetime) -> str: ...

    def decode(self, token: str) -> str: ...


UnitOfWorkFactory = Callable[[], UnitOfWork]
Clock = Callable[[], datetime]


def utc_now() -> datetime:
    return datetime.now(UTC)


def _aware(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=UTC)


class GuestSessionService:
    def __init__(
        self,
        uow_factory: UnitOfWorkFactory,
        token_codec: TokenCodec,
        ttl_hours: int,
        clock: Clock = utc_now,
    ):
        self.uow_factory = uow_factory
        self.token_codec = token_codec
        self.ttl_hours = ttl_hours
        self.clock = clock

    def create(self) -> tuple[GuestSession, str]:
        now = self.clock()
        guest_session = GuestSession(
            id=str(uuid4()),
            created_at=now,
            expires_at=now + timedelta(hours=self.ttl_hours),
        )
        with self.uow_factory() as uow:
            uow.guest_sessions.add(guest_session)
            uow.commit()
        return guest_session, self.token_codec.encode(guest_session.id, guest_session.expires_at)

    def authenticate(self, token: str) -> GuestSession:
        session_id = self.token_codec.decode(token)
        with self.uow_factory() as uow:
            guest_session = uow.guest_sessions.get(session_id)
        if guest_session is None or _aware(guest_session.expires_at) <= self.clock():
            raise UnauthorizedError("游客会话已失效，请重新进入")
        return guest_session


class CatalogService:
    def __init__(self, uow_factory: UnitOfWorkFactory):
        self.uow_factory = uow_factory

    def list_cities(self):
        with self.uow_factory() as uow:
            return uow.catalog.list_cities()

    def list_city_routes(self, city_slug: str):
        with self.uow_factory() as uow:
            city = uow.catalog.get_city_by_slug(city_slug)
            if city is None:
                raise CityNotFoundError()
            routes = uow.catalog.list_routes_for_city(city.id)
            return city, routes

    def get_route(self, route_slug: str) -> Route:
        with self.uow_factory() as uow:
            route = uow.catalog.get_route_by_slug(route_slug)
        if route is None:
            raise RouteNotFoundError()
        return route

    def get_route_by_id(self, route_id: str) -> Route:
        with self.uow_factory() as uow:
            route = uow.catalog.get_route_by_id(route_id)
        if route is None:
            raise RouteNotFoundError()
        return route


class JourneyService:
    def __init__(
        self,
        uow_factory: UnitOfWorkFactory,
        allow_demo_arrival: bool,
        clock: Clock = utc_now,
    ):
        self.uow_factory = uow_factory
        self.allow_demo_arrival = allow_demo_arrival
        self.clock = clock

    def start_or_resume(self, guest_session_id: str, route_id: str) -> Journey:
        with self.uow_factory() as uow:
            route = uow.catalog.get_route_by_id(route_id)
            if route is None:
                raise RouteNotFoundError()
            existing = uow.journeys.find_active(route_id, guest_session_id)
            if existing:
                return existing
            now = self.clock()
            journey = Journey(
                id=str(uuid4()),
                guest_session_id=guest_session_id,
                route_id=route_id,
                status=JourneyStatus.ACTIVE,
                current_stop_position=1,
                arrived_stop_id=None,
                started_at=now,
                updated_at=now,
            )
            uow.journeys.add(journey)
            uow.commit()
            return journey

    def get(self, guest_session_id: str, journey_id: str) -> Journey:
        with self.uow_factory() as uow:
            journey = uow.journeys.get_for_guest(journey_id, guest_session_id)
        if journey is None:
            raise JourneyNotFoundError()
        return journey

    def arrive(
        self,
        guest_session_id: str,
        journey_id: str,
        *,
        demo: bool,
        latitude: float | None = None,
        longitude: float | None = None,
    ) -> tuple[Journey, float | None]:
        with self.uow_factory() as uow:
            journey, _, stop = self._load_current(uow, guest_session_id, journey_id)
            if demo:
                if not self.allow_demo_arrival:
                    raise DemoArrivalDisabledError()
                distance = None
            else:
                if latitude is None or longitude is None:
                    raise ValidationError("需要提供当前位置，或显式启用演示到达")
                distance = distance_meters(latitude, longitude, stop.latitude, stop.longitude)
                if distance > stop.arrival_radius_m:
                    raise TooFarFromStopError(details={"distance_m": round(distance, 1)})
            journey.arrived_stop_id = stop.id
            journey.updated_at = self.clock()
            uow.journeys.save(journey)
            uow.commit()
            return journey, distance

    def answer(
        self,
        guest_session_id: str,
        journey_id: str,
        stop_id: str,
        selected_option: int,
    ) -> tuple[JourneyAnswer, Stop]:
        with self.uow_factory() as uow:
            journey = uow.journeys.get_for_guest(journey_id, guest_session_id)
            if journey is None:
                raise JourneyNotFoundError()
            route = uow.catalog.get_route_by_id(journey.route_id)
            if route is None:
                raise RouteNotFoundError()
            stop = next((item for item in route.stops if item.id == stop_id), None)
            if stop is None:
                raise ValidationError("站点不存在")
            existing = journey.answer_for(stop_id)
            if existing:
                return existing, stop
            if journey.status is JourneyStatus.COMPLETED:
                raise JourneyConflictError("旅程已经完成")
            current_stop = next(
                (item for item in route.stops if item.position == journey.current_stop_position),
                None,
            )
            if current_stop is None:
                raise JourneyConflictError("旅程站点状态异常")
            if current_stop.id != stop_id:
                raise JourneyConflictError("只能回答当前站点的问题")
            if journey.arrived_stop_id != stop_id:
                raise JourneyConflictError("到达站点后才能回答观察问题")
            if stop.challenge is None:
                raise ValidationError("该站点使用碎片导览任务，不提供传统观察问题")
            if selected_option < 0 or selected_option >= len(stop.challenge.options):
                raise ValidationError("答案选项不存在")
            answer = JourneyAnswer(
                stop_id=stop_id,
                selected_option=selected_option,
                is_correct=selected_option == stop.challenge.correct_option,
                answered_at=self.clock(),
            )
            uow.journeys.add_answer(journey.id, answer)
            journey.updated_at = answer.answered_at
            uow.journeys.save(journey)
            uow.commit()
            return answer, stop

    def advance(self, guest_session_id: str, journey_id: str) -> Journey:
        with self.uow_factory() as uow:
            journey, route, stop = self._load_current(uow, guest_session_id, journey_id)
            if journey.answer_for(stop.id) is None:
                raise JourneyConflictError("完成当前观察问题后才能继续")
            now = self.clock()
            if journey.current_stop_position >= len(route.stops):
                journey.status = JourneyStatus.COMPLETED
                journey.completed_at = now
            else:
                journey.current_stop_position += 1
            journey.arrived_stop_id = None
            journey.updated_at = now
            uow.journeys.save(journey)
            uow.commit()
            return journey

    def recap(self, guest_session_id: str, journey_id: str) -> tuple[Journey, Route]:
        with self.uow_factory() as uow:
            journey = uow.journeys.get_for_guest(journey_id, guest_session_id)
            if journey is None:
                raise JourneyNotFoundError()
            if journey.status is not JourneyStatus.COMPLETED:
                raise JourneyConflictError("完成路线后才会生成旅程回顾")
            route = uow.catalog.get_route_by_id(journey.route_id)
            if route is None:
                raise RouteNotFoundError()
            return journey, route

    @staticmethod
    def _load_current(
        uow: UnitOfWork,
        guest_session_id: str,
        journey_id: str,
    ) -> tuple[Journey, Route, Stop]:
        journey = uow.journeys.get_for_guest(journey_id, guest_session_id)
        if journey is None:
            raise JourneyNotFoundError()
        if journey.status is JourneyStatus.COMPLETED:
            raise JourneyConflictError("旅程已经完成")
        route = uow.catalog.get_route_by_id(journey.route_id)
        if route is None:
            raise RouteNotFoundError()
        try:
            stop = next(
                stop for stop in route.stops if stop.position == journey.current_stop_position
            )
        except StopIteration as exc:
            raise JourneyConflictError("旅程站点状态异常") from exc
        return journey, route, stop
