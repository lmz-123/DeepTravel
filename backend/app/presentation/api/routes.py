from __future__ import annotations

from datetime import datetime

from flask import Blueprint, current_app, g, jsonify, request, send_file
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
    fragment_health = _services()["fragment_tours"].health()
    status = (
        "healthy"
        if all(
            value == "up"
            for key, value in fragment_health.items()
            if key != "narration_asset_count"
        )
        else "degraded"
    )
    return jsonify({"data": {"status": status, "database": "up", **fragment_health}})


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
                "routes": [_route_payload(route, include_stops=False) for route in routes],
            }
        }
    )


@api.get("/routes/<route_slug>")
def get_route(route_slug: str):
    route = _services()["catalog"].get_route(route_slug)
    return jsonify({"data": _route_payload(route)})


@api.post("/journeys")
@require_guest
def start_journey():
    body = _json_body()
    route_id = body.get("route_id")
    if not isinstance(route_id, str) or not route_id:
        raise ValidationError("route_id 为必填字符串")
    journey = _services()["journeys"].start_or_resume(g.guest_session.id, route_id)
    _services()["fragment_tours"].initialize_journey(journey.id, route_id)
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
    journey = _services()["journeys"].get(g.guest_session.id, journey_id)
    if _services()["fragment_tours"].public_manifest(journey.route_id) is not None:
        return jsonify(
            {"data": _services()["fragment_tours"].recap(g.guest_session.id, journey_id)}
        )
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


@api.post("/journeys/<journey_id>/active-tour")
@require_guest
def start_active_tour(journey_id: str):
    return jsonify(
        {"data": _services()["fragment_tours"].start_active_tour(g.guest_session.id, journey_id)}
    )


@api.delete("/journeys/<journey_id>/active-tour")
@require_guest
def stop_active_tour(journey_id: str):
    return jsonify(
        {"data": _services()["fragment_tours"].stop_active_tour(g.guest_session.id, journey_id)}
    )


@api.post("/journeys/<journey_id>/fragments/<fragment_id>/triggers")
@require_guest
def trigger_fragment(journey_id: str, fragment_id: str):
    payload = _json_body()
    method = str(payload.get("method") or "location")
    current_app.logger.info(
        "fragment_trigger_requested journey=%s fragment=%s method=%s",
        journey_id,
        fragment_id,
        method,
    )
    result = _services()["fragment_tours"].trigger(
        g.guest_session.id, journey_id, fragment_id, payload
    )
    current_app.logger.info(
        "fragment_trigger_accepted journey=%s fragment=%s method=%s",
        journey_id,
        fragment_id,
        method,
    )
    return jsonify({"data": result})


@api.post("/journeys/<journey_id>/fragments/<fragment_id>/playback")
@require_guest
def fragment_playback(journey_id: str, fragment_id: str):
    return jsonify(
        {
            "data": _services()["fragment_tours"].playback(
                g.guest_session.id, journey_id, fragment_id, _json_body()
            )
        }
    )


@api.post("/journeys/<journey_id>/fragments/<fragment_id>/evidence")
@require_guest
def upload_fragment_evidence(journey_id: str, fragment_id: str):
    file = request.files.get("photo")
    key = request.form.get("idempotency_key", "")
    if file is None or not key:
        raise ValidationError("photo 与 idempotency_key 为必填字段")
    captured_raw = request.form.get("captured_at")
    try:
        captured_at = (
            datetime.fromisoformat(captured_raw.replace("Z", "+00:00")) if captured_raw else None
        )
    except ValueError as exc:
        raise ValidationError("captured_at 必须为 ISO-8601 时间") from exc
    evidence = _services()["fragment_tours"].upload_evidence(
        g.guest_session.id, journey_id, fragment_id, file, key, captured_at
    )
    return jsonify({"data": evidence}), 201


@api.get("/journeys/<journey_id>/evidence/<evidence_id>")
@require_guest
def get_evidence(journey_id: str, evidence_id: str):
    stream, mime_type = _services()["fragment_tours"].open_evidence(
        g.guest_session.id, journey_id, evidence_id
    )
    return send_file(stream, mimetype=mime_type, download_name=f"evidence-{evidence_id}")


@api.delete("/journeys/<journey_id>/evidence/<evidence_id>")
@require_guest
def delete_evidence(journey_id: str, evidence_id: str):
    return jsonify(
        {
            "data": _services()["fragment_tours"].delete_evidence(
                g.guest_session.id, journey_id, evidence_id
            )
        }
    )


@api.get("/journeys/<journey_id>/ledger")
@require_guest
def story_ledger(journey_id: str):
    return jsonify({"data": _services()["fragment_tours"].ledger(g.guest_session.id, journey_id)})


@api.post("/journeys/<journey_id>/reconstruction")
@require_guest
def reconstruct_story(journey_id: str):
    body = _json_body()
    relationships = body.get("relationships")
    if not isinstance(relationships, list) or not all(
        isinstance(item, str) for item in relationships
    ):
        raise ValidationError("relationships 必须是字符串数组")
    return jsonify(
        {
            "data": _services()["fragment_tours"].reconstruct(
                g.guest_session.id, journey_id, relationships
            )
        }
    )


def _route_payload(route, *, include_stops: bool = True) -> dict:
    payload = route_to_dict(route, include_stops=include_stops)
    tour = _services()["fragment_tours"].public_manifest(route.id)
    if tour is not None:
        payload["audio_tour"] = tour
        payload["fragment_count"] = tour["fragment_count"]
        payload["photo_mission_count"] = tour["photo_mission_count"]
        payload["download_size_bytes"] = tour["download_size_bytes"]
    return payload
