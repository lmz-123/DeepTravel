from __future__ import annotations

import re
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from threading import Lock
from typing import Protocol
from uuid import uuid4

from werkzeug.security import check_password_hash, generate_password_hash

from app.domain.errors import (
    AccountConflictError,
    AuthenticationError,
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
    User,
    distance_meters,
)
from app.domain.ports import UnitOfWork


class TokenCodec(Protocol):
    def encode(self, session_id: str, expires_at: datetime) -> str: ...

    def decode(self, token: str) -> str: ...

    def encode_user(self, user_id: str, auth_version: int, expires_at: datetime) -> str: ...

    def decode_identity(self, token: str): ...


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
        user = User(
            id=str(uuid4()),
            username=None,
            account_kind="legacy",
            is_active=True,
            auth_version=1,
            created_at=now,
            updated_at=now,
        )
        guest_session = GuestSession(
            id=str(uuid4()),
            user_id=user.id,
            created_at=now,
            expires_at=now + timedelta(hours=self.ttl_hours),
        )
        with self.uow_factory() as uow:
            uow.users.add(user, None)
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


class AuthenticationService:
    _username_pattern = re.compile(r"^[\w.-]{3,32}$", re.UNICODE)

    def __init__(
        self,
        uow_factory: UnitOfWorkFactory,
        token_codec: TokenCodec,
        ttl_hours: int,
        *,
        test_auth_enabled: bool,
        test_auth_users: tuple[str, ...],
        clock: Clock = utc_now,
    ):
        self.uow_factory = uow_factory
        self.token_codec = token_codec
        self.ttl_hours = ttl_hours
        self.test_auth_enabled = test_auth_enabled
        self.test_auth_users = tuple(self.normalize_username(item) for item in test_auth_users)
        self.clock = clock
        self._attempts: dict[str, list[datetime]] = {}
        self._attempt_lock = Lock()

    @classmethod
    def normalize_username(cls, value: str) -> str:
        normalized = value.strip().casefold()
        if not cls._username_pattern.fullmatch(normalized):
            raise ValidationError("用户名须为 3–32 个字母、数字、中文、点、横线或下划线")
        return normalized

    @staticmethod
    def validate_password(value: str) -> str:
        if len(value) < 8 or len(value) > 72:
            raise ValidationError("密码长度须为 8–72 个字符")
        return value

    def register(self, username: str, password: str) -> tuple[User, str, datetime]:
        normalized = self.normalize_username(username)
        password = self.validate_password(password)
        now = self.clock()
        user = User(
            id=str(uuid4()),
            username=normalized,
            account_kind="registered",
            is_active=True,
            auth_version=1,
            created_at=now,
            updated_at=now,
        )
        with self.uow_factory() as uow:
            if uow.users.get_by_username(normalized) is not None:
                raise AccountConflictError()
            uow.users.add(user, generate_password_hash(password, method="scrypt"))
            uow.commit()
        return self._authorization(user)

    def login(self, username: str, password: str, correlation: str = ""):
        normalized = self.normalize_username(username)
        self._check_rate_limit(correlation or normalized)
        with self.uow_factory() as uow:
            user = uow.users.get_by_username(normalized)
            password_hash = uow.users.password_hash(user.id) if user else None
        if (
            user is None
            or not user.is_active
            or not password_hash
            or not check_password_hash(password_hash, password)
        ):
            self._record_failure(correlation or normalized)
            raise AuthenticationError()
        self._clear_failures(correlation or normalized)
        return self._authorization(user)

    def test_login(self, alias: str):
        if not self.test_auth_enabled:
            raise LookupError("test auth disabled")
        normalized = self.normalize_username(alias)
        if normalized not in self.test_auth_users:
            raise AuthenticationError()
        with self.uow_factory() as uow:
            user = uow.users.get_by_username(normalized)
            if user is None:
                now = self.clock()
                user = User(
                    id=str(uuid4()),
                    username=normalized,
                    account_kind="test",
                    is_active=True,
                    auth_version=1,
                    created_at=now,
                    updated_at=now,
                )
                uow.users.add(user, None)
                uow.commit()
            elif user.account_kind != "test":
                raise AuthenticationError()
        return self._authorization(user)

    def upgrade_legacy(self, user_id: str, username: str, password: str):
        normalized = self.normalize_username(username)
        password = self.validate_password(password)
        with self.uow_factory() as uow:
            user = uow.users.get(user_id)
            if user is None or not user.is_active:
                raise UnauthorizedError()
            if user.account_kind != "legacy":
                raise ValidationError("当前账号不需要升级")
            existing = uow.users.get_by_username(normalized)
            if existing is not None and existing.id != user_id:
                raise AccountConflictError()
            user = uow.users.set_credentials(
                user_id, normalized, generate_password_hash(password, method="scrypt")
            )
            uow.commit()
        return self._authorization(user)

    def authenticate(self, token: str) -> User:
        identity = self.token_codec.decode_identity(token)
        with self.uow_factory() as uow:
            if identity.kind == "guest":
                guest = uow.guest_sessions.get(identity.subject)
                if guest is None or _aware(guest.expires_at) <= self.clock():
                    raise UnauthorizedError("游客会话已失效，请重新登录")
                user = uow.users.get(guest.user_id)
            else:
                user = uow.users.get(identity.subject)
        if (
            user is None
            or not user.is_active
            or (identity.kind == "user" and user.auth_version != identity.auth_version)
        ):
            raise UnauthorizedError("登录已失效，请重新登录")
        return user

    def _authorization(self, user: User) -> tuple[User, str, datetime]:
        expires_at = self.clock() + timedelta(hours=self.ttl_hours)
        token = self.token_codec.encode_user(user.id, user.auth_version, expires_at)
        return user, token, expires_at

    def _check_rate_limit(self, key: str) -> None:
        cutoff = self.clock() - timedelta(minutes=5)
        with self._attempt_lock:
            attempts = [item for item in self._attempts.get(key, []) if item > cutoff]
            self._attempts[key] = attempts
            if len(attempts) >= 10:
                raise AuthenticationError("登录尝试过多，请稍后再试")

    def _record_failure(self, key: str) -> None:
        with self._attempt_lock:
            self._attempts.setdefault(key, []).append(self.clock())

    def _clear_failures(self, key: str) -> None:
        with self._attempt_lock:
            self._attempts.pop(key, None)


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

    def get_route_for_journey(self, route_id: str) -> Route:
        with self.uow_factory() as uow:
            route = uow.catalog.get_route_for_journey(route_id)
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

    def start_or_resume(self, user_id: str, route_id: str) -> Journey:
        with self.uow_factory() as uow:
            existing = uow.journeys.find_active(route_id, user_id)
            if existing:
                return existing
            completed = uow.journeys.find_latest_completed(route_id, user_id)
            if completed:
                return completed
            route = uow.catalog.get_route_by_id(route_id)
            if route is None:
                raise RouteNotFoundError()
            now = self.clock()
            journey = Journey(
                id=str(uuid4()),
                user_id=user_id,
                guest_session_id=None,
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

    def get(self, user_id: str, journey_id: str) -> Journey:
        with self.uow_factory() as uow:
            journey = uow.journeys.get_for_user(journey_id, user_id)
        if journey is None:
            raise JourneyNotFoundError()
        return journey

    def list_active(self, user_id: str) -> list[Journey]:
        with self.uow_factory() as uow:
            return uow.journeys.list_active_for_user(user_id)

    def list_library(
        self, user_id: str, statuses: tuple[JourneyStatus, ...] | None = None
    ):
        with self.uow_factory() as uow:
            return uow.journeys.list_library_items(user_id, statuses)

    def clear_exploration_progress(self, user_id: str) -> dict[str, int]:
        with self.uow_factory() as uow:
            journey_count, fragment_count = uow.journeys.reset_exploration_progress(
                user_id, self.clock()
            )
            uow.commit()
        return {
            "journey_count": journey_count,
            "fragment_count": fragment_count,
        }

    def arrive(
        self,
        user_id: str,
        journey_id: str,
        *,
        demo: bool,
        latitude: float | None = None,
        longitude: float | None = None,
    ) -> tuple[Journey, float | None]:
        with self.uow_factory() as uow:
            journey, _, stop = self._load_current(uow, user_id, journey_id)
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
        user_id: str,
        journey_id: str,
        stop_id: str,
        selected_option: int,
    ) -> tuple[JourneyAnswer, Stop]:
        with self.uow_factory() as uow:
            journey = uow.journeys.get_for_user(journey_id, user_id)
            if journey is None:
                raise JourneyNotFoundError()
            route = uow.catalog.get_route_for_journey(journey.route_id)
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

    def advance(self, user_id: str, journey_id: str) -> Journey:
        with self.uow_factory() as uow:
            journey, route, stop = self._load_current(uow, user_id, journey_id)
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

    def recap(self, user_id: str, journey_id: str) -> tuple[Journey, Route]:
        with self.uow_factory() as uow:
            journey = uow.journeys.get_for_user(journey_id, user_id)
            if journey is None:
                raise JourneyNotFoundError()
            if journey.status is not JourneyStatus.COMPLETED:
                raise JourneyConflictError("完成路线后才会生成旅程回顾")
            route = uow.catalog.get_route_for_journey(journey.route_id)
            if route is None:
                raise RouteNotFoundError()
            return journey, route

    @staticmethod
    def _load_current(
        uow: UnitOfWork,
        user_id: str,
        journey_id: str,
    ) -> tuple[Journey, Route, Stop]:
        journey = uow.journeys.get_for_user(journey_id, user_id)
        if journey is None:
            raise JourneyNotFoundError()
        if journey.status is JourneyStatus.COMPLETED:
            raise JourneyConflictError("旅程已经完成")
        route = uow.catalog.get_route_for_journey(journey.route_id)
        if route is None:
            raise RouteNotFoundError()
        try:
            stop = next(
                stop for stop in route.stops if stop.position == journey.current_stop_position
            )
        except StopIteration as exc:
            raise JourneyConflictError("旅程站点状态异常") from exc
        return journey, route, stop
