import json

from app.infrastructure.persistence.models import JourneyModel, RouteModel, UserModel
from app.infrastructure.persistence.seed import seed_database


def test_health_and_catalog(client):
    health = client.get("/api/v1/health")
    assert health.status_code == 200
    assert health.get_json()["data"]["database"] == "up"

    cities = client.get("/api/v1/cities")
    assert cities.status_code == 200
    city_slugs = {city["slug"] for city in cities.get_json()["data"]}
    assert city_slugs == {"shanghai", "shenzhen"}

    routes = client.get("/api/v1/cities/shanghai/routes")
    featured = routes.get_json()["data"]["routes"][0]
    assert featured["stop_count"] == 5

    detail = client.get("/api/v1/routes/wukang-urban-slices")
    route = detail.get_json()["data"]
    assert route["content_status"] == "published"
    assert route["hero_image"].startswith("http://localhost/api/v1/assets/")
    assert [stop["position"] for stop in route["stops"]] == [1, 2, 3, 4, 5]
    assert "correct_option" not in route["stops"][0]["challenge"]

    media = client.get("/api/v1/assets/images/route_wukang.png")
    assert media.status_code == 200
    assert media.content_type == "image/png"
    assert client.get("/api/v1/assets/../requirements.txt").status_code == 404


def test_shenzhen_featured_route_and_media(client):
    routes = client.get("/api/v1/cities/shenzhen/routes")
    assert routes.status_code == 200
    payload = routes.get_json()["data"]
    assert payload["city"]["name"] == "深圳"
    assert payload["routes"][0]["slug"] == "nantou-time-layers"
    assert payload["routes"][0]["stop_count"] == 5

    detail = client.get("/api/v1/routes/nantou-time-layers")
    route = detail.get_json()["data"]
    assert route["content_status"] == "published"
    assert [stop["position"] for stop in route["stops"]] == [1, 2, 3, 4, 5]
    assert route["hero_image"].endswith("/assets/images/route_shenzhen.png")

    media = client.get("/api/v1/assets/images/route_shenzhen.png")
    assert media.status_code == 200
    assert media.content_type == "image/png"


def test_unknown_city_has_structured_error(client):
    response = client.get("/api/v1/cities/unknown/routes")
    assert response.status_code == 404
    assert response.get_json()["error"]["code"] == "city_not_found"


def test_journey_requires_guest(client):
    response = client.post("/api/v1/journeys", json={"route_id": "anything"})
    assert response.status_code == 401
    assert response.get_json()["error"]["code"] == "unauthorized"


def test_evidence_policy_is_runtime_driven_authenticated_and_secret_free(
    app, client, user_headers
):
    assert client.get("/api/v1/policies/evidence").status_code == 401
    response = client.get("/api/v1/policies/evidence", headers=user_headers)
    assert response.status_code == 200
    payload = response.get_json()["data"]
    assert payload == {
        "upload_enabled": bool(app.config["EVIDENCE_UPLOAD_ENABLED"]),
        "retention_days": int(app.config["EVIDENCE_RETENTION_DAYS"]),
        "max_bytes": int(app.config["EVIDENCE_MAX_BYTES"]),
        "max_edge_pixels": int(app.config["EVIDENCE_MAX_EDGE"]),
        "allowed_mime_types": ["image/jpeg", "image/png", "image/webp"],
        "private_access": True,
        "exif_removed": True,
        "normalized_on_upload": True,
    }
    serialized = json.dumps(payload).lower()
    assert not any(
        secret_name in serialized
        for secret_name in ("secret", "bucket", "object_key", "evidence_root", "access_key")
    )


def test_complete_five_stop_journey(client, guest_headers):
    route = client.get("/api/v1/routes/wukang-urban-slices").get_json()["data"]
    start = client.post(
        "/api/v1/journeys",
        json={"route_id": route["id"]},
        headers=guest_headers,
    )
    assert start.status_code == 201
    journey = start.get_json()["data"]
    journey_id = journey["id"]

    resume = client.post(
        "/api/v1/journeys",
        json={"route_id": route["id"]},
        headers=guest_headers,
    )
    assert resume.get_json()["data"]["id"] == journey_id

    correct_options = [0, 1, 1, 1, 0]
    first_answer_payload = None
    for index, stop in enumerate(route["stops"]):
        arrival = client.post(
            f"/api/v1/journeys/{journey_id}/arrivals",
            json={"demo": True},
            headers=guest_headers,
        )
        assert arrival.status_code == 200
        assert arrival.get_json()["data"]["journey"]["arrived_stop_id"] == stop["id"]

        answer = client.post(
            f"/api/v1/journeys/{journey_id}/answers",
            json={"stop_id": stop["id"], "selected_option": correct_options[index]},
            headers=guest_headers,
        )
        assert answer.status_code == 200
        assert answer.get_json()["data"]["is_correct"] is True
        if index == 0:
            first_answer_payload = answer.get_json()
            repeated = client.post(
                f"/api/v1/journeys/{journey_id}/answers",
                json={"stop_id": stop["id"], "selected_option": 2},
                headers=guest_headers,
            )
            assert repeated.get_json() == first_answer_payload

        advanced = client.post(
            f"/api/v1/journeys/{journey_id}/advance",
            headers=guest_headers,
        )
        assert advanced.status_code == 200

    assert advanced.get_json()["data"]["status"] == "completed"
    recap = client.get(f"/api/v1/journeys/{journey_id}/recap", headers=guest_headers)
    assert recap.status_code == 200
    assert len(recap.get_json()["data"]["insights"]) == 5


