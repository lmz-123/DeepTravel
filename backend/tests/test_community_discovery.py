from datetime import UTC, datetime, timedelta
from uuid import uuid4

from sqlalchemy import select

from app.infrastructure.persistence.models import RouteModel
from tests.test_community import _image, _login


def _publish_place(app, client, headers):
    route = client.get("/api/v1/routes/nantou-time-layers").get_json()["data"]
    with app.extensions["database"].session_factory() as session:
        model = session.scalar(select(RouteModel).where(RouteModel.id == route["id"]))
        model.content_status = "published"
        session.commit()
    places = client.get("/api/v1/community-places", headers=headers).get_json()["data"]
    return next(p for p in places if p["route_id"] == route["id"])


def _share(client, headers, place, **fields):
    return client.post(
        f"/api/v1/community-places/{place['fragment_id']}/posts",
        headers=headers,
        data={
            "body": "走过这里，留下见闻。",
            "idempotency_key": str(uuid4()),
            "visited_on": "2026-01-01",
            **fields,
        },
        content_type="multipart/form-data",
    )


def test_global_feed_place_handoff_comments_saves_without_journey(app, client):
    _, author = _login(client, "tester-a")
    _, viewer = _login(client, "tester-b")
    assert client.get("/api/v1/community-posts").status_code == 401
    assert client.get("/api/v1/community-places").status_code == 401
    place = _publish_place(app, client, author)
    created = _share(client, author, place, photos=(_image(), "coast.jpg"))
    assert created.status_code == 201, created.get_json()
    post = created.get_json()["data"]
    assert post["place"] == place
    assert post["visited_on"] == "2026-01-01"
    assert len(post["media"]) == 1
    feed = client.get("/api/v1/community-posts", headers=viewer).get_json()["data"]
    assert [p["id"] for p in feed["items"]] == [post["id"]]
    assert (
        client.get("/api/v1/community-posts?city=unknown", headers=viewer).get_json()["data"][
            "items"
        ]
        == []
    )
    url = f"/api/v1/community-posts/{post['id']}"
    assert client.get(url, headers=viewer).status_code == 200
    assert client.get(post["media"][0]["url"], headers=viewer).status_code == 200
    comment = client.post(
        url + "/comments",
        headers=viewer,
        json={"body": "我也想去", "idempotency_key": "comment-on-public"},
    )
    assert comment.status_code == 201
    for _ in range(2):
        assert client.put(url + "/saved", headers=viewer).get_json()["data"]["viewer_has_saved"]
    assert client.get(url, headers=viewer).get_json()["data"]["viewer_has_saved"]
    assert not client.get(url, headers=author).get_json()["data"]["viewer_has_saved"]
    assert not client.delete(url + "/saved", headers=viewer).get_json()["data"]["viewer_has_saved"]


def test_global_feed_cursor_and_publish_idempotency(app, client):
    _, headers = _login(client, "tester-a")
    place = _publish_place(app, client, headers)
    first = _share(client, headers, place, idempotency_key="repeat").get_json()["data"]
    duplicate = _share(client, headers, place, idempotency_key="repeat").get_json()["data"]
    assert first["id"] == duplicate["id"]
    second = _share(client, headers, place).get_json()["data"]
    page = client.get("/api/v1/community-posts?limit=1", headers=headers).get_json()["data"]
    assert page["next_cursor"]
    next_page = client.get(
        "/api/v1/community-posts",
        headers=headers,
        query_string={"limit": 1, "cursor": page["next_cursor"]},
    ).get_json()["data"]
    assert {page["items"][0]["id"], next_page["items"][0]["id"]} == {first["id"], second["id"]}
    assert next_page["next_cursor"] is None
    invalid = client.get(
        "/api/v1/community-posts",
        headers=headers,
        query_string={"city": place["city_slug"], "cursor": page["next_cursor"]},
    )
    assert invalid.status_code == 422


