from __future__ import annotations

from app.domain.models import City, Journey, JourneyStatus, Route, Stop


def city_to_dict(city: City) -> dict:
    return {
        "id": city.id,
        "slug": city.slug,
        "name": city.name,
        "subtitle": city.subtitle,
        "hero_image": city.hero_image,
        "latitude": city.latitude,
        "longitude": city.longitude,
    }


def route_to_dict(route: Route, *, include_stops: bool = True) -> dict:
    data = {
        "id": route.id,
        "city_id": route.city_id,
        "slug": route.slug,
        "title": route.title,
        "subtitle": route.subtitle,
        "description": route.description,
        "duration_minutes": route.duration_minutes,
        "distance_km": route.distance_km,
        "difficulty": route.difficulty,
        "theme": route.theme,
        "hero_image": route.hero_image,
        "is_featured": route.is_featured,
        "content_status": route.content_status.value,
        "stop_count": len(route.stops),
    }
    if include_stops:
        data["stops"] = [stop_to_dict(stop) for stop in route.stops]
    return data


def stop_to_dict(stop: Stop) -> dict:
    return {
        "id": stop.id,
        "route_id": stop.route_id,
        "position": stop.position,
        "title": stop.title,
        "kicker": stop.kicker,
        "address": stop.address,
        "latitude": stop.latitude,
        "longitude": stop.longitude,
        "arrival_radius_m": stop.arrival_radius_m,
        "story_title": stop.story_title,
        "story_body": stop.story_body,
        "audio_url": stop.audio_url,
        "image": stop.image,
        "insight": stop.insight,
        "challenge": {
            "id": stop.challenge.id,
            "prompt": stop.challenge.prompt,
            "hint": stop.challenge.hint,
            "options": list(stop.challenge.options),
        },
    }


def journey_to_dict(journey: Journey, stop_count: int | None = None) -> dict:
    answered_stop_ids = [answer.stop_id for answer in journey.answers]
    completed_stops = len(answered_stop_ids)
    if journey.status is JourneyStatus.COMPLETED and stop_count is not None:
        progress = 1.0
    elif stop_count:
        progress = completed_stops / stop_count
    else:
        progress = 0.0
    return {
        "id": journey.id,
        "route_id": journey.route_id,
        "status": journey.status.value,
        "current_stop_position": journey.current_stop_position,
        "arrived_stop_id": journey.arrived_stop_id,
        "answered_stop_ids": answered_stop_ids,
        "completed_stops": completed_stops,
        "progress": progress,
        "started_at": journey.started_at.isoformat(),
        "updated_at": journey.updated_at.isoformat(),
        "completed_at": journey.completed_at.isoformat() if journey.completed_at else None,
    }
