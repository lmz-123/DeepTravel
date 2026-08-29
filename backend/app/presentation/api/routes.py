from __future__ import annotations

import hashlib
import json
from datetime import datetime

from flask import Blueprint, abort, current_app, g, jsonify, request, send_file
from sqlalchemy import text

from app.domain.errors import ValidationError
from app.domain.models import ContentStatus, JourneyStatus
from app.presentation.api.auth import require_user
from app.presentation.api.media import send_media_asset
from app.presentation.api.serializers import (
    city_to_dict,
    journey_library_item_to_dict,
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


def _page_limit(default: int = 10) -> int:
    raw = request.args.get("limit")
    if raw is None:
        return default
    try:
        return int(raw)
    except ValueError as exc:
        raise ValidationError("limit 必须是整数") from exc


def _authorization_payload(result) -> dict:
    user, token, expires_at = result
    return {
        "user": {
            "id": user.id,
            "username": user.username,
            "account_kind": user.account_kind,
        },
        "token": token,
        "expires_at": expires_at.isoformat(),
    }


@api.get("/health")
def health():
    database = current_app.extensions["database"]
    database.session_factory().execute(text("SELECT 1"))
    fragment_health = _services()["fragment_tours"].health()
    media_readiness = _services()["media_readiness"].audit()
    status = (
        "healthy"
        if all(
            value == "up"
            for key, value in fragment_health.items()
            if key != "narration_asset_count"
        )
        else "degraded"
    )
    if media_readiness["status"] != "ready":
        status = "degraded"
    return jsonify(
        {
            "data": {
                "status": status,
                "database": "up",
                **fragment_health,
                "media_readiness": media_readiness,
            }
        }
    )


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
                    "user_id": guest_session.user_id,
                    "token": token,
                    "expires_at": guest_session.expires_at.isoformat(),
                }
            }
        ),
        201,
    )


@api.post("/auth/register")
def register_user():
    body = _json_body()
    username = body.get("username")
    password = body.get("password")
    if not isinstance(username, str) or not isinstance(password, str):
        raise ValidationError("username 与 password 为必填字符串")
    result = _services()["authentication"].register(username, password)
    current_app.logger.info("auth_register_success user=%s", result[0].id[:8])
    return jsonify({"data": _authorization_payload(result)}), 201


@api.post("/auth/login")
def login_user():
    body = _json_body()
    username = body.get("username")
    password = body.get("password")
    if not isinstance(username, str) or not isinstance(password, str):
        raise ValidationError("username 与 password 为必填字符串")
    result = _services()["authentication"].login(
        username, password, correlation=request.remote_addr or "unknown"
    )
    current_app.logger.info("auth_login_success user=%s", result[0].id[:8])
    return jsonify({"data": _authorization_payload(result)})


@api.post("/auth/test-login")
def test_login_user():
    body = _json_body()
    alias = body.get("alias")
    if not isinstance(alias, str):
        raise ValidationError("alias 为必填字符串")
    try:
        result = _services()["authentication"].test_login(alias)
    except LookupError:
        abort(404)
    current_app.logger.info("auth_test_login_success user=%s", result[0].id[:8])
    return jsonify({"data": _authorization_payload(result)})


@api.get("/auth/me")
@require_user
def current_user():
    user = g.current_user
    return jsonify(
        {
            "data": {
                "id": user.id,
                "username": user.username,
                "account_kind": user.account_kind,
            }
        }
    )


@api.get("/policies/evidence")
@require_user
def evidence_policy():
    return jsonify(
        {
            "data": {
                "upload_enabled": bool(current_app.config["EVIDENCE_UPLOAD_ENABLED"]),
                "retention_days": int(current_app.config["EVIDENCE_RETENTION_DAYS"]),
                "max_bytes": int(current_app.config["EVIDENCE_MAX_BYTES"]),
                "max_edge_pixels": int(current_app.config["EVIDENCE_MAX_EDGE"]),
                "allowed_mime_types": ["image/jpeg", "image/png", "image/webp"],
                "private_access": True,
                "exif_removed": True,
                "normalized_on_upload": True,
            }
        }
    )


