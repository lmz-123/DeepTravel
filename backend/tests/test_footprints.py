from __future__ import annotations

from datetime import UTC, datetime
from io import BytesIO
from uuid import uuid4

from PIL import Image
from sqlalchemy.orm import Session

from app.infrastructure.persistence.models import (
    FootprintEntryModel,
    FootprintPhotoModel,
    JourneyModel,
    RouteModel,
    StoryCatalogItemModel,
)


def _start_and_trigger(client, headers, fragment_index: int = 0):
    route = client.get("/api/v1/routes/nantou-time-layers").get_json()["data"]
    journey = client.post(
        "/api/v1/journeys", json={"route_id": route["id"]}, headers=headers
    ).get_json()["data"]
    fragment = route["audio_tour"]["fragments"][fragment_index]
    response = client.post(
        f"/api/v1/journeys/{journey['id']}/fragments/{fragment['id']}/triggers",
        json={
            "method": "location",
            "latitude": fragment["trigger_region"]["latitude"],
            "longitude": fragment["trigger_region"]["longitude"],
            "accuracy_m": 10,
            "idempotency_key": str(uuid4()),
        },
        headers=headers,
    )
    assert response.status_code == 200
    return journey, fragment


def _image() -> BytesIO:
    payload = BytesIO()
    Image.new("RGB", (80, 60), "#8d5a42").save(payload, format="JPEG")
    payload.seek(0)
    return payload


def _assert_no_voice_fields(value):
    forbidden = {
        "audio_url",
        "audio_path",
        "playback_progress",
        "voice_profile",
        "voice_provider",
        "voice_version",
        "latitude",
        "longitude",
    }
    if isinstance(value, dict):
        assert forbidden.isdisjoint(value)
        for child in value.values():
            _assert_no_voice_fields(child)
    elif isinstance(value, list):
        for child in value:
            _assert_no_voice_fields(child)


def test_trigger_creates_idempotent_private_footprint(client, guest_headers):
    journey, fragment = _start_and_trigger(client, guest_headers)
    listing = client.get("/api/v1/footprints", headers=guest_headers)
    assert listing.status_code == 200
    payload = listing.get_json()["data"]
    assert payload["total"] == 1
    item = payload["items"][0]
    assert item["journey_id"] == journey["id"]
    assert item["source"] == {"kind": "story_fragment", "id": fragment["id"]}
    assert item["journey_state"] == "partial"
    assert item["organization_state"] == "draft"
    assert item["jian_di_narrative"]["editorial_summary"]
    assert item["jian_di_narrative"]["summary_options"]
    _assert_no_voice_fields(item)

    repeated = client.get("/api/v1/footprints", headers=guest_headers).get_json()["data"]
    assert repeated["total"] == 1
    resume = client.get("/api/v1/footprints/resume-candidate", headers=guest_headers).get_json()[
        "data"
    ]
    assert resume["id"] == item["id"]


