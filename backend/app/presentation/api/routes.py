from __future__ import annotations

from flask import Blueprint, current_app, g, jsonify, request
from sqlalchemy import text

from app.domain.errors import ValidationError
from app.presentation.api.auth import require_guest
from app.presentation.api.media import send_media_asset
from app.presentation.api.serializers import (
    city_to_dict,
    journey_to_dict,
    route_to_dict,
)

api = Blueprint("api", __name__, url_prefix="/api/v1")


def _json_body() -> dict:
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        raise ValidationError("请求体必须是 JSON 对象")
    return body


def _services() -> dict:
    return current_app.extensions["services"]


@api.get("/health")
def health():
    database = current_app.extensions["database"]
    database.session_factory().execute(text("SELECT 1"))
    return jsonify({"data": {"status": "healthy", "database": "up"}})


@api.get("/assets/<path:asset_path>")
def media_asset(asset_path: str):
    return send_media_asset(asset_path)


@api.post("/sessions/guest")
def create_guest_session():
    guest_session, token = _services()["guest_sessions"].create()
    return (
        jsonify(
            {
                "data": {
                    "session_id": guest_session.id,
                    "token": token,
                    "expires_at": guest_session.expires_at.isoformat(),
                }
            }
        ),
        201,
    )


@api.get("/cities")
def list_cities():
    cities = _services()["catalog"].list_cities()
    return jsonify({"data": [city_to_dict(city) for city in cities]})


@api.get("/cities/<city_slug>/routes")
def list_city_routes(city_slug: str):
    city, routes = _services()["catalog"].list_city_routes(city_slug)
    return jsonify(
        {
            "data": {
                "city": city_to_dict(city),
                "routes": [route_to_dict(route, include_stops=False) for route in routes],
            }
        }
    )


@api.get("/routes/<route_slug>")
def get_route(route_slug: str):
    route = _services()["catalog"].get_route(route_slug)
    return jsonify({"data": route_to_dict(route)})


@api.post("/journeys")
@require_guest
def start_journey():
    body = _json_body()
    route_id = body.get("route_id")
    if not isinstance(route_id, str) or not route_id:
        raise ValidationError("route_id 为必填字符串")
    journey = _services()["journeys"].start_or_resume(g.guest_session.id, route_id)
    route = _services()["catalog"].get_route_by_id(route_id)
    return jsonify({"data": journey_to_dict(journey, len(route.stops))}), 201


@api.get("/journeys/<journey_id>")
@require_guest
def get_journey(journey_id: str):
    journey = _services()["journeys"].get(g.guest_session.id, journey_id)
    route = _services()["catalog"].get_route_by_id(journey.route_id)
    return jsonify({"data": journey_to_dict(journey, len(route.stops))})


@api.post("/journeys/<journey_id>/arrivals")
@require_guest
def arrive(journey_id: str):
    body = _json_body()
    demo = body.get("demo", False)
    if not isinstance(demo, bool):
        raise ValidationError("demo 必须是布尔值")
    latitude = body.get("latitude")
    longitude = body.get("longitude")
    if latitude is not None and (
        not isinstance(latitude, int | float) or isinstance(latitude, bool)
    ):
        raise ValidationError("latitude 必须是数字")
    if longitude is not None and (
        not isinstance(longitude, int | float) or isinstance(longitude, bool)
    ):
        raise ValidationError("longitude 必须是数字")
    journey, distance = _services()["journeys"].arrive(
        g.guest_session.id,
        journey_id,
        demo=demo,
        latitude=float(latitude) if latitude is not None else None,
        longitude=float(longitude) if longitude is not None else None,
    )
    route = _services()["catalog"].get_route_by_id(journey.route_id)
    return jsonify(
        {
            "data": {
                "journey": journey_to_dict(journey, len(route.stops)),
                "distance_m": round(distance, 1) if distance is not None else None,
            }
        }
    )


@api.post("/journeys/<journey_id>/answers")
@require_guest
def answer(journey_id: str):
    body = _json_body()
    stop_id = body.get("stop_id")
    selected_option = body.get("selected_option")
    if not isinstance(stop_id, str) or not stop_id:
        raise ValidationError("stop_id 为必填字符串")
    if not isinstance(selected_option, int) or isinstance(selected_option, bool):
        raise ValidationError("selected_option 必须是整数")
    answer_result, stop = _services()["journeys"].answer(
        g.guest_session.id,
        journey_id,
        stop_id,
        selected_option,
    )
    return jsonify(
        {
            "data": {
                "stop_id": answer_result.stop_id,
                "selected_option": answer_result.selected_option,
                "is_correct": answer_result.is_correct,
                "explanation": stop.challenge.explanation,
                "insight": stop.insight,
            }
        }
    )


@api.post("/journeys/<journey_id>/advance")
@require_guest
def advance(journey_id: str):
    journey = _services()["journeys"].advance(g.guest_session.id, journey_id)
    route = _services()["catalog"].get_route_by_id(journey.route_id)
    return jsonify({"data": journey_to_dict(journey, len(route.stops))})


@api.get("/journeys/<journey_id>/recap")
@require_guest
def recap(journey_id: str):
    journey, route = _services()["journeys"].recap(g.guest_session.id, journey_id)
    answered = {answer.stop_id: answer for answer in journey.answers}
    insights = [
        {
            "stop_id": stop.id,
            "title": stop.title,
            "insight": stop.insight,
            "is_correct": answered[stop.id].is_correct,
        }
        for stop in route.stops
        if stop.id in answered
    ]
    return jsonify(
        {
            "data": {
                "journey": journey_to_dict(journey, len(route.stops)),
                "route": route_to_dict(route, include_stops=False),
                "insights": insights,
            }
        }
    )