@api.get("/policies/footprints")
@require_user
def footprint_policy():
    return jsonify(
        {
            "data": {
                "photo_upload_enabled": True,
                "max_bytes": int(current_app.config["EVIDENCE_MAX_BYTES"]),
                "max_edge_pixels": int(current_app.config["EVIDENCE_MAX_EDGE"]),
                "allowed_mime_types": ["image/jpeg", "image/png", "image/webp"],
                "private_by_default": True,
                "durable": True,
                "exif_removed": True,
                "observation_max_length": 280,
                "sentence_max_length": 160,
            }
        }
    )


@api.get("/policies/community")
@require_user
def community_policy():
    return jsonify({"data": _services()["community"].policy()})


@api.post("/auth/upgrade-legacy")
@require_user
def upgrade_legacy_user():
    body = _json_body()
    username = body.get("username")
    password = body.get("password")
    if not isinstance(username, str) or not isinstance(password, str):
        raise ValidationError("username 与 password 为必填字符串")
    result = _services()["authentication"].upgrade_legacy(g.current_user.id, username, password)
    current_app.logger.info("auth_legacy_upgraded user=%s", result[0].id[:8])
    return jsonify({"data": _authorization_payload(result)})


@api.get("/cities")
def list_cities():
    cities = _services()["catalog"].list_cities()
    return jsonify({"data": [city_to_dict(city) for city in cities]})


@api.get("/cities/<city_slug>/routes")
def list_city_routes(city_slug: str):
    city, routes = _services()["catalog"].list_city_routes(city_slug)
    route_payloads = [
        _route_payload(route, include_stops=False, include_center=True) for route in routes
    ]
    return jsonify(
        {
            "data": {
                "city": city_to_dict(city),
                "routes": route_payloads,
            }
        }
    )


@api.get("/cities/<city_slug>/stories")
def list_city_stories(city_slug: str):
    return jsonify({"data": _services()["city_stories"].home(city_slug)})


@api.get("/routes/<route_slug>")
def get_route(route_slug: str):
    route = _services()["catalog"].get_route(route_slug)
    return jsonify({"data": _route_payload(route)})


