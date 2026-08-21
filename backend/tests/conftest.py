from __future__ import annotations

import pytest

from app import create_app
from app.infrastructure.persistence.seed import seed_database


@pytest.fixture()
def app(tmp_path):
    database_path = tmp_path / "test.db"
    app = create_app(
        {
            "TESTING": True,
            "DATABASE_URL": f"sqlite:///{database_path}",
            "SECRET_KEY": "test-secret",
            "ALLOW_DEMO_ARRIVAL": True,
            "EVIDENCE_ROOT": str(tmp_path / "private-evidence"),
        }
    )
    database = app.extensions["database"]
    database.create_all()
    session = database.session_factory()
    seed_database(session)
    session.close()
    yield app
    database.remove_session()
    database.engine.dispose()


@pytest.fixture()
def client(app):
    return app.test_client()


@pytest.fixture()
def guest_headers(client):
    response = client.post("/api/v1/sessions/guest")
    token = response.get_json()["data"]["token"]
    return {"Authorization": f"Bearer {token}"}