def test_completed_route_start_revisits_same_owned_journey(app, client, user_headers):
    route = client.get("/api/v1/routes/wukang-urban-slices").get_json()["data"]
    journey = client.post(
        "/api/v1/journeys", json={"route_id": route["id"]}, headers=user_headers
    ).get_json()["data"]
    correct_options = [0, 1, 1, 1, 0]
    for index, stop in enumerate(route["stops"]):
        client.post(
            f"/api/v1/journeys/{journey['id']}/arrivals",
            json={"demo": True},
            headers=user_headers,
        )
        client.post(
            f"/api/v1/journeys/{journey['id']}/answers",
            json={"stop_id": stop["id"], "selected_option": correct_options[index]},
            headers=user_headers,
        )
        client.post(f"/api/v1/journeys/{journey['id']}/advance", headers=user_headers)

    revisit = client.post(
        "/api/v1/journeys", json={"route_id": route["id"]}, headers=user_headers
    )
    assert revisit.status_code == 201
    assert revisit.get_json()["data"]["id"] == journey["id"]
    assert revisit.get_json()["data"]["status"] == "completed"

    database = app.extensions["database"]
    session = database.session_factory()
    owner = session.query(UserModel).filter_by(username="traveler-one").one()
    assert (
        session.query(JourneyModel)
        .filter_by(user_id=owner.id, route_id=route["id"])
        .count()
        == 1
    )
    session.close()

    other_headers = _register_test_user(client, "completed-other-user")
    other = client.post(
        "/api/v1/journeys", json={"route_id": route["id"]}, headers=other_headers
    )
    assert other.status_code == 201
    assert other.get_json()["data"]["id"] != journey["id"]


def test_location_rejects_far_position(client, guest_headers):
    route = client.get("/api/v1/routes/wukang-urban-slices").get_json()["data"]
    journey = client.post(
        "/api/v1/journeys", json={"route_id": route["id"]}, headers=guest_headers
    ).get_json()["data"]
    response = client.post(
        f"/api/v1/journeys/{journey['id']}/arrivals",
        json={"latitude": 39.9, "longitude": 116.4},
        headers=guest_headers,
    )
    assert response.status_code == 409
    assert response.get_json()["error"]["code"] == "too_far_from_stop"


def test_location_accepts_real_position(client, guest_headers):
    route = client.get("/api/v1/routes/wukang-urban-slices").get_json()["data"]
    journey = client.post(
        "/api/v1/journeys", json={"route_id": route["id"]}, headers=guest_headers
    ).get_json()["data"]
    stop = route["stops"][0]
    response = client.post(
        f"/api/v1/journeys/{journey['id']}/arrivals",
        json={"latitude": stop["latitude"], "longitude": stop["longitude"]},
        headers=guest_headers,
    )
    assert response.status_code == 200
    assert response.get_json()["data"]["distance_m"] == 0.0


def test_demo_arrival_can_be_disabled(app, client, guest_headers):
    app.extensions["services"]["journeys"].allow_demo_arrival = False
    route = client.get("/api/v1/routes/wukang-urban-slices").get_json()["data"]
    journey = client.post(
        "/api/v1/journeys", json={"route_id": route["id"]}, headers=guest_headers
    ).get_json()["data"]
    response = client.post(
        f"/api/v1/journeys/{journey['id']}/arrivals",
        json={"demo": True},
        headers=guest_headers,
    )
    assert response.status_code == 403
    assert response.get_json()["error"]["code"] == "demo_arrival_disabled"


def test_seed_is_idempotent(app):
    database = app.extensions["database"]
    session = database.session_factory()
    assert seed_database(session) is False
    session.close()


def test_published_status_remains_public_and_truthful(app, client):
    database = app.extensions["database"]
    session = database.session_factory()
    route = session.query(RouteModel).filter_by(slug="nantou-time-layers").one()
    route.content_status = "published"
    session.commit()
    session.close()

    response = client.get("/api/v1/routes/nantou-time-layers")

    assert response.status_code == 200
    assert response.get_json()["data"]["content_status"] == "published"


def test_verified_route_is_offline_and_city_without_published_routes_is_hidden(app, client):
    database = app.extensions["database"]
    session = database.session_factory()
    route = session.query(RouteModel).filter_by(slug="wukang-urban-slices").one()
    route.content_status = "verified"
    route.published_at = None
    session.commit()
    session.close()

    assert client.get("/api/v1/routes/wukang-urban-slices").status_code == 404
    cities = client.get("/api/v1/cities").get_json()["data"]
    assert "shanghai" not in {item["slug"] for item in cities}
    assert client.get("/api/v1/cities/shanghai/routes").status_code == 404


