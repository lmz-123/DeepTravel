from __future__ import annotations

from dataclasses import dataclass

from app.domain.models import distance_meters


@dataclass(frozen=True, slots=True)
class TriggerDecision:
    accepted: bool
    code: str | None
    distance_m: float | None


def evaluate_trigger(
    *,
    method: str,
    allow_demo: bool,
    latitude: float | None,
    longitude: float | None,
    accuracy_m: float | None,
    region_latitude: float,
    region_longitude: float,
    entry_radius_m: int,
    max_accuracy_m: int,
) -> TriggerDecision:
    if method == "demo":
        return TriggerDecision(allow_demo, None if allow_demo else "demo_trigger_disabled", None)
    if method != "location" or latitude is None or longitude is None or accuracy_m is None:
        return TriggerDecision(False, "location_evidence_required", None)
    if accuracy_m < 0 or accuracy_m > max_accuracy_m:
        return TriggerDecision(False, "location_accuracy_insufficient", None)
    distance = distance_meters(latitude, longitude, region_latitude, region_longitude)
    if distance > entry_radius_m:
        return TriggerDecision(False, "trigger_too_far", distance)
    return TriggerDecision(True, None, distance)


def playback_state(interaction_type: str, progress: float, threshold: float) -> str:
    if progress < threshold:
        return "playing"
    return "mission_pending" if interaction_type == "photo" else "collected"


def reconstruction_feedback(expected: list[str], submitted: list[str]) -> tuple[bool, list[dict]]:
    feedback = []
    for index, expected_value in enumerate(expected):
        actual = submitted[index] if index < len(submitted) else None
        if actual != expected_value:
            feedback.append({"position": index + 1, "submitted": actual})
    return not feedback and len(submitted) == len(expected), feedback
