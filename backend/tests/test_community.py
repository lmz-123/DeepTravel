from __future__ import annotations

from datetime import UTC, datetime, timedelta
from io import BytesIO
from uuid import uuid4

from PIL import Image
from sqlalchemy import select

from app.infrastructure.persistence.models import (
    CommunityPostModel,
    EvidenceModel,
    JourneyFragmentModel,
    RouteModel,
)


def _image(*, size: tuple[int, int] = (80, 60), color: str = "#9f5b43") -> BytesIO:
    payload = BytesIO()
    Image.new("RGB", size, color).save(payload, format="JPEG", exif=b"Exif\x00\x00private-gps")
    payload.seek(0)
    return payload


def _login(client, alias: str) -> tuple[dict, dict]:
    result = client.post("/api/v1/auth/test-login", json={"alias": alias}).get_json()["data"]
    return result, {"Authorization": f"Bearer {result['token']}"}


def _register(client, username: str) -> tuple[dict, dict]:
    result = client.post(
        "/api/v1/auth/register",
        json={"username": username, "password": "field-test-123"},
    ).get_json()["data"]
    return result, {"Authorization": f"Bearer {result['token']}"}


def _journey(client, headers: dict, *, reveal: bool = True) -> tuple[dict, dict, dict]:
    route = client.get("/api/v1/routes/nantou-time-layers").get_json()["data"]
    journey = client.post(
        "/api/v1/journeys", json={"route_id": route["id"]}, headers=headers
    ).get_json()["data"]
    fragment = route["audio_tour"]["fragments"][0]
    if reveal:
        response = client.post(
            f"/api/v1/journeys/{journey['id']}/fragments/{fragment['id']}/triggers",
            json={"method": "demo", "idempotency_key": str(uuid4())},
            headers=headers,
        )
        assert response.status_code == 200
    return route, journey, fragment


def _create_post(client, headers: dict, journey: dict, fragment: dict, **overrides):
    data = {
        "category": "viewpoint",
        "title": "城墙转角机位",
        "body": "下午四点从榕树旁向东拍，光线会落在砖缝上。",
        "idempotency_key": str(uuid4()),
    }
    data.update(overrides)
    return client.post(
        f"/api/v1/journeys/{journey['id']}/fragments/{fragment['id']}/community-posts",
        data=data,
        headers=headers,
        content_type="multipart/form-data",
    )


def test_policy_requires_auth_and_exposes_only_safe_runtime_contract(client):
    assert client.get("/api/v1/policies/community").status_code == 401
    _, headers = _login(client, "tester-a")
    response = client.get("/api/v1/policies/community", headers=headers)
    assert response.status_code == 200
    policy = response.get_json()["data"]
    assert policy["enabled"] is True
    assert len(policy["categories"]) == 4
    assert policy["max_media"] == 4
    serialized = str(policy).lower()
    assert not any(
        secret in serialized
        for secret in ("object_key", "access_key", "secret_key", "bucket", "threshold")
    )


def test_locked_and_cross_user_journeys_use_not_found_semantics(client):
    _, headers_a = _login(client, "tester-a")
    _, headers_b = _login(client, "tester-b")
    _, journey_a, fragment = _journey(client, headers_a)
    _, journey_b, _ = _journey(client, headers_b, reveal=False)
    url_a = f"/api/v1/journeys/{journey_a['id']}/fragments/{fragment['id']}/community-posts"
    url_b = f"/api/v1/journeys/{journey_b['id']}/fragments/{fragment['id']}/community-posts"
    assert client.get(url_a, headers=headers_b).status_code == 404
    locked = client.get(url_b, headers=headers_b)
    assert locked.status_code == 404
    assert locked.get_json()["error"]["code"] == "community_fragment_locked"