@api.get("/routes/<route_slug>/offline-package")
def get_route_offline_package(route_slug: str):
    route = _services()["catalog"].get_route(route_slug)
    if route.content_status is not ContentStatus.PUBLISHED:
        abort(404)
    manifest = _services()["fragment_tours"].offline_manifest(route.id)
    if manifest is None:
        abort(404)
    city = next(
        (item for item in _services()["catalog"].list_cities() if item.id == route.city_id),
        None,
    )
    if city is None:
        abort(404)
    route_payload = _route_payload(route)
    route_payload["audio_tour"] = manifest
    package = {
        "package_version": manifest["script_version"],
        "city": city_to_dict(city),
        "route": route_payload,
    }
    canonical = json.dumps(
        package,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode()
    package["package_checksum_sha256"] = hashlib.sha256(canonical).hexdigest()
    return jsonify({"data": package})


@api.get("/stories/random")
def random_story():
    return jsonify(
        {
            "data": _services()["story_listening"].random_story(
                str(request.args.get("city_slug") or ""),
                request.args.get("exclude_id"),
            )
        }
    )


@api.get("/stories/<publication_id>")
def get_listening_story(publication_id: str):
    return jsonify({"data": _services()["story_listening"].get(publication_id)})


@api.get("/city-stories/<catalog_id>")
def get_city_story(catalog_id: str):
    return jsonify(
        {
            "data": _services()["city_stories"].get_story(
                catalog_id, request.args.get("variant_role")
            )
        }
    )


@api.get("/routes/<route_slug>/pretrip")
def get_route_pretrip(route_slug: str):
    return jsonify({"data": _services()["city_stories"].pretrip(route_slug)})


@api.get("/favorites")
@require_user
def list_favorites():
    return jsonify({"data": _services()["city_stories"].list_favorites(g.current_user.id)})


@api.put("/favorites/<target_kind>/<path:target_id>")
@require_user
def add_favorite(target_kind: str, target_id: str):
    return jsonify(
        {
            "data": _services()["city_stories"].add_favorite(
                g.current_user.id, target_kind, target_id
            )
        }
    )


@api.delete("/favorites/<target_kind>/<path:target_id>")
@require_user
def remove_favorite(target_kind: str, target_id: str):
    return jsonify(
        {
            "data": _services()["city_stories"].remove_favorite(
                g.current_user.id, target_kind, target_id
            )
        }
    )


@api.post("/journeys")
@require_user
def start_journey():
    body = _json_body()
    route_id = body.get("route_id")
    if not isinstance(route_id, str) or not route_id:
        raise ValidationError("route_id 为必填字符串")
    journey = _services()["journeys"].start_or_resume(g.current_user.id, route_id)
    _services()["fragment_tours"].initialize_journey(journey.id, route_id)
    route = _services()["catalog"].get_route_for_journey(route_id)
    return jsonify({"data": journey_to_dict(journey, len(route.stops))}), 201


@api.get("/journeys/<journey_id>")
@require_user
def get_journey(journey_id: str):
    journey = _services()["journeys"].get(g.current_user.id, journey_id)
    route = _services()["catalog"].get_route_for_journey(journey.route_id)
    return jsonify({"data": journey_to_dict(journey, len(route.stops))})


@api.get("/journeys/<journey_id>/context")
@require_user
def get_journey_context(journey_id: str):
    journey = _services()["journeys"].get(g.current_user.id, journey_id)
    route = _services()["catalog"].get_route_for_journey(journey.route_id)
    route_payload = _route_payload(route)
    if "audio_tour" in route_payload:
        ledger = _services()["fragment_tours"].ledger(g.current_user.id, journey_id)
        collected_count = ledger["collected_count"]
        total_count = ledger["total_count"]
        journey_kind = "fragmented"
    else:
        collected_count = len(journey.answers)
        total_count = len(route.stops)
        ledger = None
        journey_kind = "legacy"
    return jsonify(
        {
            "data": {
                "journey": journey_to_dict(journey, total_count),
                "route": route_payload,
                "journey_kind": journey_kind,
                "progress": {
                    "collected_count": collected_count,
                    "total_count": total_count,
                },
                "ledger": ledger,
            }
        }
    )


@api.get("/journeys/active")
@require_user
def list_active_journeys():
    rows = []
    for journey in _services()["journeys"].list_active(g.current_user.id):
        route = _services()["catalog"].get_route_for_journey(journey.route_id)
        rows.append(
            {
                "journey": journey_to_dict(journey, len(route.stops)),
                "route": _route_payload(route),
            }
        )
    return jsonify({"data": rows})


@api.get("/journeys")
@require_user
def list_journeys():
    raw_status = request.args.get("status")
    statuses = None
    if raw_status is not None:
        try:
            statuses = (JourneyStatus(raw_status),)
        except ValueError as exc:
            raise ValidationError("status 仅支持 active 或 completed") from exc
    items = _services()["journeys"].list_library(g.current_user.id, statuses)
    return jsonify({"data": [journey_library_item_to_dict(item) for item in items]})


@api.delete("/journeys/progress")
@require_user
def clear_journey_progress():
    return jsonify(
        {"data": _services()["journeys"].clear_exploration_progress(g.current_user.id)}
    )


@api.post("/journeys/<journey_id>/arrivals")
@require_user
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
        g.current_user.id,
        journey_id,
        demo=demo,
        latitude=float(latitude) if latitude is not None else None,
        longitude=float(longitude) if longitude is not None else None,
    )
    route = _services()["catalog"].get_route_for_journey(journey.route_id)
    return jsonify(
        {
            "data": {
                "journey": journey_to_dict(journey, len(route.stops)),
                "distance_m": round(distance, 1) if distance is not None else None,
            }
        }
    )


