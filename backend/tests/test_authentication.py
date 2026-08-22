from __future__ import annotations

from datetime import UTC, datetime, timedelta

from app import create_app
from app.infrastructure.persistence.models import JourneyModel, UserModel
from app.infrastructure.persistence.seed import seed_database
from app.infrastructure.security import JwtTokenCodec


def _register(client, username: str) -> dict:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": username, "password": "field-test-123"},
    )
    assert response.status_code == 201
    return response.get_json()["data"]


def test_register_login_me_and_password_hash(app, client):
    registered = _register(client, "Traveler.One")
    assert registered["user"]["username"] == "traveler.one"
    headers = {"Authorization": f"Bearer {registered['token']}"}
    assert (
        client.get("/api/v1/auth/me", headers=headers).get_json()["data"]["id"]
        == registered["user"]["id"]
    )

    login = client.post(
        "/api/v1/auth/login",
        json={"username": "TRAVELER.ONE", "password": "field-test-123"},
    )
    assert login.status_code == 200
    assert login.get_json()["data"]["user"]["id"] == registered["user"]["id"]

    session = app.extensions["database"].session_factory()
    model = session.get(UserModel, registered["user"]["id"])
    assert model.password_hash != "field-test-123"
    assert model.password_hash.startswith("scrypt:")
    session.close()


def test_duplicate_and_invalid_login_are_generic(client):
    _register(client, "duplicate-user")
    duplicate = client.post(
        "/api/v1/auth/register",
        json={"username": "duplicate-user", "password": "field-test-123"},
    )
    assert duplicate.status_code == 409

    unknown = client.post(
        "/api/v1/auth/login",
        json={"username": "missing-user", "password": "wrong-pass"},
    )
    incorrect = client.post(
        "/api/v1/auth/login",
        json={"username": "duplicate-user", "password": "wrong-pass"},
    )
    assert unknown.status_code == incorrect.status_code == 401
    assert unknown.get_json()["error"] == incorrect.get_json()["error"]


def test_auth_logs_use_only_sanitized_user_correlation(client, caplog):
    password = "never-log-this-password"
    registered = client.post(
        "/api/v1/auth/register",
        json={"username": "private-log-user", "password": password},
    )
    token = registered.get_json()["data"]["token"]
    client.post(
        "/api/v1/auth/login",
        json={"username": "private-log-user", "password": password},
    )

    assert "auth_register_success user=" in caplog.text
    assert "auth_login_success user=" in caplog.text
    assert password not in caplog.text
    assert token not in caplog.text
    assert "private-log-user" not in caplog.text


def test_test_users_are_isolated_and_same_user_resumes(client):
    route = client.get("/api/v1/routes/nantou-time-layers").get_json()["data"]
    tester_a = client.post("/api/v1/auth/test-login", json={"alias": "tester-a"}).get_json()["data"]
    tester_b = client.post("/api/v1/auth/test-login", json={"alias": "tester-b"}).get_json()["data"]
    headers_a = {"Authorization": f"Bearer {tester_a['token']}"}
    headers_b = {"Authorization": f"Bearer {tester_b['token']}"}
    journey = client.post(
        "/api/v1/journeys", json={"route_id": route["id"]}, headers=headers_a
    ).get_json()["data"]

    denied = client.get(f"/api/v1/journeys/{journey['id']}", headers=headers_b)
    assert denied.status_code == 404

    tester_a_again = client.post("/api/v1/auth/test-login", json={"alias": "tester-a"}).get_json()[
        "data"
    ]
    resumed = client.post(
        "/api/v1/journeys",
        json={"route_id": route["id"]},
        headers={"Authorization": f"Bearer {tester_a_again['token']}"},
    )
    assert resumed.get_json()["data"]["id"] == journey["id"]


