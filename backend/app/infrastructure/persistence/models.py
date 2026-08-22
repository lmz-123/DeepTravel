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


class MediaAssetModel(Base):
    __tablename__ = "media_assets"

    key: Mapped[str] = mapped_column(String(120), primary_key=True)
    storage_path: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    mime_type: Mapped[str] = mapped_column(String(100))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


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
    managed_package_id: Mapped[str | None] = mapped_column(String(120), nullable=True, index=True)
    managed_package_version: Mapped[str | None] = mapped_column(String(80), nullable=True)

    city: Mapped[CityModel] = relationship(back_populates="routes")
    stops: Mapped[list[StopModel]] = relationship(
        back_populates="route",
        cascade="all, delete-orphan",
        order_by="StopModel.position",
    )
    story_arc: Mapped[StoryArcModel | None] = relationship(
        back_populates="route", cascade="all, delete-orphan", uselist=False
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
    fragments: Mapped[list[JourneyFragmentModel]] = relationship(
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


class HistoricalSourceModel(Base):
    __tablename__ = "historical_sources"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    title: Mapped[str] = mapped_column(String(255))
    publisher: Mapped[str] = mapped_column(String(160))
    url: Mapped[str] = mapped_column(String(800))
    source_type: Mapped[str] = mapped_column(String(40), default="government")
    accessed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    review_state: Mapped[str] = mapped_column(String(40), default="in_review")
    summary: Mapped[str] = mapped_column(Text)


class HistoricalClaimModel(Base):
    __tablename__ = "historical_claims"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    canonical_text: Mapped[str] = mapped_column(Text)
    claim_kind: Mapped[str] = mapped_column(String(40))
    certainty: Mapped[str] = mapped_column(String(40), default="documented")
    review_state: Mapped[str] = mapped_column(String(40), default="in_review")
    boundary_note: Mapped[str] = mapped_column(Text, default="")
    supersedes_claim_id: Mapped[str | None] = mapped_column(
        ForeignKey("historical_claims.id"), nullable=True
    )
    reviewed_by: Mapped[str | None] = mapped_column(String(120), nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class ClaimSourceModel(Base):
    __tablename__ = "claim_sources"
    __table_args__ = (UniqueConstraint("claim_id", "source_id", name="uq_claim_source"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    claim_id: Mapped[str] = mapped_column(ForeignKey("historical_claims.id"), index=True)
    source_id: Mapped[str] = mapped_column(ForeignKey("historical_sources.id"), index=True)
    support_note: Mapped[str] = mapped_column(Text)


class StoryArcModel(Base):
    __tablename__ = "story_arcs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    route_id: Mapped[str] = mapped_column(ForeignKey("routes.id"), unique=True, index=True)
    title: Mapped[str] = mapped_column(String(255))
    central_question: Mapped[str] = mapped_column(Text)
    complete_story: Mapped[str] = mapped_column(Text)
    causal_model_json: Mapped[list[dict | str]] = mapped_column(JSON)
    pronunciation_notes_json: Mapped[list[str]] = mapped_column(JSON, default=list)
    script_version: Mapped[str] = mapped_column(String(40))
    review_state: Mapped[str] = mapped_column(String(40), default="in_review")
    field_audit_state: Mapped[str] = mapped_column(String(40), default="required")
    reviewed_by: Mapped[str | None] = mapped_column(String(120), nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    source_version: Mapped[str | None] = mapped_column(String(80), nullable=True)
    publication_decision: Mapped[str | None] = mapped_column(String(40), nullable=True)

    route: Mapped[RouteModel] = relationship(back_populates="story_arc")
    fragments: Mapped[list[StoryFragmentModel]] = relationship(
        back_populates="arc", cascade="all, delete-orphan", order_by="StoryFragmentModel.position"
    )


class StoryFragmentModel(Base):
    __tablename__ = "story_fragments"
    __table_args__ = (UniqueConstraint("arc_id", "position", name="uq_fragment_arc_position"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    arc_id: Mapped[str] = mapped_column(ForeignKey("story_arcs.id"), index=True)
    stop_id: Mapped[str | None] = mapped_column(ForeignKey("stops.id"), nullable=True)
    position: Mapped[int] = mapped_column(Integer)
    title: Mapped[str] = mapped_column(String(255))
    safe_preview: Mapped[str] = mapped_column(Text)
    narration_script: Mapped[str] = mapped_column(Text)
    transcript: Mapped[str] = mapped_column(Text)
    audio_path: Mapped[str] = mapped_column(String(500))
    audio_mime_type: Mapped[str] = mapped_column(String(80), default="audio/mpeg")
    audio_size_bytes: Mapped[int] = mapped_column(Integer, default=0)
    script_version: Mapped[str] = mapped_column(String(40))
    interaction_type: Mapped[str] = mapped_column(String(40))
    completion_threshold: Mapped[float] = mapped_column(Float, default=0.9)
    key_claim: Mapped[str] = mapped_column(Text)
    answers_question: Mapped[str] = mapped_column(Text)
    raises_question: Mapped[str] = mapped_column(Text)
    authenticity_label: Mapped[str] = mapped_column(String(80), default="interpretive")
    review_state: Mapped[str] = mapped_column(String(40), default="in_review")

    arc: Mapped[StoryArcModel] = relationship(back_populates="fragments")
    trigger_region: Mapped[TriggerRegionModel] = relationship(
        back_populates="fragment", cascade="all, delete-orphan", uselist=False
    )
    photo_mission: Mapped[PhotoMissionModel | None] = relationship(
        back_populates="fragment", cascade="all, delete-orphan", uselist=False
    )


class FragmentClaimModel(Base):
    __tablename__ = "fragment_claims"
    __table_args__ = (UniqueConstraint("fragment_id", "claim_id", name="uq_fragment_claim"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    fragment_id: Mapped[str] = mapped_column(ForeignKey("story_fragments.id"), index=True)
    claim_id: Mapped[str] = mapped_column(ForeignKey("historical_claims.id"), index=True)


class FragmentDependencyModel(Base):
    __tablename__ = "fragment_dependencies"
    __table_args__ = (
        UniqueConstraint("fragment_id", "required_fragment_id", name="uq_fragment_dependency"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    fragment_id: Mapped[str] = mapped_column(ForeignKey("story_fragments.id"), index=True)
    required_fragment_id: Mapped[str] = mapped_column(ForeignKey("story_fragments.id"), index=True)


class TriggerRegionModel(Base):
    __tablename__ = "trigger_regions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    fragment_id: Mapped[str] = mapped_column(ForeignKey("story_fragments.id"), unique=True)
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)
    entry_radius_m: Mapped[int] = mapped_column(Integer, default=60)
    exit_radius_m: Mapped[int] = mapped_column(Integer, default=90)
    max_accuracy_m: Mapped[int] = mapped_column(Integer, default=50)
    qualifying_samples: Mapped[int] = mapped_column(Integer, default=2)
    sample_window_seconds: Mapped[int] = mapped_column(Integer, default=15)
    cooldown_seconds: Mapped[int] = mapped_column(Integer, default=120)
    audit_state: Mapped[str] = mapped_column(String(40), default="in_review")
    coordinate_system: Mapped[str] = mapped_column(String(20), default="WGS84")
    source_coordinate_system: Mapped[str | None] = mapped_column(String(20), nullable=True)
    coordinate_source: Mapped[str | None] = mapped_column(Text, nullable=True)
    field_notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    fragment: Mapped[StoryFragmentModel] = relationship(back_populates="trigger_region")


class PhotoMissionModel(Base):
    __tablename__ = "photo_missions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    fragment_id: Mapped[str] = mapped_column(ForeignKey("story_fragments.id"), unique=True)
    prompt: Mapped[str] = mapped_column(Text)
    field_subject: Mapped[str] = mapped_column(Text)
    safety_copy: Mapped[str] = mapped_column(Text)
    accessibility_alternative: Mapped[str] = mapped_column(Text)
    authenticity_label: Mapped[str] = mapped_column(String(80), default="interpretive")
    required: Mapped[bool] = mapped_column(Boolean, default=True)
    audit_state: Mapped[str] = mapped_column(String(40), default="in_review")

    fragment: Mapped[StoryFragmentModel] = relationship(back_populates="photo_mission")


class JourneyFragmentModel(Base):
    __tablename__ = "journey_fragments"
    __table_args__ = (UniqueConstraint("journey_id", "fragment_id", name="uq_journey_fragment"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    journey_id: Mapped[str] = mapped_column(ForeignKey("journeys.id"), index=True)
    fragment_id: Mapped[str] = mapped_column(ForeignKey("story_fragments.id"), index=True)
    state: Mapped[str] = mapped_column(String(40), default="undiscovered")
    trigger_method: Mapped[str | None] = mapped_column(String(40), nullable=True)
    triggered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    playback_started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    playback_completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    playback_progress: Mapped[float] = mapped_column(Float, default=0.0)
    evidence_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    collected_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    reconstructed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    journey: Mapped[JourneyModel] = relationship(back_populates="fragments")


class ActiveTourModel(Base):
    __tablename__ = "active_tours"

    journey_id: Mapped[str] = mapped_column(ForeignKey("journeys.id"), primary_key=True)
    status: Mapped[str] = mapped_column(String(40), default="monitoring")
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class EvidenceModel(Base):
    __tablename__ = "evidence"
    __table_args__ = (UniqueConstraint("journey_id", "idempotency_key", name="uq_evidence_retry"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    journey_id: Mapped[str] = mapped_column(ForeignKey("journeys.id"), index=True)
    mission_id: Mapped[str] = mapped_column(ForeignKey("photo_missions.id"), index=True)
    object_key: Mapped[str] = mapped_column(String(255), unique=True)
    mime_type: Mapped[str] = mapped_column(String(80))
    size_bytes: Mapped[int] = mapped_column(Integer)
    sha256: Mapped[str] = mapped_column(String(64))
    width: Mapped[int] = mapped_column(Integer)
    height: Mapped[int] = mapped_column(Integer)
    captured_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    uploaded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    idempotency_key: Mapped[str] = mapped_column(String(80))


class ReconstructionModel(Base):
    __tablename__ = "reconstructions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    journey_id: Mapped[str] = mapped_column(ForeignKey("journeys.id"), unique=True, index=True)
    submitted_model_json: Mapped[list[str]] = mapped_column(JSON)
    is_correct: Mapped[bool] = mapped_column(Boolean)
    attempt_count: Mapped[int] = mapped_column(Integer, default=1)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class IdempotencyRecordModel(Base):
    __tablename__ = "idempotency_records"
    __table_args__ = (UniqueConstraint("scope", "idempotency_key", name="uq_idempotency_scope"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    scope: Mapped[str] = mapped_column(String(160), index=True)
    idempotency_key: Mapped[str] = mapped_column(String(80))
    response_json: Mapped[dict] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
