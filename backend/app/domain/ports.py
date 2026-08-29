from __future__ import annotations

from datetime import datetime
from typing import Protocol

from app.domain.models import (
    City,
    GuestSession,
    Journey,
    JourneyAnswer,
    JourneyLibraryItem,
    JourneyStatus,
    Route,
    User,
)


class CatalogRepository(Protocol):
    def list_cities(self) -> list[City]: ...

    def get_city_by_slug(self, slug: str) -> City | None: ...

    def list_routes_for_city(self, city_id: str) -> list[Route]: ...

    def get_route_by_slug(self, slug: str) -> Route | None: ...

    def get_route_by_id(self, route_id: str) -> Route | None: ...

    def get_route_for_journey(self, route_id: str) -> Route | None: ...


class GuestSessionRepository(Protocol):
    def add(self, guest_session: GuestSession) -> None: ...

    def get(self, session_id: str) -> GuestSession | None: ...


class UserRepository(Protocol):
    def add(self, user: User, password_hash: str | None) -> None: ...

    def get(self, user_id: str) -> User | None: ...

    def get_by_username(self, normalized_username: str) -> User | None: ...

    def password_hash(self, user_id: str) -> str | None: ...

    def set_credentials(self, user_id: str, username: str, password_hash: str) -> User: ...


class JourneyRepository(Protocol):
    def add(self, journey: Journey) -> None: ...

    def get_for_user(self, journey_id: str, user_id: str) -> Journey | None: ...

    def find_active(self, route_id: str, user_id: str) -> Journey | None: ...

    def find_latest_completed(self, route_id: str, user_id: str) -> Journey | None: ...

    def list_active_for_user(self, user_id: str) -> list[Journey]: ...

    def list_for_user(
        self, user_id: str, statuses: tuple[JourneyStatus, ...] | None = None
    ) -> list[Journey]: ...

    def list_library_items(
        self, user_id: str, statuses: tuple[JourneyStatus, ...] | None = None
    ) -> list[JourneyLibraryItem]: ...

    def add_answer(self, journey_id: str, answer: JourneyAnswer) -> None: ...

    def save(self, journey: Journey) -> None: ...

    def reset_exploration_progress(
        self, user_id: str, updated_at: datetime
    ) -> tuple[int, int]: ...


class UnitOfWork(Protocol):
    catalog: CatalogRepository
    users: UserRepository
    guest_sessions: GuestSessionRepository
    journeys: JourneyRepository

    def __enter__(self) -> UnitOfWork: ...

    def __exit__(self, exc_type: object, exc: object, traceback: object) -> None: ...

    def commit(self) -> None: ...