@api.post("/journeys/<journey_id>/answers")
@require_user
def answer(journey_id: str):
    body = _json_body()
    stop_id = body.get("stop_id")
    selected_option = body.get("selected_option")
    if not isinstance(stop_id, str) or not stop_id:
        raise ValidationError("stop_id 为必填字符串")
    if not isinstance(selected_option, int) or isinstance(selected_option, bool):
        raise ValidationError("selected_option 必须是整数")
    answer_result, stop = _services()["journeys"].answer(
        g.current_user.id,
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
@require_user
def advance(journey_id: str):
    journey = _services()["journeys"].advance(g.current_user.id, journey_id)
    route = _services()["catalog"].get_route_for_journey(journey.route_id)
    return jsonify({"data": journey_to_dict(journey, len(route.stops))})


@api.get("/journeys/<journey_id>/recap")
@require_user
def recap(journey_id: str):
    journey = _services()["journeys"].get(g.current_user.id, journey_id)
    if _services()["fragment_tours"].public_manifest(journey.route_id) is not None:
        return jsonify({"data": _services()["fragment_tours"].recap(g.current_user.id, journey_id)})
    journey, route = _services()["journeys"].recap(g.current_user.id, journey_id)
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
@require_user
def start_active_tour(journey_id: str):
    return jsonify(
        {"data": _services()["fragment_tours"].start_active_tour(g.current_user.id, journey_id)}
    )


@api.delete("/journeys/<journey_id>/active-tour")
@require_user
def stop_active_tour(journey_id: str):
    return jsonify(
        {"data": _services()["fragment_tours"].stop_active_tour(g.current_user.id, journey_id)}
    )


@api.post("/journeys/<journey_id>/fragments/<fragment_id>/triggers")
@require_user
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
        g.current_user.id, journey_id, fragment_id, payload
    )
    try:
        _services()["footprints"].reconcile_journey(g.current_user.id, journey_id)
    except Exception:
        current_app.logger.exception(
            "footprint_reconcile_failed journey=%s fragment=%s", journey_id, fragment_id
        )
    current_app.logger.info(
        "fragment_trigger_accepted journey=%s fragment=%s method=%s",
        journey_id,
        fragment_id,
        method,
    )
    return jsonify({"data": result})


@api.get("/footprints")
@require_user
def list_footprints():
    return jsonify(
        {
            "data": _services()["footprints"].list(
                g.current_user.id,
                city_slug=request.args.get("city_slug"),
                theme=request.args.get("theme"),
                journey_state=request.args.get("journey_state"),
                organization_state=request.args.get("organization_state"),
                month=request.args.get("month"),
                order=request.args.get("order", "recent"),
                cursor=request.args.get("cursor"),
                limit=_page_limit(default=20),
            )
        }
    )


@api.get("/footprints/resume-candidate")
@require_user
def footprint_resume_candidate():
    return jsonify({"data": _services()["footprints"].resume_candidate(g.current_user.id)})


@api.get("/footprints/<footprint_id>")
@require_user
def footprint_detail(footprint_id: str):
    return jsonify({"data": _services()["footprints"].detail(g.current_user.id, footprint_id)})


@api.patch("/footprints/<footprint_id>")
@require_user
def update_footprint(footprint_id: str):
    return jsonify(
        {"data": _services()["footprints"].update(g.current_user.id, footprint_id, _json_body())}
    )


@api.get("/footprints/<footprint_id>/related-content")
@require_user
def footprint_related_content(footprint_id: str):
    return jsonify(
        {"data": _services()["footprints"].related_content(g.current_user.id, footprint_id)}
    )


@api.post("/footprints/<footprint_id>/photo")
@require_user
def upload_footprint_photo(footprint_id: str):
    photo = request.files.get("photo")
    idempotency_key = request.form.get("idempotency_key", "")
    if photo is None or not idempotency_key:
        raise ValidationError("photo 与 idempotency_key 为必填字段")
    return (
        jsonify(
            {
                "data": _services()["footprints"].upload_photo(
                    g.current_user.id, footprint_id, photo, idempotency_key
                )
            }
        ),
        201,
    )


@api.get("/footprints/<footprint_id>/photo")
@require_user
def get_footprint_photo(footprint_id: str):
    stream, mime_type = _services()["footprints"].open_photo(g.current_user.id, footprint_id)
    return send_file(stream, mimetype=mime_type, download_name=f"footprint-{footprint_id}")


@api.delete("/footprints/<footprint_id>/photo")
@require_user
def delete_footprint_photo(footprint_id: str):
    return jsonify(
        {"data": _services()["footprints"].delete_photo(g.current_user.id, footprint_id)}
    )


@api.post("/journeys/<journey_id>/fragments/<fragment_id>/playback")
@require_user
def fragment_playback(journey_id: str, fragment_id: str):
    return jsonify(
        {
            "data": _services()["fragment_tours"].playback(
                g.current_user.id, journey_id, fragment_id, _json_body()
            )
        }
    )


