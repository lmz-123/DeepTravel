from app.infrastructure.persistence.models import RouteModel
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


def _register_test_user(client, username: str) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": username, "password": "field-test-123"},
    )
    token = response.get_json()["data"]["token"]
    return {"Authorization": f"Bearer {token}"}
