from app.infrastructure.persistence.seed import seed_database


def test_health_and_catalog(client):
    health = client.get("/api/v1/health")
    assert health.status_code == 200
    assert health.get_json()["data"]["database"] == "up"

    cities = client.get("/api/v1/cities")
    assert cities.status_code == 200
    assert cities.get_json()["data"][0]["slug"] == "shanghai"

    routes = client.get("/api/v1/cities/shanghai/routes")
    featured = routes.get_json()["data"]["routes"][0]
    assert featured["stop_count"] == 5

    detail = client.get("/api/v1/routes/wukang-urban-slices")
    route = detail.get_json()["data"]
    assert route["content_status"] == "demo_unverified"
    assert [stop["position"] for stop in route["stops"]] == [1, 2, 3, 4, 5]
    assert "correct_option" not in route["stops"][0]["challenge"]


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


def test_seed_is_idempotent(app):
    database = app.extensions["database"]
    session = database.session_factory()
    assert seed_database(session) is False
    session.close()