def test_private_endpoint_matrix_hides_other_user_progress(client):
    route = client.get("/api/v1/routes/nantou-time-layers").get_json()["data"]
    fragment = route["audio_tour"]["fragments"][0]
    tester_a = client.post("/api/v1/auth/test-login", json={"alias": "tester-a"}).get_json()["data"]
    tester_b = client.post("/api/v1/auth/test-login", json={"alias": "tester-b"}).get_json()["data"]
    headers_a = {"Authorization": f"Bearer {tester_a['token']}"}
    headers_b = {"Authorization": f"Bearer {tester_b['token']}"}
    journey = client.post(
        "/api/v1/journeys", json={"route_id": route["id"]}, headers=headers_a
    ).get_json()["data"]
    trigger_key = "owner-private-trigger-key"
    owner_trigger = client.post(
        f"/api/v1/journeys/{journey['id']}/fragments/{fragment['id']}/triggers",
        json={"method": "demo", "idempotency_key": trigger_key},
        headers=headers_a,
    )
    assert owner_trigger.status_code == 200

    checks = (
        client.get(f"/api/v1/journeys/{journey['id']}", headers=headers_b),
        client.get(f"/api/v1/journeys/{journey['id']}/ledger", headers=headers_b),
        client.get(f"/api/v1/journeys/{journey['id']}/recap", headers=headers_b),
        client.post(f"/api/v1/journeys/{journey['id']}/active-tour", headers=headers_b),
        client.post(
            f"/api/v1/journeys/{journey['id']}/fragments/{fragment['id']}/triggers",
            json={"method": "demo", "idempotency_key": trigger_key},
            headers=headers_b,
        ),
        client.post(
            f"/api/v1/journeys/{journey['id']}/reconstruction",
            json={"relationships": []},
            headers=headers_b,
        ),
    )
    assert all(response.status_code == 404 for response in checks)


def test_legacy_guest_can_upgrade_without_moving_progress(app, client):
    guest = client.post("/api/v1/sessions/guest").get_json()["data"]
    guest_headers = {"Authorization": f"Bearer {guest['token']}"}
    route = client.get("/api/v1/routes/nantou-time-layers").get_json()["data"]
    journey = client.post(
        "/api/v1/journeys", json={"route_id": route["id"]}, headers=guest_headers
    ).get_json()["data"]

    upgraded = client.post(
        "/api/v1/auth/upgrade-legacy",
        json={"username": "legacy-owner", "password": "field-test-123"},
        headers=guest_headers,
    )
    assert upgraded.status_code == 200
    upgraded_data = upgraded.get_json()["data"]
    assert upgraded_data["user"]["id"] == guest["user_id"]
    new_headers = {"Authorization": f"Bearer {upgraded_data['token']}"}
    assert client.get(f"/api/v1/journeys/{journey['id']}", headers=new_headers).status_code == 200

    session = app.extensions["database"].session_factory()
    assert session.get(JourneyModel, journey["id"]).user_id == guest["user_id"]
    session.close()


def test_expired_user_token_requires_login(app, client):
    registered = _register(client, "expiring-user")
    codec = JwtTokenCodec(str(app.config["SECRET_KEY"]))
    expired = codec.encode_user(
        registered["user"]["id"], 1, datetime.now(UTC) - timedelta(seconds=1)
    )
    response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {expired}"})
    assert response.status_code == 401


def test_test_login_is_unavailable_when_disabled(tmp_path):
    app = create_app(
        {
            "TESTING": True,
            "DATABASE_URL": f"sqlite:///{tmp_path / 'disabled.db'}",
            "EVIDENCE_ROOT": str(tmp_path / "disabled-evidence"),
            "TEST_AUTH_ENABLED": False,
        }
    )
    app.extensions["database"].create_all()
    session = app.extensions["database"].session_factory()
    seed_database(session)
    session.close()
    response = app.test_client().post("/api/v1/auth/test-login", json={"alias": "tester-a"})
    assert response.status_code == 404


def test_production_rejects_test_auth_configuration(tmp_path):
    try:
        create_app(
            {
                "TESTING": True,
                "ENVIRONMENT": "production",
                "DATABASE_URL": f"sqlite:///{tmp_path / 'production.db'}",
                "EVIDENCE_ROOT": str(tmp_path / "production-evidence"),
                "TEST_AUTH_ENABLED": True,
            }
        )
    except RuntimeError as error:
        assert "TEST_AUTH_ENABLED" in str(error)
    else:
        raise AssertionError("production test authentication must fail closed")
