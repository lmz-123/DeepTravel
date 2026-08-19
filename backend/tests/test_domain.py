from app.domain.models import distance_meters


def test_distance_is_zero_for_same_point():
    assert distance_meters(31.2, 121.4, 31.2, 121.4) == 0


def test_distance_detects_far_location():
    assert distance_meters(31.2, 121.4, 31.3, 121.5) > 10_000