def test_footprint_edit_filters_and_private_photo(app, client, guest_headers, user_headers):
    _start_and_trigger(client, guest_headers)
    item = client.get("/api/v1/footprints", headers=guest_headers).get_json()["data"]["items"][0]
    option = item["jian_di_narrative"]["summary_options"][0]
    updated = client.patch(
        f"/api/v1/footprints/{item['id']}",
        json={
            "selected_summary_id": option["id"],
            "user_observation": "我留意到墙面新旧砖缝的差别。",
            "user_sentence": "旧城并没有停在过去。",
        },
        headers=guest_headers,
    )
    assert updated.status_code == 200
    edited = updated.get_json()["data"]
    assert edited["organization_state"] == "organized"
    assert edited["what_i_left"]["selected_summary_text"] == option["text"]
    assert edited["what_i_saw"]["observation"].startswith("我留意到")

    by_city = client.get(
        "/api/v1/footprints?city_slug=shenzhen&journey_state=partial",
        headers=guest_headers,
    ).get_json()["data"]
    assert by_city["total"] == 1
    theme = edited["themes"][0]
    by_theme = client.get(
        "/api/v1/footprints", query_string={"theme": theme}, headers=guest_headers
    ).get_json()["data"]
    assert by_theme["total"] == 1
    created_month = edited["created_at"][:7]
    combined = client.get(
        "/api/v1/footprints",
        query_string={
            "city_slug": "shenzhen",
            "theme": theme,
            "month": created_month,
            "organization_state": "organized",
        },
        headers=guest_headers,
    ).get_json()["data"]
    assert combined["total"] == 1
    assert combined["facets"]["months"][0]["key"] == created_month

    upload = client.post(
        f"/api/v1/footprints/{item['id']}/photo",
        data={
            "photo": (_image(), "memory.jpg"),
            "idempotency_key": "footprint-photo-1",
        },
        headers=guest_headers,
        content_type="multipart/form-data",
    )
    assert upload.status_code == 201
    assert upload.get_json()["data"]["private"] is True
    first_photo_id = upload.get_json()["data"]["id"]
    database = app.extensions["database"]
    with database.session_factory() as session:
        first_object_key = session.query(FootprintPhotoModel).one().object_key
    repeated_upload = client.post(
        f"/api/v1/footprints/{item['id']}/photo",
        data={
            "photo": (_image(), "ignored-retry.jpg"),
            "idempotency_key": "footprint-photo-1",
        },
        headers=guest_headers,
        content_type="multipart/form-data",
    )
    assert repeated_upload.get_json()["data"]["id"] == first_photo_id
    replacement = client.post(
        f"/api/v1/footprints/{item['id']}/photo",
        data={
            "photo": (_image(), "replacement.jpg"),
            "idempotency_key": "footprint-photo-2",
        },
        headers=guest_headers,
        content_type="multipart/form-data",
    )
    assert replacement.status_code == 201
    storage = app.extensions["services"]["footprints"].photo_storage.object_storage
    assert storage.exists(first_object_key) is False
    own = client.get(f"/api/v1/footprints/{item['id']}/photo", headers=guest_headers)
    assert own.status_code == 200
    assert own.content_type == "image/jpeg"
    other = client.get(f"/api/v1/footprints/{item['id']}/photo", headers=user_headers)
    assert other.status_code == 404
    assert client.delete(
        f"/api/v1/footprints/{item['id']}/photo", headers=guest_headers
    ).get_json()["data"] == {"deleted": True}
    assert client.delete(
        f"/api/v1/footprints/{item['id']}/photo", headers=guest_headers
    ).get_json()["data"] == {"deleted": False}


def test_footprint_validation_and_defer(client, guest_headers):
    _start_and_trigger(client, guest_headers)
    item = client.get("/api/v1/footprints", headers=guest_headers).get_json()["data"]["items"][0]
    invalid = client.patch(
        f"/api/v1/footprints/{item['id']}",
        json={"user_sentence": "长" * 161},
        headers=guest_headers,
    )
    assert invalid.status_code == 422
    deferred = client.patch(
        f"/api/v1/footprints/{item['id']}",
        json={"user_sentence": "稍后还想补充", "defer_organization": True},
        headers=guest_headers,
    )
    assert deferred.get_json()["data"]["organization_state"] == "draft"


def test_footprint_policy_owner_isolation_clearing_and_stale_choice(
    client, guest_headers, user_headers
):
    _start_and_trigger(client, guest_headers)
    item = client.get("/api/v1/footprints", headers=guest_headers).get_json()["data"]["items"][0]
    footprint_id = item["id"]

    policy = client.get("/api/v1/policies/footprints", headers=guest_headers)
    assert policy.status_code == 200
    assert policy.get_json()["data"]["observation_max_length"] == 280
    assert "bucket" not in policy.get_data(as_text=True)
    assert "object" not in policy.get_data(as_text=True)
    assert client.get("/api/v1/policies/footprints").status_code == 401
    assert client.get(f"/api/v1/footprints/{footprint_id}", headers=user_headers).status_code == 404
    assert (
        client.patch(
            f"/api/v1/footprints/{footprint_id}",
            json={"selected_summary_id": "removed-option"},
            headers=guest_headers,
        ).status_code
        == 422
    )

    option_id = item["jian_di_narrative"]["summary_options"][0]["id"]
    saved = client.patch(
        f"/api/v1/footprints/{footprint_id}",
        json={
            "selected_summary_id": option_id,
            "user_observation": "先保存",
            "user_sentence": "稍后清空",
        },
        headers=guest_headers,
    )
    assert saved.status_code == 200
    cleared = client.patch(
        f"/api/v1/footprints/{footprint_id}",
        json={
            "selected_summary_id": None,
            "user_observation": "",
            "user_sentence": None,
        },
        headers=guest_headers,
    ).get_json()["data"]
    assert cleared["what_i_saw"]["observation"] is None
    assert cleared["what_i_left"]["selected_summary_id"] is None
    assert cleared["what_i_left"]["sentence"] is None
    assert cleared["organization_state"] == "draft"

    empty = client.get(
        "/api/v1/footprints",
        query_string={"theme": "不存在的任意主题"},
        headers=guest_headers,
    ).get_json()["data"]
    assert empty["items"] == []
    assert empty["total"] == 0