@api.post("/journeys/<journey_id>/fragments/<fragment_id>/evidence")
@require_user
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
        g.current_user.id, journey_id, fragment_id, file, key, captured_at
    )
    return jsonify({"data": evidence}), 201


@api.get("/journeys/<journey_id>/fragments/<fragment_id>/community-posts")
@require_user
def list_community_posts(journey_id: str, fragment_id: str):
    return jsonify(
        {
            "data": _services()["community"].feed(
                g.current_user.id,
                journey_id,
                fragment_id,
                category=request.args.get("category"),
                cursor=request.args.get("cursor"),
                limit=_page_limit(),
            )
        }
    )


@api.post("/journeys/<journey_id>/fragments/<fragment_id>/community-posts")
@require_user
def create_community_post(journey_id: str, fragment_id: str):
    evidence_ids = request.form.getlist("evidence_ids") + request.form.getlist("evidence_ids[]")
    result = _services()["community"].create_post(
        g.current_user.id,
        journey_id,
        fragment_id,
        category=request.form.get("category", ""),
        title=request.form.get("title"),
        body=request.form.get("body"),
        idempotency_key=request.form.get("idempotency_key", ""),
        files=request.files.getlist("photos") + request.files.getlist("photos[]"),
        evidence_ids=[value for value in evidence_ids if value],
    )
    return jsonify({"data": result}), 201


@api.get("/community-posts/<post_id>")
@require_user
def community_post_detail(post_id: str):
    return jsonify({"data": _services()["community"].detail(g.current_user.id, post_id)})


@api.delete("/community-posts/<post_id>")
@require_user
def delete_community_post(post_id: str):
    return jsonify({"data": _services()["community"].delete_post(g.current_user.id, post_id)})


@api.get("/community-posts/<post_id>/likes")
@require_user
def community_post_likers(post_id: str):
    return jsonify(
        {
            "data": _services()["community"].likers(
                g.current_user.id,
                post_id,
                cursor=request.args.get("cursor"),
                limit=_page_limit(),
            )
        }
    )


@api.put("/community-posts/<post_id>/like")
@require_user
def like_community_post(post_id: str):
    return jsonify({"data": _services()["community"].set_like(g.current_user.id, post_id, True)})


@api.delete("/community-posts/<post_id>/like")
@require_user
def unlike_community_post(post_id: str):
    return jsonify({"data": _services()["community"].set_like(g.current_user.id, post_id, False)})


@api.get("/community-posts/<post_id>/comments")
@require_user
def list_community_comments(post_id: str):
    return jsonify(
        {
            "data": _services()["community"].comments(
                g.current_user.id,
                post_id,
                cursor=request.args.get("cursor"),
                limit=_page_limit(),
            )
        }
    )


@api.post("/community-posts/<post_id>/comments")
@require_user
def create_community_comment(post_id: str):
    body = _json_body()
    reply_to_comment_id = body.get("reply_to_comment_id")
    if reply_to_comment_id is None and body.get("parent_id") is not None:
        reply_to_comment_id = body.get("parent_id")
    return (
        jsonify(
            {
                "data": _services()["community"].create_comment(
                    g.current_user.id,
                    post_id,
                    body=str(body.get("body") or ""),
                    idempotency_key=str(body.get("idempotency_key") or ""),
                    reply_to_comment_id=(
                        str(reply_to_comment_id) if reply_to_comment_id is not None else None
                    ),
                )
            }
        ),
        201,
    )


@api.get("/community-comments/<comment_id>/replies")
@require_user
def list_community_replies(comment_id: str):
    return jsonify(
        {
            "data": _services()["community"].replies(
                g.current_user.id,
                comment_id,
                cursor=request.args.get("cursor"),
                limit=_page_limit(),
            )
        }
    )


@api.delete("/community-comments/<comment_id>")
@require_user
def delete_community_comment(comment_id: str):
    return jsonify({"data": _services()["community"].delete_comment(g.current_user.id, comment_id)})


@api.post("/community-posts/<post_id>/reports")
@require_user
def report_community_post(post_id: str):
    body = _json_body()
    return (
        jsonify(
            {
                "data": _services()["community"].report(
                    g.current_user.id, "post", post_id, str(body.get("reason") or "")
                )
            }
        ),
        201,
    )


