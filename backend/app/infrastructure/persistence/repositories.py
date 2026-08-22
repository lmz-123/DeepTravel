from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.domain.models import (
    Challenge,
    City,
    ContentStatus,
    GuestSession,
    Journey,
    JourneyAnswer,
    JourneyStatus,
    Route,
    Stop,
    User,
)
from app.infrastructure.persistence.models import (
    CityModel,
    GuestSessionModel,
    JourneyAnswerModel,
    JourneyModel,
    MediaAssetModel,
    RouteModel,
    StopModel,
    UserModel,
)


def _challenge_to_domain(model: object | None) -> Challenge | None:
    if model is None:
        return None
    return Challenge(
        id=model.id,
        stop_id=model.stop_id,
        prompt=model.prompt,
        hint=model.hint,
        options=tuple(model.options_json),
        correct_option=model.correct_option,
        explanation=model.explanation,
    )


def _stop_to_domain(model: StopModel, resolve_media=lambda value: value) -> Stop:
    return Stop(
        id=model.id,
        route_id=model.route_id,
        position=model.position,
        title=model.title,
        kicker=model.kicker,
        address=model.address,
        latitude=model.latitude,
        longitude=model.longitude,
        arrival_radius_m=model.arrival_radius_m,
        story_title=model.story_title,
        story_body=model.story_body,
        audio_url=resolve_media(model.audio_url),
        image=resolve_media(model.image),
        insight=model.insight,
        challenge=_challenge_to_domain(model.challenge),
    )


def _route_to_domain(
    model: RouteModel, include_stops: bool = True, resolve_media=lambda value: value
) -> Route:
    content_status = ContentStatus(model.content_status)
    return Route(
        id=model.id,
        city_id=model.city_id,
        slug=model.slug,
        title=model.title,
        subtitle=model.subtitle,
        description=model.description,
        duration_minutes=model.duration_minutes,
        distance_km=model.distance_km,
        difficulty=model.difficulty,
        theme=model.theme,
        hero_image=resolve_media(model.hero_image),
        is_featured=model.is_featured,
        content_status=content_status,
        stops=tuple(_stop_to_domain(stop, resolve_media) for stop in model.stops)
        if include_stops
        else (),
    )


def _city_to_domain(model: CityModel, resolve_media=lambda value: value) -> City:
    return City(
        id=model.id,
        slug=model.slug,
        name=model.name,
        subtitle=model.subtitle,
        hero_image=resolve_media(model.hero_image),
        latitude=model.latitude,
        longitude=model.longitude,
    )


def _answer_to_domain(model: JourneyAnswerModel) -> JourneyAnswer:
    return JourneyAnswer(
        stop_id=model.stop_id,
        selected_option=model.selected_option,
        is_correct=model.is_correct,
        answered_at=model.answered_at,
    )


def _journey_to_domain(model: JourneyModel) -> Journey:
    return Journey(
        id=model.id,
        user_id=model.user_id,
        guest_session_id=model.guest_session_id,
        route_id=model.route_id,
        status=JourneyStatus(model.status),
        current_stop_position=model.current_stop_position,
        arrived_stop_id=model.arrived_stop_id,
        started_at=model.started_at,
        updated_at=model.updated_at,
        completed_at=model.completed_at,
        answers=[_answer_to_domain(answer) for answer in model.answers],
    )


