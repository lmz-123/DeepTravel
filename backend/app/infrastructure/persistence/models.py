from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    Double,
    Float,
    ForeignKey,
    Index,
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
    storage_provider: Mapped[str] = mapped_column(String(20), default="local")
    object_key: Mapped[str | None] = mapped_column(String(500), nullable=True, index=True)
    canonical_url: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    visibility: Mapped[str] = mapped_column(String(20), default="public")
    size_bytes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    checksum_sha256: Mapped[str | None] = mapped_column(String(64), nullable=True)
    metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class UserModel(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    username: Mapped[str | None] = mapped_column(String(80), nullable=True, unique=True, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    account_kind: Mapped[str] = mapped_column(String(20), default="registered", index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    auth_version: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    guest_sessions: Mapped[list[GuestSessionModel]] = relationship(back_populates="user")
    journeys: Mapped[list[JourneyModel]] = relationship(back_populates="user")


class CityModel(Base):
    __tablename__ = "cities"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    slug: Mapped[str] = mapped_column(String(80), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(80))
    subtitle: Mapped[str] = mapped_column(String(160))
    hero_image: Mapped[str] = mapped_column(String(255))
    latitude: Mapped[float] = mapped_column(Double)
    longitude: Mapped[float] = mapped_column(Double)

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
    latitude: Mapped[float] = mapped_column(Double)
    longitude: Mapped[float] = mapped_column(Double)
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
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)

    user: Mapped[UserModel] = relationship(back_populates="guest_sessions")
    journeys: Mapped[list[JourneyModel]] = relationship(back_populates="guest_session")


class JourneyModel(Base):
    __tablename__ = "journeys"
    __table_args__ = (
        Index("ix_journeys_user_status_updated", "user_id", "status", "updated_at"),
        Index(
            "ix_journeys_user_route_status_completed",
            "user_id",
            "route_id",
            "status",
            "completed_at",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    guest_session_id: Mapped[str | None] = mapped_column(
        ForeignKey("guest_sessions.id"), index=True, nullable=True
    )
    route_id: Mapped[str] = mapped_column(ForeignKey("routes.id"), index=True)
    status: Mapped[str] = mapped_column(String(20), index=True)
    current_stop_position: Mapped[int] = mapped_column(Integer, default=1)
    arrived_stop_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped[UserModel] = relationship(back_populates="journeys")
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
    story_narration_tracks: Mapped[list[StoryNarrationTrackModel]] = relationship(
        back_populates="arc", cascade="all, delete-orphan"
    )
    home_story_publication: Mapped[HomeStoryPublicationModel | None] = relationship(
        back_populates="arc", cascade="all, delete-orphan", uselist=False
    )


class StoryNarrationTrackModel(Base):
    __tablename__ = "story_narration_tracks"
    __table_args__ = (
        UniqueConstraint(
            "arc_id",
            "profile_id",
            "transcript_hash",
            "script_version",
            name="uq_story_voice_script",
        ),
        Index("ix_story_narration_tracks_hash_status", "transcript_hash", "status"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    arc_id: Mapped[str] = mapped_column(ForeignKey("story_arcs.id"), index=True)
    profile_id: Mapped[str] = mapped_column(
        ForeignKey("narration_voice_profiles.id"), index=True
    )
    transcript_hash: Mapped[str] = mapped_column(String(64), index=True)
    script_version: Mapped[str] = mapped_column(String(40))
    media_path: Mapped[str] = mapped_column(String(500))
    mime_type: Mapped[str] = mapped_column(String(80), default="audio/mpeg")
    size_bytes: Mapped[int] = mapped_column(Integer, default=0)
    duration_ms: Mapped[int] = mapped_column(Integer, default=0)
    checksum_sha256: Mapped[str | None] = mapped_column(String(64), nullable=True)
    generation_metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)
    status: Mapped[str] = mapped_column(String(20), default="draft", index=True)
    reviewed_by: Mapped[str | None] = mapped_column(String(120), nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    arc: Mapped[StoryArcModel] = relationship(back_populates="story_narration_tracks")


class HomeStoryPublicationModel(Base):
    __tablename__ = "home_story_publications"
    __table_args__ = (
        Index(
            "ix_home_story_publications_status_weight",
            "status",
            "selection_weight",
            "published_at",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    arc_id: Mapped[str] = mapped_column(ForeignKey("story_arcs.id"), unique=True, index=True)
    selected_track_id: Mapped[str | None] = mapped_column(
        ForeignKey("story_narration_tracks.id"), nullable=True, index=True
    )
    title: Mapped[str] = mapped_column(String(255))
    introduction: Mapped[str] = mapped_column(Text)
    cover_image: Mapped[str] = mapped_column(String(500))
    selection_weight: Mapped[int] = mapped_column(Integer, default=1)
    status: Mapped[str] = mapped_column(String(20), default="draft", index=True)
    reviewed_by: Mapped[str | None] = mapped_column(String(120), nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    arc: Mapped[StoryArcModel] = relationship(back_populates="home_story_publication")
    selected_track: Mapped[StoryNarrationTrackModel | None] = relationship(
        foreign_keys=[selected_track_id]
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


class NarrationVoiceProfileModel(Base):
    __tablename__ = "narration_voice_profiles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    slug: Mapped[str] = mapped_column(String(80), unique=True, index=True)
    display_name: Mapped[str] = mapped_column(String(120))
    description: Mapped[str] = mapped_column(String(500), default="")
    provider: Mapped[str] = mapped_column(String(40))
    model: Mapped[str] = mapped_column(String(80))
    voice_id: Mapped[str] = mapped_column(String(120))
    emotion: Mapped[str] = mapped_column(String(40), default="neutral")
    speed: Mapped[float] = mapped_column(Float, default=1.0)
    pitch: Mapped[int] = mapped_column(Integer, default=0)
    preview_media_path: Mapped[str | None] = mapped_column(String(500), nullable=True)
    display_order: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(20), default="draft", index=True)
    is_default: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class FragmentNarrationTrackModel(Base):
    __tablename__ = "fragment_narration_tracks"
    __table_args__ = (
        UniqueConstraint(
            "fragment_id",
            "profile_id",
            "transcript_hash",
            "script_version",
            name="uq_fragment_voice_script",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    fragment_id: Mapped[str] = mapped_column(ForeignKey("story_fragments.id"), index=True)
    profile_id: Mapped[str] = mapped_column(ForeignKey("narration_voice_profiles.id"), index=True)
    transcript_hash: Mapped[str] = mapped_column(String(64), index=True)
    script_version: Mapped[str] = mapped_column(String(40))
    media_path: Mapped[str] = mapped_column(String(500))
    mime_type: Mapped[str] = mapped_column(String(80), default="audio/mpeg")
    size_bytes: Mapped[int] = mapped_column(Integer, default=0)
    checksum_sha256: Mapped[str | None] = mapped_column(String(64), nullable=True)
    generation_metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)
    approved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


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
    latitude: Mapped[float] = mapped_column(Double)
    longitude: Mapped[float] = mapped_column(Double)
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
    vantage_point: Mapped[str | None] = mapped_column(Text, nullable=True)
    shooting_direction: Mapped[str | None] = mapped_column(Text, nullable=True)
    composition_tip: Mapped[str | None] = mapped_column(Text, nullable=True)
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
    storage_provider: Mapped[str] = mapped_column(String(20), default="local")
    canonical_reference: Mapped[str | None] = mapped_column(String(1000), nullable=True)
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


class CommunityPostModel(Base):
    __tablename__ = "community_posts"
    __table_args__ = (
        UniqueConstraint("author_user_id", "idempotency_key", name="uq_community_post_retry"),
        Index(
            "ix_community_posts_fragment_status_created",
            "fragment_id",
            "status",
            "created_at",
            "id",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    fragment_id: Mapped[str] = mapped_column(ForeignKey("story_fragments.id"), index=True)
    author_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    category: Mapped[str] = mapped_column(String(40), index=True)
    title: Mapped[str | None] = mapped_column(String(120), nullable=True)
    body: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(20), default="visible", index=True)
    report_count: Mapped[int] = mapped_column(Integer, default=0)
    idempotency_key: Mapped[str] = mapped_column(String(80))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class CommunityMediaModel(Base):
    __tablename__ = "community_media"
    __table_args__ = (UniqueConstraint("post_id", "position", name="uq_community_media_position"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    post_id: Mapped[str] = mapped_column(
        ForeignKey("community_posts.id", ondelete="CASCADE"), index=True
    )
    position: Mapped[int] = mapped_column(Integer)
    storage_provider: Mapped[str] = mapped_column(String(20))
    object_key: Mapped[str] = mapped_column(String(500), unique=True)
    canonical_reference: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    mime_type: Mapped[str] = mapped_column(String(80))
    size_bytes: Mapped[int] = mapped_column(Integer)
    sha256: Mapped[str] = mapped_column(String(64))
    width: Mapped[int] = mapped_column(Integer)
    height: Mapped[int] = mapped_column(Integer)
    source_kind: Mapped[str] = mapped_column(String(30), default="upload")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class CommunityPostLikeModel(Base):
    __tablename__ = "community_post_likes"
    __table_args__ = (
        UniqueConstraint("post_id", "user_id", name="uq_community_post_like"),
        Index("ix_community_likes_post_created", "post_id", "created_at", "id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    post_id: Mapped[str] = mapped_column(
        ForeignKey("community_posts.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class CommunityCommentModel(Base):
    __tablename__ = "community_comments"
    __table_args__ = (
        UniqueConstraint("author_user_id", "idempotency_key", name="uq_community_comment_retry"),
        Index("ix_community_comments_post_status_created", "post_id", "status", "created_at", "id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    post_id: Mapped[str] = mapped_column(
        ForeignKey("community_posts.id", ondelete="CASCADE"), index=True
    )
    root_comment_id: Mapped[str | None] = mapped_column(
        ForeignKey("community_comments.id", ondelete="RESTRICT"), nullable=True, index=True
    )
    reply_to_comment_id: Mapped[str | None] = mapped_column(
        ForeignKey("community_comments.id", ondelete="RESTRICT"), nullable=True, index=True
    )
    author_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    body: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(20), default="visible", index=True)
    report_count: Mapped[int] = mapped_column(Integer, default=0)
    idempotency_key: Mapped[str] = mapped_column(String(80))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class CommunityReportModel(Base):
    __tablename__ = "community_reports"
    __table_args__ = (
        UniqueConstraint(
            "reporter_user_id", "target_type", "target_id", name="uq_community_report_target"
        ),
        Index("ix_community_reports_target", "target_type", "target_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    reporter_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    target_type: Mapped[str] = mapped_column(String(20))
    target_id: Mapped[str] = mapped_column(String(36))
    reason: Mapped[str] = mapped_column(String(40))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class NarrationPreviewModel(Base):
    __tablename__ = "narration_previews"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    fragment_id: Mapped[str] = mapped_column(ForeignKey("story_fragments.id"), index=True)
    profile_id: Mapped[str | None] = mapped_column(
        ForeignKey("narration_voice_profiles.id"), nullable=True, index=True
    )
    transcript_hash: Mapped[str] = mapped_column(String(64), index=True)
    provider: Mapped[str] = mapped_column(String(40))
    model: Mapped[str] = mapped_column(String(80))
    voice_id: Mapped[str] = mapped_column(String(120))
    emotion: Mapped[str] = mapped_column(String(40), default="calm")
    speed: Mapped[float] = mapped_column(Float, default=1.0)
    pitch: Mapped[int] = mapped_column(Integer, default=0)
    pronunciation_json: Mapped[list[str]] = mapped_column(JSON, default=list)
    object_key: Mapped[str | None] = mapped_column(String(500), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="pending", index=True)
    error_code: Mapped[str | None] = mapped_column(String(80), nullable=True)
    metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


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