def test_archived_route_rejects_new_start_but_existing_owner_continues(app, client, user_headers):
    route = client.get("/api/v1/routes/wukang-urban-slices").get_json()["data"]
    journey = client.post(
        "/api/v1/journeys", json={"route_id": route["id"]}, headers=user_headers
    ).get_json()["data"]

    database = app.extensions["database"]
    session = database.session_factory()
    model = session.get(RouteModel, route["id"])
    model.content_status = "archived"
    session.commit()
    session.close()

    assert client.get("/api/v1/routes/wukang-urban-slices").status_code == 404
    resumed = client.post(
        "/api/v1/journeys", json={"route_id": route["id"]}, headers=user_headers
    )
    assert resumed.status_code == 201
    assert resumed.get_json()["data"]["id"] == journey["id"]
    other = _register_test_user(client, "archived-new-user")
    rejected = client.post("/api/v1/journeys", json={"route_id": route["id"]}, headers=other)
    assert rejected.status_code == 404
    assert client.get(f"/api/v1/journeys/{journey['id']}", headers=user_headers).status_code == 200
    active = client.get("/api/v1/journeys/active", headers=user_headers)
    assert active.status_code == 200
    archived_entry = next(
        item for item in active.get_json()["data"] if item["journey"]["id"] == journey["id"]
    )
    assert archived_entry["route"]["content_status"] == "archived"
    assert archived_entry["route"]["slug"] == "wukang-urban-slices"
    continued = client.post(
        f"/api/v1/journeys/{journey['id']}/arrivals",
        json={"demo": True},
        headers=user_headers,
    )
    assert continued.status_code == 200


def test_journey_library_filters_orders_and_isolates_accounts(app, client, user_headers):
    legacy_route = client.get("/api/v1/routes/wukang-urban-slices").get_json()["data"]
    fragmented_route = client.get("/api/v1/routes/nantou-time-layers").get_json()["data"]
    completed = client.post(
        "/api/v1/journeys",
        json={"route_id": legacy_route["id"]},
        headers=user_headers,
    ).get_json()["data"]

    database = app.extensions["database"]
    session = database.session_factory()
    completed_model = session.get(JourneyModel, completed["id"])
    completed_model.status = "completed"
    completed_model.completed_at = completed_model.updated_at
    session.commit()
    session.close()

    active = client.post(
        "/api/v1/journeys",
        json={"route_id": fragmented_route["id"]},
        headers=user_headers,
    ).get_json()["data"]
    response = client.get("/api/v1/journeys", headers=user_headers)
    assert response.status_code == 200
    rows = response.get_json()["data"]
    assert {item["journey"]["id"] for item in rows} == {completed["id"], active["id"]}
    assert {item["journey_kind"] for item in rows} == {"legacy", "fragmented"}
    assert all("stops" not in item["route"] for item in rows)
    assert all(
        {"collected_count", "total_count", "evidence_count"} <= set(item)
        for item in rows
    )

    completed_rows = client.get(
        "/api/v1/journeys?status=completed", headers=user_headers
    ).get_json()["data"]
    assert [item["journey"]["id"] for item in completed_rows] == [completed["id"]]
    assert client.get(
        "/api/v1/journeys?status=unknown", headers=user_headers
    ).status_code == 422

    active_rows = client.get("/api/v1/journeys/active", headers=user_headers)
    assert active_rows.status_code == 200
    assert [item["journey"]["id"] for item in active_rows.get_json()["data"]] == [
        active["id"]
    ]
    other_headers = _register_test_user(client, "library-other-user")
    assert client.get("/api/v1/journeys", headers=other_headers).get_json()["data"] == []


def test_owner_context_recovers_archived_fragment_route_and_hides_from_others(
    app, client, user_headers
):
    route = client.get("/api/v1/routes/nantou-time-layers").get_json()["data"]
    journey = client.post(
        "/api/v1/journeys", json={"route_id": route["id"]}, headers=user_headers
    ).get_json()["data"]
    database = app.extensions["database"]
    session = database.session_factory()
    session.get(RouteModel, route["id"]).content_status = "archived"
    session.commit()
    session.close()

    assert client.get("/api/v1/routes/nantou-time-layers").status_code == 404
    context = client.get(
        f"/api/v1/journeys/{journey['id']}/context", headers=user_headers
    )
    assert context.status_code == 200
    payload = context.get_json()["data"]
    assert payload["journey"]["id"] == journey["id"]
    assert payload["route"]["content_status"] == "archived"
    assert payload["route"]["audio_tour"]["fragments"]
    assert payload["journey_kind"] == "fragmented"
    assert payload["ledger"]["journey_id"] == journey["id"]

    other_headers = _register_test_user(client, "context-other-user")
    hidden = client.get(
        f"/api/v1/journeys/{journey['id']}/context", headers=other_headers
    )
    assert hidden.status_code == 404


def _register_test_user(client, username: str) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": username, "password": "field-test-123"},
    )
    token = response.get_json()["data"]["token"]
    return {"Authorization": f"Bearer {token}"}
