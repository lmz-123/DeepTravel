from __future__ import annotations

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
)
from app.infrastructure.persistence.models import (
    CityModel,
    GuestSessionModel,
    JourneyAnswerModel,
    JourneyModel,
    RouteModel,
    StopModel,
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


def _stop_to_domain(model: StopModel) -> Stop:
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
        audio_url=model.audio_url,
        image=model.image,
        insight=model.insight,
        challenge=_challenge_to_domain(model.challenge),
    )


def _route_to_domain(model: RouteModel, include_stops: bool = True) -> Route:
    content_status = (
        ContentStatus.VERIFIED
        if model.content_status == "published"
        else ContentStatus(model.content_status)
    )
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
        hero_image=model.hero_image,
        is_featured=model.is_featured,
        content_status=content_status,
        stops=tuple(_stop_to_domain(stop) for stop in model.stops) if include_stops else (),
    )


def _city_to_domain(model: CityModel) -> City:
    return City(
        id=model.id,
        slug=model.slug,
        name=model.name,
        subtitle=model.subtitle,
        hero_image=model.hero_image,
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


class SqlAlchemyCatalogRepository:
    def __init__(self, session: Session):
        self.session = session

    def list_cities(self) -> list[City]:
        models = self.session.scalars(select(CityModel).order_by(CityModel.name)).all()
        return [_city_to_domain(model) for model in models]

    def get_city_by_slug(self, slug: str) -> City | None:
        model = self.session.scalar(select(CityModel).where(CityModel.slug == slug))
        return _city_to_domain(model) if model else None

    def list_routes_for_city(self, city_id: str) -> list[Route]:
        statement = (
            select(RouteModel)
            .where(RouteModel.city_id == city_id, RouteModel.published_at.is_not(None))
            .options(selectinload(RouteModel.stops).joinedload(StopModel.challenge))
            .order_by(RouteModel.is_featured.desc(), RouteModel.title)
        )
        return [_route_to_domain(model) for model in self.session.scalars(statement)]

    def get_route_by_slug(self, slug: str) -> Route | None:
        statement = (
            select(RouteModel)
            .where(RouteModel.slug == slug, RouteModel.published_at.is_not(None))
            .options(selectinload(RouteModel.stops).joinedload(StopModel.challenge))
        )
        model = self.session.scalar(statement)
        return _route_to_domain(model) if model else None

    def get_route_by_id(self, route_id: str) -> Route | None:
        statement = (
            select(RouteModel)
            .where(RouteModel.id == route_id, RouteModel.published_at.is_not(None))
            .options(selectinload(RouteModel.stops).joinedload(StopModel.challenge))
        )
        model = self.session.scalar(statement)
        return _route_to_domain(model) if model else None


class SqlAlchemyGuestSessionRepository:
    def __init__(self, session: Session):
        self.session = session

    def add(self, guest_session: GuestSession) -> None:
        self.session.add(
            GuestSessionModel(
                id=guest_session.id,
                created_at=guest_session.created_at,
                expires_at=guest_session.expires_at,
            )
        )

    def get(self, session_id: str) -> GuestSession | None:
        model = self.session.get(GuestSessionModel, session_id)
        if model is None:
            return None
        return GuestSession(id=model.id, created_at=model.created_at, expires_at=model.expires_at)


class SqlAlchemyJourneyRepository:
    def __init__(self, session: Session):
        self.session = session

    def add(self, journey: Journey) -> None:
        self.session.add(
            JourneyModel(
                id=journey.id,
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

    def _get_model(self, journey_id: str, guest_session_id: str) -> JourneyModel | None:
        statement = (
            select(JourneyModel)
            .where(
                JourneyModel.id == journey_id,
                JourneyModel.guest_session_id == guest_session_id,
            )
            .options(selectinload(JourneyModel.answers))
        )
        return self.session.scalar(statement)

    def get_for_guest(self, journey_id: str, guest_session_id: str) -> Journey | None:
        model = self._get_model(journey_id, guest_session_id)
        return _journey_to_domain(model) if model else None

    def find_active(self, route_id: str, guest_session_id: str) -> Journey | None:
        statement = (
            select(JourneyModel)
            .where(
                JourneyModel.route_id == route_id,
                JourneyModel.guest_session_id == guest_session_id,
                JourneyModel.status == JourneyStatus.ACTIVE.value,
            )
            .options(selectinload(JourneyModel.answers))
            .order_by(JourneyModel.started_at.desc())
        )
        model = self.session.scalar(statement)
        return _journey_to_domain(model) if model else None

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