def test_unpublished_places_and_invalid_visit_dates_rejected(app, client):
    _, headers = _login(client, "tester-a")
    place = _publish_place(app, client, headers)
    for value in ("not-a-date", (datetime.now(UTC) + timedelta(days=2)).date().isoformat()):
        assert _share(client, headers, place, visited_on=value).status_code == 422
    _share(client, headers, place)
    with app.extensions["database"].session_factory() as session:
        route = session.get(RouteModel, place["route_id"])
        route.content_status = "draft"
        session.commit()
    assert _share(client, headers, place).status_code == 404
    assert client.get("/api/v1/community-posts", headers=headers).get_json()["data"]["items"] == []
    assert place not in client.get("/api/v1/community-places", headers=headers).get_json()["data"]


def test_live_filters_nearest_pagination_and_saved_scope(app, client):
    _, author = _login(client, "tester-a")
    _, viewer = _login(client, "tester-b")
    place = _publish_place(app, client, author)
    first = _share(client, author, place, category="viewpoint").get_json()["data"]
    second = _share(client, author, place, category="viewpoint").get_json()["data"]
    _share(client, author, place, category="experience")
    assert first["category"] == "viewpoint"
    assert place["latitude"] is not None
    query = dict(
        category="viewpoint",
        latitude=place["latitude"],
        longitude=place["longitude"],
        radius_km=5,
        order="nearest",
        limit=1,
    )
    response = client.get("/api/v1/community-posts", headers=viewer, query_string=query)
    assert response.status_code == 200, response.get_json()
    page = response.get_json()["data"]
    assert page["total"] == 2
    other = client.get(
        "/api/v1/community-posts",
        headers=viewer,
        query_string={**query, "cursor": page["next_cursor"]},
    ).get_json()["data"]
    assert {page["items"][0]["id"], other["items"][0]["id"]} == {first["id"], second["id"]}
    assert other["next_cursor"] is None
    for changes in ({"category": "experience"}, {"latitude": 0}, {"order": "latest"}):
        assert (
            client.get(
                "/api/v1/community-posts",
                headers=viewer,
                query_string={**query, **changes, "cursor": page["next_cursor"]},
            ).status_code
            == 422
        )
    far = client.get(
        "/api/v1/community-posts",
        headers=viewer,
        query_string={**query, "latitude": 0, "longitude": 0},
    ).get_json()["data"]
    assert far["items"] == []
    for invalid in (
        {"order": "nearest"},
        {"latitude": "nan", "longitude": 1},
        {"radius_km": -1},
        {"category": "unknown"},
    ):
        assert (
            client.get("/api/v1/community-posts", headers=viewer, query_string=invalid).status_code
            == 422
        )
    client.put(f"/api/v1/community-posts/{first['id']}/saved", headers=viewer)
    saved = client.get("/api/v1/community-posts?saved=true", headers=viewer).get_json()["data"]
    assert [p["id"] for p in saved["items"]] == [first["id"]]
    assert (
        client.get("/api/v1/community-posts?saved=true", headers=author).get_json()["data"]["items"]
        == []
    )
    client.delete(f"/api/v1/community-posts/{first['id']}/saved", headers=viewer)
    assert (
        client.get("/api/v1/community-posts?saved=true", headers=viewer).get_json()["data"]["items"]
        == []
    )


def test_nine_photos_keep_order_and_route_favorites_work(app, client):
    _, headers = _login(client, "tester-a")
    place = _publish_place(app, client, headers)
    response = _share(
        client,
        headers,
        place,
        category="experience",
        photos=[(_image(), f"photo-{i}.jpg") for i in range(9)],
    )
    assert response.status_code == 201, response.get_json()
    post = response.get_json()["data"]
    assert [m["position"] for m in post["media"]] == list(range(9))
    assert (
        _share(
            client, headers, place, photos=[(_image(), f"photo-{i}.jpg") for i in range(10)]
        ).status_code
        == 422
    )
    url = f"/api/v1/favorites/route/{place['route_id']}"
    assert client.put(url, headers=headers).status_code in (200, 201)
    assert client.put(url, headers=headers).status_code in (200, 201)
    favorites = client.get("/api/v1/favorites", headers=headers).get_json()["data"]
    assert len([f for f in favorites if f["target_id"] == place["route_id"]]) == 1
    assert client.delete(url, headers=headers).status_code in (200, 204)