def _user_to_domain(model: UserModel) -> User:
    return User(
        id=model.id,
        username=model.username,
        account_kind=model.account_kind,
        is_active=model.is_active,
        auth_version=model.auth_version,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


class SqlAlchemyCatalogRepository:
    def __init__(self, session: Session):
        self.session = session

    def _resolve_media(self, value: str | None) -> str | None:
        if not value or value.startswith(("http://", "https://")):
            return value
        asset = self.session.scalar(
            select(MediaAssetModel).where(
                (MediaAssetModel.storage_path == value) | (MediaAssetModel.key == value)
            )
        )
        if asset and asset.canonical_url:
            return asset.canonical_url
        return value

    def list_cities(self) -> list[City]:
        published_route = (
            select(RouteModel.id)
            .where(
                RouteModel.city_id == CityModel.id,
                RouteModel.content_status == ContentStatus.PUBLISHED.value,
                RouteModel.published_at.is_not(None),
            )
            .exists()
        )
        models = self.session.scalars(
            select(CityModel).where(published_route).order_by(CityModel.name)
        ).all()
        return [_city_to_domain(model, self._resolve_media) for model in models]

    def get_city_by_slug(self, slug: str) -> City | None:
        published_route = (
            select(RouteModel.id)
            .where(
                RouteModel.city_id == CityModel.id,
                RouteModel.content_status == ContentStatus.PUBLISHED.value,
                RouteModel.published_at.is_not(None),
            )
            .exists()
        )
        model = self.session.scalar(
            select(CityModel).where(CityModel.slug == slug, published_route)
        )
        return _city_to_domain(model, self._resolve_media) if model else None

    def list_routes_for_city(self, city_id: str) -> list[Route]:
        statement = (
            select(RouteModel)
            .where(
                RouteModel.city_id == city_id,
                RouteModel.content_status == ContentStatus.PUBLISHED.value,
                RouteModel.published_at.is_not(None),
            )
            .options(selectinload(RouteModel.stops).joinedload(StopModel.challenge))
            .order_by(RouteModel.is_featured.desc(), RouteModel.title)
        )
        return [
            _route_to_domain(model, resolve_media=self._resolve_media)
            for model in self.session.scalars(statement)
        ]

    def get_route_by_slug(self, slug: str) -> Route | None:
        statement = (
            select(RouteModel)
            .where(
                RouteModel.slug == slug,
                RouteModel.content_status == ContentStatus.PUBLISHED.value,
                RouteModel.published_at.is_not(None),
            )
            .options(selectinload(RouteModel.stops).joinedload(StopModel.challenge))
        )
        model = self.session.scalar(statement)
        return _route_to_domain(model, resolve_media=self._resolve_media) if model else None

    def get_route_by_id(self, route_id: str) -> Route | None:
        statement = (
            select(RouteModel)
            .where(
                RouteModel.id == route_id,
                RouteModel.content_status == ContentStatus.PUBLISHED.value,
                RouteModel.published_at.is_not(None),
            )
            .options(selectinload(RouteModel.stops).joinedload(StopModel.challenge))
        )
        model = self.session.scalar(statement)
        return _route_to_domain(model, resolve_media=self._resolve_media) if model else None

    def get_route_for_journey(self, route_id: str) -> Route | None:
        statement = (
            select(RouteModel)
            .where(RouteModel.id == route_id)
            .options(selectinload(RouteModel.stops).joinedload(StopModel.challenge))
        )
        model = self.session.scalar(statement)
        return _route_to_domain(model, resolve_media=self._resolve_media) if model else None


class SqlAlchemyUserRepository:
    def __init__(self, session: Session):
        self.session = session

    def add(self, user: User, password_hash: str | None) -> None:
        self.session.add(
            UserModel(
                id=user.id,
                username=user.username,
                password_hash=password_hash,
                account_kind=user.account_kind,
                is_active=user.is_active,
                auth_version=user.auth_version,
                created_at=user.created_at,
                updated_at=user.updated_at,
            )
        )

    def get(self, user_id: str) -> User | None:
        model = self.session.get(UserModel, user_id)
        return _user_to_domain(model) if model else None

    def get_by_username(self, normalized_username: str) -> User | None:
        model = self.session.scalar(
            select(UserModel).where(UserModel.username == normalized_username)
        )
        return _user_to_domain(model) if model else None

    def password_hash(self, user_id: str) -> str | None:
        return self.session.scalar(select(UserModel.password_hash).where(UserModel.id == user_id))

    def set_credentials(self, user_id: str, username: str, password_hash: str) -> User:
        model = self.session.get(UserModel, user_id)
        if model is None:
            raise LookupError(user_id)
        model.username = username
        model.password_hash = password_hash
        model.account_kind = "registered"
        model.updated_at = datetime.now(UTC)
        return _user_to_domain(model)


class SqlAlchemyGuestSessionRepository:
    def __init__(self, session: Session):
        self.session = session

    def add(self, guest_session: GuestSession) -> None:
        self.session.add(
            GuestSessionModel(
                id=guest_session.id,
                user_id=guest_session.user_id,
                created_at=guest_session.created_at,
                expires_at=guest_session.expires_at,
            )
        )

    def get(self, session_id: str) -> GuestSession | None:
        model = self.session.get(GuestSessionModel, session_id)
        if model is None:
            return None
        return GuestSession(
            id=model.id,
            user_id=model.user_id,
            created_at=model.created_at,
            expires_at=model.expires_at,
        )


class SqlAlchemyJourneyRepository:
    def __init__(self, session: Session):
        self.session = session

    def add(self, journey: Journey) -> None:
        self.session.add(
            JourneyModel(
                id=journey.id,
                user_id=journey.user_id,
                guest_session_id=journey.guest_session_id,
                route_id=journey.route_id,
                status=journey.status.value,
                current_stop_position=journey.current_stop_position,
                arrived_stop_id=journey.arrived_stop_id,
                started_at=journey.started_at,
                updated_at=journey.updated_at,
                completed_at=journey.completed_at,
            )
        )

    def _get_model(self, journey_id: str, user_id: str) -> JourneyModel | None:
        statement = (
            select(JourneyModel)
            .where(
                JourneyModel.id == journey_id,
                JourneyModel.user_id == user_id,
            )
            .options(selectinload(JourneyModel.answers))
        )
        return self.session.scalar(statement)

    def get_for_user(self, journey_id: str, user_id: str) -> Journey | None:
        model = self._get_model(journey_id, user_id)
        return _journey_to_domain(model) if model else None

    def find_active(self, route_id: str, user_id: str) -> Journey | None:
        statement = (
            select(JourneyModel)
            .where(
                JourneyModel.route_id == route_id,
                JourneyModel.user_id == user_id,
                JourneyModel.status == JourneyStatus.ACTIVE.value,
            )
            .options(selectinload(JourneyModel.answers))
            .order_by(JourneyModel.started_at.desc())
        )
        model = self.session.scalar(statement)
        return _journey_to_domain(model) if model else None

    def list_active_for_user(self, user_id: str) -> list[Journey]:
        statement = (
            select(JourneyModel)
            .where(
                JourneyModel.user_id == user_id,
                JourneyModel.status == JourneyStatus.ACTIVE.value,
            )
            .options(selectinload(JourneyModel.answers))
            .order_by(JourneyModel.updated_at.desc())
        )
        return [_journey_to_domain(model) for model in self.session.scalars(statement)]

    def add_answer(self, journey_id: str, answer: JourneyAnswer) -> None:
        self.session.add(
            JourneyAnswerModel(
                journey_id=journey_id,
                stop_id=answer.stop_id,
                selected_option=answer.selected_option,
                is_correct=answer.is_correct,
                answered_at=answer.answered_at,
            )
        )

    def save(self, journey: Journey) -> None:
        model = self.session.get(JourneyModel, journey.id)
        if model is None:
            return
        model.status = journey.status.value
        model.current_stop_position = journey.current_stop_position
        model.arrived_stop_id = journey.arrived_stop_id
        model.updated_at = journey.updated_at
        model.completed_at = journey.completed_at


class SqlAlchemyUnitOfWork:
    def __init__(self, session_factory: object):
        self._session_factory = session_factory
        self.session: Session | None = None

    def __enter__(self) -> SqlAlchemyUnitOfWork:
        self.session = self._session_factory()
        self.catalog = SqlAlchemyCatalogRepository(self.session)
        self.users = SqlAlchemyUserRepository(self.session)
        self.guest_sessions = SqlAlchemyGuestSessionRepository(self.session)
        self.journeys = SqlAlchemyJourneyRepository(self.session)
        return self

    def __exit__(self, exc_type: object, exc: object, traceback: object) -> None:
        if self.session is None:
            return
        if exc_type is not None:
            self.session.rollback()
        self.session.close()

    def commit(self) -> None:
        if self.session is not None:
            self.session.commit()
