from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class CityModel(Base):
    __tablename__ = "cities"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    slug: Mapped[str] = mapped_column(String(80), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(80))
    subtitle: Mapped[str] = mapped_column(String(160))
    hero_image: Mapped[str] = mapped_column(String(255))
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)

    routes: Mapped[list[RouteModel]] = relationship(
        back_populates="city", cascade="all, delete-orphan"
    )


class RouteModel(Base):
    __tablename__ = "routes"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    city_id: Mapped[str] = mapped_column(ForeignKey("cities.id"), index=True)
    slug: Mapped[str] = mapped_column(String(120), unique=True, index=True)
    title: Mapped[str] = mapped_column(String(160))
    subtitle: Mapped[str] = mapped_column(String(255))
    description: Mapped[str] = mapped_column(Text)
    duration_minutes: Mapped[int] = mapped_column(Integer)
    distance_km: Mapped[float] = mapped_column(Float)
    difficulty: Mapped[str] = mapped_column(String(40))
    theme: Mapped[str] = mapped_column(String(80))
    hero_image: Mapped[str] = mapped_column(String(255))
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False)
    content_status: Mapped[str] = mapped_column(String(40), default="demo_unverified")
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    city: Mapped[CityModel] = relationship(back_populates="routes")
    stops: Mapped[list[StopModel]] = relationship(
        back_populates="route",
        cascade="all, delete-orphan",
        order_by="StopModel.position",
    )


class StopModel(Base):
    __tablename__ = "stops"
    __table_args__ = (UniqueConstraint("route_id", "position", name="uq_stop_route_position"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    route_id: Mapped[str] = mapped_column(ForeignKey("routes.id"), index=True)
    position: Mapped[int] = mapped_column(Integer)
    title: Mapped[str] = mapped_column(String(160))
    kicker: Mapped[str] = mapped_column(String(120))
    address: Mapped[str] = mapped_column(String(255))
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)
    arrival_radius_m: Mapped[int] = mapped_column(Integer, default=80)
    story_title: Mapped[str] = mapped_column(String(200))
    story_body: Mapped[str] = mapped_column(Text)
    audio_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    image: Mapped[str] = mapped_column(String(255))
    insight: Mapped[str] = mapped_column(Text)

    route: Mapped[RouteModel] = relationship(back_populates="stops")
    challenge: Mapped[ChallengeModel] = relationship(
        back_populates="stop", cascade="all, delete-orphan", uselist=False
    )


class ChallengeModel(Base):
    __tablename__ = "challenges"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    stop_id: Mapped[str] = mapped_column(ForeignKey("stops.id"), unique=True, index=True)
    prompt: Mapped[str] = mapped_column(Text)
    hint: Mapped[str] = mapped_column(Text)
    options_json: Mapped[list[str]] = mapped_column(JSON)
    correct_option: Mapped[int] = mapped_column(Integer)
    explanation: Mapped[str] = mapped_column(Text)

    stop: Mapped[StopModel] = relationship(back_populates="challenge")


class GuestSessionModel(Base):
    __tablename__ = "guest_sessions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)

    journeys: Mapped[list[JourneyModel]] = relationship(back_populates="guest_session")


class JourneyModel(Base):
    __tablename__ = "journeys"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    guest_session_id: Mapped[str] = mapped_column(ForeignKey("guest_sessions.id"), index=True)
    route_id: Mapped[str] = mapped_column(ForeignKey("routes.id"), index=True)
    status: Mapped[str] = mapped_column(String(20), index=True)
    current_stop_position: Mapped[int] = mapped_column(Integer, default=1)
    arrived_stop_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    guest_session: Mapped[GuestSessionModel] = relationship(back_populates="journeys")
    answers: Mapped[list[JourneyAnswerModel]] = relationship(
        back_populates="journey", cascade="all, delete-orphan"
    )


class JourneyAnswerModel(Base):
    __tablename__ = "journey_answers"
    __table_args__ = (UniqueConstraint("journey_id", "stop_id", name="uq_answer_journey_stop"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    journey_id: Mapped[str] = mapped_column(ForeignKey("journeys.id"), index=True)
    stop_id: Mapped[str] = mapped_column(ForeignKey("stops.id"), index=True)
    selected_option: Mapped[int] = mapped_column(Integer)
    is_correct: Mapped[bool] = mapped_column(Boolean)
    answered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    journey: Mapped[JourneyModel] = relationship(back_populates="answers")
