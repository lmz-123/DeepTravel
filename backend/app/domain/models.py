from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum
from math import asin, cos, radians, sin, sqrt


class ContentStatus(StrEnum):
    DRAFT = "draft"
    IN_REVIEW = "in_review"
    DEMO_UNVERIFIED = "demo_unverified"
    VERIFIED = "verified"
    PUBLISHED = "published"
    ARCHIVED = "archived"


class JourneyStatus(StrEnum):
    ACTIVE = "active"
    COMPLETED = "completed"


@dataclass(frozen=True, slots=True)
class Challenge:
    id: str
    stop_id: str
    prompt: str
    hint: str
    options: tuple[str, ...]
    correct_option: int
    explanation: str


@dataclass(frozen=True, slots=True)
class Stop:
    id: str
    route_id: str
    position: int
    title: str
    kicker: str
    address: str
    latitude: float
    longitude: float
    arrival_radius_m: int
    story_title: str
    story_body: str
    audio_url: str | None
    image: str
    insight: str
    challenge: Challenge | None


@dataclass(frozen=True, slots=True)
class Route:
    id: str
    city_id: str
    slug: str
    title: str
    subtitle: str
    description: str
    duration_minutes: int
    distance_km: float
    difficulty: str
    theme: str
    hero_image: str
    is_featured: bool
    content_status: ContentStatus
    stops: tuple[Stop, ...] = field(default_factory=tuple)


@dataclass(frozen=True, slots=True)
class City:
    id: str
    slug: str
    name: str
    subtitle: str
    hero_image: str
    latitude: float
    longitude: float


@dataclass(frozen=True, slots=True)
class GuestSession:
    id: str
    user_id: str
    created_at: datetime
    expires_at: datetime


@dataclass(frozen=True, slots=True)
class User:
    id: str
    username: str | None
    account_kind: str
    is_active: bool
    auth_version: int
    created_at: datetime
    updated_at: datetime


@dataclass(slots=True)
class JourneyAnswer:
    stop_id: str
    selected_option: int
    is_correct: bool
    answered_at: datetime


@dataclass(slots=True)
class Journey:
    id: str
    user_id: str
    route_id: str
    status: JourneyStatus
    current_stop_position: int
    arrived_stop_id: str | None
    started_at: datetime
    updated_at: datetime
    completed_at: datetime | None = None
    guest_session_id: str | None = None
    answers: list[JourneyAnswer] = field(default_factory=list)

    def answer_for(self, stop_id: str) -> JourneyAnswer | None:
        return next((answer for answer in self.answers if answer.stop_id == stop_id), None)


def distance_meters(
    latitude_a: float,
    longitude_a: float,
    latitude_b: float,
    longitude_b: float,
) -> float:
    """Haversine distance with sufficient precision for an arrival radius."""
    earth_radius_m = 6_371_000.0
    lat_a, lat_b = radians(latitude_a), radians(latitude_b)
    delta_lat = radians(latitude_b - latitude_a)
    delta_lon = radians(longitude_b - longitude_a)
    value = sin(delta_lat / 2) ** 2 + cos(lat_a) * cos(lat_b) * sin(delta_lon / 2) ** 2
    return 2 * earth_radius_m * asin(sqrt(value))