def test_shared_feed_detail_like_comment_pagination_and_privacy(client):
    account_a, headers_a = _login(client, "tester-a")
    account_b, headers_b = _login(client, "tester-b")
    _, journey_a, fragment = _journey(client, headers_a)
    _, journey_b, _ = _journey(client, headers_b)

    created = _create_post(
        client,
        headers_a,
        journey_a,
        fragment,
        photos=(_image(), "view.jpg"),
    )
    assert created.status_code == 201
    post = created.get_json()["data"]
    repeated = _create_post(
        client,
        headers_a,
        journey_a,
        fragment,
        idempotency_key="stable-post-key",
    )
    repeated_again = _create_post(
        client,
        headers_a,
        journey_a,
        fragment,
        idempotency_key="stable-post-key",
    )
    assert repeated.status_code == repeated_again.status_code == 201
    assert repeated.get_json()["data"]["id"] == repeated_again.get_json()["data"]["id"]

    feed_url = f"/api/v1/journeys/{journey_b['id']}/fragments/{fragment['id']}/community-posts"
    first_page = client.get(f"{feed_url}?limit=1", headers=headers_b).get_json()["data"]
    assert len(first_page["items"]) == 1
    assert first_page["next_cursor"]
    second_page = client.get(
        f"{feed_url}?limit=1&cursor={first_page['next_cursor']}", headers=headers_b
    ).get_json()["data"]
    assert len(second_page["items"]) == 1
    assert first_page["items"][0]["id"] != second_page["items"][0]["id"]

    detail = client.get(f"/api/v1/community-posts/{post['id']}", headers=headers_b)
    assert detail.status_code == 200
    payload_text = str(detail.get_json())
    assert account_a["user"]["id"] not in payload_text
    assert account_b["user"]["id"] not in payload_text
    assert "object_key" not in payload_text and "canonical_reference" not in payload_text

    like_url = f"/api/v1/community-posts/{post['id']}/like"
    assert client.put(like_url, headers=headers_b).get_json()["data"]["like_count"] == 1
    assert client.put(like_url, headers=headers_b).get_json()["data"]["like_count"] == 1
    likers = client.get(
        f"/api/v1/community-posts/{post['id']}/likes?limit=1", headers=headers_a
    ).get_json()["data"]
    assert likers["items"] == [{"avatar": "default", "display_name": "tester-b"}]
    assert client.delete(like_url, headers=headers_b).get_json()["data"]["like_count"] == 0

    comment_url = f"/api/v1/community-posts/{post['id']}/comments"
    comment_body = {"body": "这个时间点确实好拍。", "idempotency_key": "comment-key"}
    comment = client.post(comment_url, json=comment_body, headers=headers_b)
    duplicate = client.post(comment_url, json=comment_body, headers=headers_b)
    assert comment.status_code == duplicate.status_code == 201
    assert comment.get_json()["data"]["id"] == duplicate.get_json()["data"]["id"]
    nested = client.post(
        comment_url,
        json={
            "body": "回复",
            "parent_id": comment.get_json()["data"]["id"],
            "idempotency_key": "nested",
        },
        headers=headers_a,
    )
    assert nested.status_code == 201
    reply = nested.get_json()["data"]
    assert reply["root_comment_id"] == comment.get_json()["data"]["id"]
    assert reply["reply_to"]["display_name"] == "tester-b"
    comments = client.get(f"{comment_url}?limit=1", headers=headers_a).get_json()["data"]
    assert len(comments["items"]) == 1
    assert comments["items"][0]["reply_count"] == 1
    assert comments["items"][0]["reply_preview"][0]["id"] == reply["id"]
    reply_to_reply = client.post(
        comment_url,
        json={
            "body": "继续交流",
            "reply_to_comment_id": reply["id"],
            "idempotency_key": "reply-to-reply",
        },
        headers=headers_b,
    )
    assert reply_to_reply.status_code == 201
    assert reply_to_reply.get_json()["data"]["root_comment_id"] == comment.get_json()["data"]["id"]
    replies = client.get(
        f"/api/v1/community-comments/{comment.get_json()['data']['id']}/replies?limit=1",
        headers=headers_a,
    ).get_json()["data"]
    assert len(replies["items"]) == 1
    assert replies["next_cursor"]
    assert account_b["user"]["id"] not in str(comments)
    assert (
        client.delete(
            f"/api/v1/community-comments/{comment.get_json()['data']['id']}", headers=headers_b
        ).status_code
        == 200
    )

    media_id = post["media"][0]["id"]
    assert client.get(f"/api/v1/community-media/{media_id}", headers=headers_b).status_code == 200
    assert client.get(f"/api/v1/community-media/{media_id}").status_code == 401


def test_evidence_copy_is_independent_and_invalid_media_leaves_no_orphans(app, client):
    _, headers = _login(client, "tester-a")
    route, journey, _ = _journey(client, headers, reveal=False)
    fragment = next(
        item for item in route["audio_tour"]["fragments"] if item["interaction_type"] == "photo"
    )
    for item in route["audio_tour"]["fragments"]:
        response = client.post(
            f"/api/v1/journeys/{journey['id']}/fragments/{item['id']}/triggers",
            json={"method": "demo", "idempotency_key": str(uuid4())},
            headers=headers,
        )
        assert response.status_code == 200
        if item["id"] == fragment["id"]:
            break
    base = f"/api/v1/journeys/{journey['id']}/fragments/{fragment['id']}"
    assert (
        client.post(
            f"{base}/playback",
            json={"progress": 1.0, "idempotency_key": str(uuid4())},
            headers=headers,
        ).status_code
        == 200
    )
    evidence = client.post(
        f"{base}/evidence",
        data={"photo": (_image(), "private.jpg"), "idempotency_key": str(uuid4())},
        headers=headers,
        content_type="multipart/form-data",
    ).get_json()["data"]
    post = _create_post(
        client,
        headers,
        journey,
        fragment,
        evidence_ids=evidence["id"],
    ).get_json()["data"]
    media_id = post["media"][0]["id"]
    assert (
        client.delete(
            f"/api/v1/journeys/{journey['id']}/evidence/{evidence['id']}", headers=headers
        ).status_code
        == 200
    )
    assert client.get(f"/api/v1/community-media/{media_id}", headers=headers).status_code == 200

    database = app.extensions["database"]
    with database.session_factory() as session:
        source = session.get(EvidenceModel, evidence["id"])
        assert source.deleted_at is not None
        source.deleted_at = None
        source.expires_at = datetime.now(UTC) - timedelta(seconds=1)
        session.commit()
    expired_copy = _create_post(
        client,
        headers,
        journey,
        fragment,
        idempotency_key="expired-copy",
        evidence_ids=evidence["id"],
    )
    assert expired_copy.status_code == 404

    invalid = _create_post(
        client,
        headers,
        journey,
        fragment,
        idempotency_key="invalid-media",
        photos=(BytesIO(b"not-an-image"), "bad.jpg"),
    )
    assert invalid.status_code == 422
    with database.session_factory() as session:
        assert (
            session.scalar(
                select(CommunityPostModel).where(
                    CommunityPostModel.idempotency_key == "invalid-media"
                )
            )
            is None
        )


