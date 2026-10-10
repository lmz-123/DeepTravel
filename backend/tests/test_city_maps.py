from datetime import datetime

from sqlalchemy import select

from app.infrastructure.persistence.models import CityMapModel, CityModel, RouteModel


def test_manifest_for_existing_new_and_unknown_city(app, client):
    assert client.get("/api/v1/cities/unknown-city/map").status_code == 404
    assert client.get("/api/v1/cities/shenzhen/map").get_json()["data"]["status"] == "pending"
    db = app.extensions["database"].session_factory()
    city = db.scalar(select(CityModel).where(CityModel.slug == "shenzhen"))
    row = CityMapModel(
        city_id=city.id,
        adcode="440300",
        status="ready",
        object_key="maps/cities/440300/version.geojson",
        version="a" * 64,
        district_count=9,
        attempts=1,
        next_attempt_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(row)
    db.commit()
    response = client.get("/api/v1/cities/shenzhen/map")
    data = response.get_json()["data"]
    assert data["url"].endswith("/maps/cities/440300/version.geojson")
    assert data["district_count"] == 9
    assert data["version"] == "a" * 64
    assert response.headers["Cache-Control"] == "no-store"
    row.status = "failed"
    row.error = "private internal error"
    db.commit()
    data = client.get("/api/v1/cities/shenzhen/map").get_json()["data"]
    assert data["status"] == "ready"  # Keep the last successful resource.
    assert "error" not in data


def test_public_routes_deliver_editorial_map_category(app, client):
    db = app.extensions["database"].session_factory()
    route = db.scalar(select(RouteModel).where(RouteModel.slug == "nantou-time-layers"))
    route.map_category = "streets"
    db.commit()
    routes = client.get("/api/v1/cities/shenzhen/routes").get_json()["data"]["routes"]
    assert next(item for item in routes if item["id"] == route.id)["map_category"] == "streets"
