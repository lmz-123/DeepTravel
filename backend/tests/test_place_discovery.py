from sqlalchemy import select

from app.infrastructure.persistence.models import CityModel, RouteModel, StopModel


def _places(app, count=31):
    with app.extensions["database"].session_factory() as session:
        city = session.scalar(select(CityModel).where(CityModel.slug == "shenzhen"))
        for i in range(count):
            route = RouteModel(
                id=f"page-{i:03}",
                city_id=city.id,
                slug=f"page-{i}",
                title=f"测试景点{i}",
                subtitle="海边散步" if i % 2 else "城市街巷",
                description="很长的景点正文" * 1000,
                duration_minutes=60,
                distance_km=1,
                difficulty="轻松",
                theme="定位音频",
                map_category="coast" if i % 2 else "streets",
                hero_image=f"places/{i}.jpg",
                is_featured=i < 2,
                content_status="published",
                travel_preparation={
                    "enabled": True,
                    "admission": "ticket",
                    "tickets": [{"description": "票种内容" * 1000}],
                },
            )
            session.add(route)
            session.add(
                StopModel(
                    id=f"point-{i}",
                    route_id=route.id,
                    position=1,
                    title="地点",
                    kicker="",
                    address="",
                    latitude=22 + i * 0.01,
                    longitude=114,
                    arrival_radius_m=100,
                    story_title="",
                    story_body="",
                    image="",
                    insight="",
                )
            )
        session.commit()


def test_real_cursor_pages_filters_and_lightweight_markers(app, client):
    _places(app)
    url = "/api/v1/cities/shenzhen/places"
    first = client.get(url, query_string={"q": "测试景点"}).get_json()["data"]
    assert len(first["items"]) == 12 and first["total"] == 31
    assert first["next_cursor"]
    assert first["categories"] == ["coast", "streets"]
    assert all(len(p["description"]) <= 600 for p in first["items"])
    assert all("audio_tour" not in p and "stops" not in p for p in first["items"])
    assert all("tickets" not in p["travel_preparation"] for p in first["items"])
    seen = {p["id"] for p in first["items"]}
    cursor = first["next_cursor"]
    while cursor:
        page = client.get(url, query_string={"q": "测试景点", "cursor": cursor}).get_json()["data"]
        ids = {p["id"] for p in page["items"]}
        assert not ids & seen
        seen |= ids
        cursor = page["next_cursor"]
    assert len(seen) == 31
    filtered = client.get(url, query_string={"category": "coast", "limit": 20}).get_json()["data"]
    assert filtered["total"] == 15
    assert all(p["map_category"] == "coast" for p in filtered["items"])
    assert (
        client.get(
            url, query_string={"category": "coast", "cursor": first["next_cursor"]}
        ).status_code
        == 422
    )
    assert client.get(url, query_string={"cursor": "invalid"}).status_code == 422
    assert client.get(url, query_string={"q": "%"}).get_json()["data"]["total"] == 0
    markers = client.get(
        "/api/v1/cities/shenzhen/place-markers", query_string={"category": "coast"}
    ).get_json()["data"]
    assert len(markers["items"]) == 15
    assert all(
        set(p) == {"id", "slug", "title", "map_category", "district", "center"}
        for p in markers["items"]
    )
    detail = client.get("/api/v1/places/page-3").get_json()["data"]
    assert detail["title"] == "测试景点3" and detail["description"]


def test_nearest_stable_pages_and_unpublished_exclusion(app, client):
    _places(app, 5)
    with app.extensions["database"].session_factory() as session:
        session.get(RouteModel, "page-004").content_status = "draft"
        session.commit()
    url = "/api/v1/cities/shenzhen/places"
    params = {"q": "测试景点", "order": "nearest", "latitude": 22.035, "longitude": 114, "limit": 2}
    first = client.get(url, query_string=params).get_json()["data"]
    assert [r["id"] for r in first["items"]] == ["page-003", "page-002"]
    second = client.get(url, query_string={**params, "cursor": first["next_cursor"]}).get_json()[
        "data"
    ]
    assert [r["id"] for r in second["items"]] == ["page-001", "page-000"]
    assert second["next_cursor"] is None
    assert client.get("/api/v1/places/page-4").status_code == 404
    for params in [
        {"order": "nearest"},
        {"limit": "x"},
        {"limit": 0},
        {"latitude": "nan", "longitude": 1},
        {"category": "audio"},
    ]:
        assert client.get(url, query_string=params).status_code == 422


def test_directory_keeps_narration_capability_without_downloading_manifest(app, client):
    with app.extensions["database"].session_factory() as session:
        route = session.scalar(select(RouteModel).where(RouteModel.slug == "nantou-time-layers"))
        route.content_status = "published"
        session.commit()
    data = client.get("/api/v1/cities/shenzhen/routes?summary=1").get_json()["data"]["routes"]
    route = next(p for p in data if p["slug"] == "nantou-time-layers")
    assert route["supports_companion"] is True
    assert route["stop_count"] > 0 and route["center"]
    assert "audio_tour" not in route and "pretrip" not in route


def test_thumbnail_urls_resize_owned_images_without_rewriting_external_urls(app, client):
    _places(app, 1)
    app.config["OSS_PUBLIC_BASE_URL"] = "https://our-bucket.oss-cn-hangzhou.aliyuncs.com"
    data = client.get("/api/v1/places/page-0").get_json()["data"]
    assert "w_240" in data["image_variants"]["thumbnail"]
    assert "w_960" in data["image_variants"]["preview"]
    assert "x-oss-process" not in data["hero_image"]
    with app.extensions["database"].session_factory() as session:
        session.get(RouteModel, "page-000").hero_image = "https://external.example/image.jpg"
        session.commit()
    data = client.get("/api/v1/places/page-0").get_json()["data"]
    assert data["image_variants"]["thumbnail"] == "https://external.example/image.jpg"