def test_soft_delete_reporting_hold_completed_and_archived_access(app, client):
    _, headers_a = _login(client, "tester-a")
    _, headers_b = _login(client, "tester-b")
    _, headers_c = _register(client, "community-third")
    guest = client.post("/api/v1/sessions/guest").get_json()["data"]
    headers_d = {"Authorization": f"Bearer {guest['token']}"}
    _, journey_a, fragment = _journey(client, headers_a)
    _, journey_b, _ = _journey(client, headers_b)
    _, journey_c, _ = _journey(client, headers_c)
    _, journey_d, _ = _journey(client, headers_d)
    post = _create_post(client, headers_a, journey_a, fragment).get_json()["data"]

    report_url = f"/api/v1/community-posts/{post['id']}/reports"
    for headers in (headers_b, headers_c):
        assert (
            client.post(report_url, json={"reason": "misinformation"}, headers=headers).status_code
            == 201
        )
    assert client.get(f"/api/v1/community-posts/{post['id']}", headers=headers_b).status_code == 404
    assert client.get(f"/api/v1/community-posts/{post['id']}", headers=headers_a).status_code == 200
    assert (
        client.post(report_url, json={"reason": "misinformation"}, headers=headers_d).status_code
        == 201
    )
    assert client.get(f"/api/v1/community-posts/{post['id']}", headers=headers_a).status_code == 404

    keep = _create_post(
        client,
        headers_a,
        journey_a,
        fragment,
        idempotency_key="delete-me",
        photos=(_image(), "delete.jpg"),
    ).get_json()["data"]
    assert (
        client.delete(f"/api/v1/community-posts/{keep['id']}", headers=headers_b).status_code == 403
    )
    assert (
        client.delete(f"/api/v1/community-posts/{keep['id']}", headers=headers_a).status_code == 200
    )
    assert client.get(f"/api/v1/community-posts/{keep['id']}", headers=headers_a).status_code == 404

    database = app.extensions["database"]
    with database.session_factory() as session:
        state = session.scalar(
            select(JourneyFragmentModel).where(
                JourneyFragmentModel.journey_id == journey_a["id"],
                JourneyFragmentModel.fragment_id == fragment["id"],
            )
        )
        state.state = "collected"
        route = session.get(RouteModel, journey_a["route_id"])
        route.content_status = "archived"
        session.commit()
    feed = client.get(
        f"/api/v1/journeys/{journey_a['id']}/fragments/{fragment['id']}/community-posts",
        headers=headers_a,
    )
    assert feed.status_code == 200


def test_disabled_policy_blocks_community_operations(app, client):
    _, headers = _login(client, "tester-a")
    _, journey, fragment = _journey(client, headers)
    app.extensions["services"]["community"].enabled = False
    policy = client.get("/api/v1/policies/community", headers=headers)
    assert policy.get_json()["data"]["enabled"] is False
    response = client.get(
        f"/api/v1/journeys/{journey['id']}/fragments/{fragment['id']}/community-posts",
        headers=headers,
    )
    assert response.status_code == 503
    assert response.get_json()["error"]["code"] == "community_disabled"


def test_invalid_scope_bound_cursor_and_query_values_are_rejected(client):
    _, headers = _login(client, "tester-a")
    _, journey, fragment = _journey(client, headers)
    base = f"/api/v1/journeys/{journey['id']}/fragments/{fragment['id']}/community-posts"
    _create_post(client, headers, journey, fragment)
    page = client.get(f"{base}?limit=1", headers=headers).get_json()["data"]
    cursor = page["next_cursor"]
    assert client.get(f"{base}?cursor=tampered", headers=headers).status_code == 422
    assert client.get(f"{base}?category=unknown", headers=headers).status_code == 422
    assert client.get(f"{base}?limit=zero", headers=headers).status_code == 422
    if cursor:
        assert (
            client.get(f"{base}?category=experience&cursor={cursor}", headers=headers).status_code
            == 422
        )