@api.post("/community-comments/<comment_id>/reports")
@require_user
def report_community_comment(comment_id: str):
    body = _json_body()
    return (
        jsonify(
            {
                "data": _services()["community"].report(
                    g.current_user.id,
                    "comment",
                    comment_id,
                    str(body.get("reason") or ""),
                )
            }
        ),
        201,
    )


@api.get("/community-media/<media_id>")
@require_user
def get_community_media(media_id: str):
    stream, mime_type = _services()["community"].open_media(g.current_user.id, media_id)
    return send_file(stream, mimetype=mime_type, download_name=f"community-{media_id}")


@api.get("/journeys/<journey_id>/evidence/<evidence_id>")
@require_user
def get_evidence(journey_id: str, evidence_id: str):
    stream, mime_type = _services()["fragment_tours"].open_evidence(
        g.current_user.id, journey_id, evidence_id
    )
    return send_file(stream, mimetype=mime_type, download_name=f"evidence-{evidence_id}")


@api.get("/journeys/<journey_id>/evidence")
@require_user
def list_evidence(journey_id: str):
    return jsonify(
        {"data": _services()["fragment_tours"].list_evidence(g.current_user.id, journey_id)}
    )


@api.delete("/journeys/<journey_id>/evidence/<evidence_id>")
@require_user
def delete_evidence(journey_id: str, evidence_id: str):
    return jsonify(
        {
            "data": _services()["fragment_tours"].delete_evidence(
                g.current_user.id, journey_id, evidence_id
            )
        }
    )


@api.get("/journeys/<journey_id>/ledger")
@require_user
def story_ledger(journey_id: str):
    ledger = _services()["fragment_tours"].ledger(g.current_user.id, journey_id)
    try:
        _services()["footprints"].reconcile_journey(g.current_user.id, journey_id)
    except Exception:
        current_app.logger.exception("footprint_ledger_reconcile_failed journey=%s", journey_id)
    state_counts: dict[str, int] = {}
    for entry in ledger["entries"]:
        entry_state = str(entry["state"])
        state_counts[entry_state] = state_counts.get(entry_state, 0) + 1
    current_app.logger.info(
        "journey_ledger_loaded journey=%s collected=%s total=%s states=%s",
        journey_id,
        ledger["collected_count"],
        ledger["total_count"],
        ",".join(f"{key}:{value}" for key, value in sorted(state_counts.items())),
    )
    return jsonify({"data": ledger})


@api.post("/journeys/<journey_id>/reconstruction")
@require_user
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
                g.current_user.id, journey_id, relationships
            )
        }
    )


def _route_payload(route, *, include_stops: bool = True, include_center: bool = False) -> dict:
    payload = route_to_dict(route, include_stops=include_stops)
    tour = _services()["fragment_tours"].public_manifest(route.id)
    if tour is not None:
        payload["audio_tour"] = tour
        payload["fragment_count"] = tour["fragment_count"]
        payload["photo_mission_count"] = tour["photo_mission_count"]
        payload["download_size_bytes"] = tour["download_size_bytes"]
    if include_center:
        payload["center"] = _route_center(route, tour)
    if route.content_status.value == "published":
        payload["pretrip"] = _services()["city_stories"].pretrip(route.slug)
        payload["predeparture"] = payload["pretrip"].get("predeparture")
        payload["companion_tags"] = payload["pretrip"]["companion_tags"]
    return payload


def _route_center(route, tour: dict | None) -> dict | None:
    coordinates: list[tuple[float, float]] = []
    if isinstance(tour, dict) and tour.get("fragments"):
        for fragment in tour["fragments"]:
            region = fragment.get("trigger_region") or {}
            latitude = region.get("latitude")
            longitude = region.get("longitude")
            if isinstance(latitude, int | float) and isinstance(longitude, int | float):
                coordinates.append((float(latitude), float(longitude)))
    else:
        coordinates.extend((stop.latitude, stop.longitude) for stop in route.stops)
    if not coordinates:
        return None
    latitudes = [item[0] for item in coordinates]
    longitudes = [item[1] for item in coordinates]
    return {
        "latitude": (min(latitudes) + max(latitudes)) / 2,
        "longitude": (min(longitudes) + max(longitudes)) / 2,
    }