def test_resume_candidate_is_account_scoped(client, guest_headers, user_headers):
    _start_and_trigger(client, guest_headers)
    _start_and_trigger(client, user_headers, fragment_index=3)
    guest = client.get("/api/v1/footprints/resume-candidate", headers=guest_headers).get_json()[
        "data"
    ]
    user = client.get("/api/v1/footprints/resume-candidate", headers=user_headers).get_json()[
        "data"
    ]
    assert guest["id"] != user["id"]
    assert guest["source"]["id"] != user["source"]["id"]
    option_id = guest["jian_di_narrative"]["summary_options"][0]["id"]
    assert (
        client.patch(
            f"/api/v1/footprints/{guest['id']}",
            json={"selected_summary_id": option_id},
            headers=guest_headers,
        ).get_json()["data"]["organization_state"]
        == "organized"
    )
    # An organized record from an incomplete journey is still an eligible resume card.
    assert (
        client.get("/api/v1/footprints/resume-candidate", headers=guest_headers).get_json()["data"][
            "id"
        ]
        == guest["id"]
    )


def test_related_content_is_published_same_city_and_voice_free(app, client, guest_headers):
    _start_and_trigger(client, guest_headers)
    item = client.get("/api/v1/footprints", headers=guest_headers).get_json()["data"]["items"][0]
    now = datetime.now(UTC)
    database = app.extensions["database"]
    with database.session_factory() as session:
        for suffix, status, themes in (
            ("published", "published", item["themes"]),
            ("draft", "draft", ["其他主题"]),
        ):
            session.add(
                StoryCatalogItemModel(
                    id=f"footprint-related-{suffix}",
                    city_id=item["city"]["id"],
                    source_kind="footprint_test",
                    source_id=f"source-{suffix}",
                    canonical_revision=suffix,
                    title=f"相关内容-{suffix}",
                    summary="只返回可读的城市文字。",
                    cover_image="",
                    district=None,
                    themes_json=themes,
                    point_ids_json=[],
                    related_stories_json=[],
                    content_type="city_small_thing",
                    place_context="同一座城市",
                    observable_detail="一处可以看到的细节",
                    attention_hint=None,
                    sources_json=[],
                    fact_status="documented",
                    review_status="reviewed" if status == "published" else "draft",
                    status=status,
                    version=1,
                    reviewed_at=now if status == "published" else None,
                    published_at=now if status == "published" else None,
                    created_at=now,
                    updated_at=now,
                )
            )
        session.commit()

    related = client.get(f"/api/v1/footprints/{item['id']}/related-content", headers=guest_headers)
    assert related.status_code == 200
    data = related.get_json()["data"]
    assert [entry["id"] for entry in data] == ["footprint-related-published"]
    _assert_no_voice_fields(data)


