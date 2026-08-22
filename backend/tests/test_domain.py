from app.domain.fragment_rules import playback_state
from app.domain.models import distance_meters


def test_distance_is_zero_for_same_point():
    assert distance_meters(31.2, 121.4, 31.2, 121.4) == 0


def test_distance_detects_far_location():
    assert distance_meters(31.2, 121.4, 31.3, 121.5) > 10_000


def test_photo_playback_collects_at_threshold_without_evidence():
    assert playback_state("photo", 0.89, 0.9) == "playing"
    assert playback_state("photo", 0.9, 0.9) == "collected"