def test_footprint_projection_failure_never_blocks_trigger_or_ledger(
    app, client, guest_headers, monkeypatch
):
    service = app.extensions["services"]["footprints"]
    original = service.reconcile_journey

    def unavailable(*_args, **_kwargs):
        raise RuntimeError("projection temporarily unavailable")

    monkeypatch.setattr(service, "reconcile_journey", unavailable)
    journey, fragment = _start_and_trigger(client, guest_headers, fragment_index=3)
    monkeypatch.setattr(service, "reconcile_journey", original)

    ledger = client.get(f"/api/v1/journeys/{journey['id']}/ledger", headers=guest_headers)
    assert ledger.status_code == 200
    entries = ledger.get_json()["data"]["entries"]
    assert next(entry for entry in entries if entry["id"] == fragment["id"])["state"] != "locked"
    footprints = client.get("/api/v1/footprints", headers=guest_headers).get_json()["data"]
    assert footprints["total"] == 1


def test_private_footprint_text_is_not_written_to_routine_logs(client, guest_headers, caplog):
    _start_and_trigger(client, guest_headers)
    item = client.get("/api/v1/footprints", headers=guest_headers).get_json()["data"]["items"][0]
    secret = "只属于我的现场观察-不可进入日志"
    response = client.patch(
        f"/api/v1/footprints/{item['id']}",
        json={"user_observation": secret},
        headers=guest_headers,
    )
    assert response.status_code == 200
    assert secret not in caplog.text


def test_footprint_cursor_is_stable_and_invalid_filters_are_rejected(client, guest_headers):
    _start_and_trigger(client, guest_headers)
    _start_and_trigger(client, guest_headers, fragment_index=3)
    first = client.get("/api/v1/footprints?limit=1&order=recent", headers=guest_headers).get_json()[
        "data"
    ]
    assert len(first["items"]) == 1
    assert first["next_cursor"]
    second = client.get(
        "/api/v1/footprints",
        query_string={"limit": 1, "order": "recent", "cursor": first["next_cursor"]},
        headers=guest_headers,
    ).get_json()["data"]
    assert len(second["items"]) == 1
    assert second["items"][0]["id"] != first["items"][0]["id"]
    assert second["next_cursor"] is None

    assert client.get("/api/v1/footprints?month=2026-99", headers=guest_headers).status_code == 422
    assert (
        client.get(
            "/api/v1/footprints?organization_state=unknown", headers=guest_headers
        ).status_code
        == 422
    )


def test_invalid_or_spoofed_footprint_photo_is_rejected(client, guest_headers):
    _start_and_trigger(client, guest_headers)
    item = client.get("/api/v1/footprints", headers=guest_headers).get_json()["data"]["items"][0]
    response = client.post(
        f"/api/v1/footprints/{item['id']}/photo",
        data={
            "photo": (BytesIO(b"not-an-image"), "fake.jpg", "image/jpeg"),
            "idempotency_key": "invalid-image",
        },
        headers=guest_headers,
        content_type="multipart/form-data",
    )
    assert response.status_code == 422
    assert response.get_json()["error"]["code"] == "evidence_invalid"


def test_staged_footprint_photo_is_removed_when_database_commit_fails(
    app, client, guest_headers, monkeypatch
):
    _start_and_trigger(client, guest_headers)
    item = client.get("/api/v1/footprints", headers=guest_headers).get_json()["data"]["items"][0]
    storage = app.extensions["services"]["footprints"].photo_storage.object_storage
    before = set(storage.root.rglob("*"))

    def fail_commit(_session):
        raise RuntimeError("database unavailable")

    monkeypatch.setattr(Session, "commit", fail_commit)
    response = client.post(
        f"/api/v1/footprints/{item['id']}/photo",
        data={
            "photo": (_image(), "rollback.jpg"),
            "idempotency_key": "rollback-photo",
        },
        headers=guest_headers,
        content_type="multipart/form-data",
    )
    assert response.status_code == 500
    after = set(storage.root.rglob("*"))
    assert {path for path in after - before if path.is_file()} == set()


def test_backfill_restores_revealed_story_and_copies_one_durable_photo(
    app, client, guest_headers, monkeypatch
):
    journey, fragment = _start_and_trigger(client, guest_headers)
    playback = client.post(
        f"/api/v1/journeys/{journey['id']}/fragments/{fragment['id']}/playback",
        json={"progress": 0.95, "idempotency_key": str(uuid4())},
        headers=guest_headers,
    )
    assert playback.status_code == 200
    evidence = client.post(
        f"/api/v1/journeys/{journey['id']}/fragments/{fragment['id']}/evidence",
        data={
            "photo": (_image(), "field.jpg"),
            "idempotency_key": str(uuid4()),
        },
        headers=guest_headers,
        content_type="multipart/form-data",
    )
    assert evidence.status_code == 201

    database = app.extensions["database"]
    with database.session_factory() as session:
        session.query(FootprintEntryModel).delete()
        session.commit()

    dry_run = app.extensions["services"]["footprints"].backfill(dry_run=True)
    assert dry_run == {
        "created": 1,
        "photos_copied": 0,
        "failures": [],
        "dry_run": True,
    }
    with database.session_factory() as session:
        assert session.query(FootprintEntryModel).count() == 0

    service = app.extensions["services"]["footprints"]
    original_open = service.photo_storage.open

    def unavailable(_object_key):
        raise OSError("private storage temporarily unavailable")

    monkeypatch.setattr(service.photo_storage, "open", unavailable)
    failed_report = service.backfill()
    assert failed_report["created"] == 1
    assert failed_report["photos_copied"] == 0
    assert failed_report["failures"][0]["code"] == "photo_copy_failed"
    assert "private storage" not in str(failed_report)

    monkeypatch.setattr(service.photo_storage, "open", original_open)
    report = service.backfill()
    assert report == {
        "created": 0,
        "photos_copied": 1,
        "failures": [],
        "dry_run": False,
    }
    item = client.get("/api/v1/footprints", headers=guest_headers).get_json()["data"]["items"][0]
    assert item["what_i_saw"]["photo"]["private"] is True


def test_backfill_handles_archived_partial_multi_owner_and_no_photo(
    app, client, guest_headers, user_headers
):
    guest_journey, _ = _start_and_trigger(client, guest_headers, fragment_index=3)
    user_journey, _ = _start_and_trigger(client, user_headers)
    stopped = client.delete(
        f"/api/v1/journeys/{guest_journey['id']}/active-tour",
        headers=guest_headers,
    )
    assert stopped.status_code == 200
    assert stopped.get_json()["data"]["status"] == "stopped"

    database = app.extensions["database"]
    with database.session_factory() as session:
        session.get(RouteModel, guest_journey["route_id"]).content_status = "archived"
        session.query(FootprintEntryModel).delete()
        session.commit()

    service = app.extensions["services"]["footprints"]
    report = service.backfill(copy_photos=False)
    assert report["created"] == 2
    assert report["photos_copied"] == 0
    assert service.backfill(copy_photos=False)["created"] == 0
    with database.session_factory() as session:
        rows = session.query(FootprintEntryModel).all()
        assert len(rows) == 2
        assert len({row.user_id for row in rows}) == 2
        assert all(row.photo is None for row in rows)
        assert session.get(JourneyModel, guest_journey["id"]).status == "active"
        assert session.get(JourneyModel, user_journey["id"]).status == "active"
        assert session.get(RouteModel, guest_journey["route_id"]).content_status == "archived"


def test_backfill_creates_semantic_legacy_stop_without_audio_fields(app, client, guest_headers):
    route = client.get("/api/v1/routes/wukang-urban-slices").get_json()["data"]
    journey = client.post(
        "/api/v1/journeys", json={"route_id": route["id"]}, headers=guest_headers
    ).get_json()["data"]
    stop = route["stops"][0]
    assert (
        client.post(
            f"/api/v1/journeys/{journey['id']}/arrivals",
            json={"demo": True},
            headers=guest_headers,
        ).status_code
        == 200
    )
    assert (
        client.post(
            f"/api/v1/journeys/{journey['id']}/answers",
            json={"stop_id": stop["id"], "selected_option": 0},
            headers=guest_headers,
        ).status_code
        == 200
    )

    report = app.extensions["services"]["footprints"].backfill(copy_photos=False)
    assert report["created"] == 1
    item = client.get("/api/v1/footprints", headers=guest_headers).get_json()["data"]["items"][0]
    assert item["source"] == {"kind": "legacy_stop", "id": stop["id"]}
    assert item["jian_di_narrative"]["editorial_summary"] == stop["insight"]
    _assert_no_voice_fields(item)
