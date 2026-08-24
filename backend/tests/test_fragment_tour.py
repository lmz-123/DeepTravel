from __future__ import annotations

import hashlib
import json
from datetime import UTC, datetime, timedelta
from io import BytesIO
from pathlib import Path
from uuid import uuid4

from PIL import Image
from sqlalchemy import select

from app.infrastructure.persistence.models import (
    EvidenceModel,
    FragmentNarrationTrackModel,
    JourneyFragmentModel,
    NarrationVoiceProfileModel,
    PhotoMissionModel,
    RouteModel,
    StoryArcModel,
    StoryFragmentModel,
)


def _start(client, headers):
    route = client.get("/api/v1/routes/nantou-time-layers").get_json()["data"]
    journey = client.post(
        "/api/v1/journeys", json={"route_id": route["id"]}, headers=headers
    ).get_json()["data"]
    return route, journey


def _image() -> BytesIO:
    payload = BytesIO()
    Image.new("RGB", (64, 48), "#b55f3d").save(payload, format="JPEG")
    payload.seek(0)
    return payload


def test_public_fragment_manifest_is_spoiler_safe_and_in_review(client):
    route = client.get("/api/v1/routes/nantou-time-layers").get_json()["data"]
    tour = route["audio_tour"]
    assert tour["central_question"].startswith("为什么深圳")
    assert tour["review_state"] == "in_review"
    assert tour["production_ready"] is False
    assert tour["fragment_count"] == 5
    assert tour["photo_mission_count"] == 3
    assert tour["download_size_bytes"] == 0
    assert "transcript" not in tour["fragments"][0]
    assert tour["fragments"][0]["audio"]["url"].endswith(".m4a")
    assert tour["fragments"][0]["display_theme"] == "定位音频 · 碎片叙事"
    assert tour["fragments"][0]["expected_duration_seconds"] > 0
    audio = client.get("/api/v1/assets/audio/nantou-fragment-1-nantou-2026.08-conversational.3.m4a")
    assert audio.status_code == 404


def test_offline_package_is_hidden_when_published_audio_has_no_checksum(client):
    response = client.get("/api/v1/routes/nantou-time-layers/offline-package")

    assert response.status_code == 404


def test_offline_package_is_complete_versioned_and_canonical(app, client):
    database = app.extensions["database"]
    media_root = Path(app.config["MEDIA_ROOT"])
    with database.session_factory() as session:
        route = session.scalar(select(RouteModel).where(RouteModel.slug == "nantou-time-layers"))
        arc = session.scalar(select(StoryArcModel).where(StoryArcModel.route_id == route.id))
        arc.script_version = "nantou-2026.08-review.1"
        for fragment in arc.fragments:
            path = f"audio/nantou-fragment-{fragment.position}-nantou-2026.08-review.1.m4a"
            fragment.audio_path = path
            fragment.audio_size_bytes = (media_root / path).stat().st_size
            fragment.script_version = arc.script_version
        session.query(FragmentNarrationTrackModel).delete()
        session.commit()

    public_route = client.get("/api/v1/routes/nantou-time-layers").get_json()["data"]
    assert "transcript" not in public_route["audio_tour"]["fragments"][0]

    response = client.get("/api/v1/routes/nantou-time-layers/offline-package")

    assert response.status_code == 200
    package = response.get_json()["data"]
    checksum = package.pop("package_checksum_sha256")
    canonical = json.dumps(
        package,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode()
    assert checksum == hashlib.sha256(canonical).hexdigest()
    assert package["package_version"] == package["route"]["audio_tour"]["script_version"]
    assert package["city"]["slug"] == "shenzhen"
    fragments = package["route"]["audio_tour"]["fragments"]
    assert all(item["transcript"] for item in fragments)
    assert all(item["state"] == "undiscovered" for item in fragments)
    assert all(len(item["audio"]["checksum_sha256"]) == 64 for item in fragments)


def test_public_voice_profiles_require_complete_current_coverage_and_preserve_default(
    app, client, user_headers
):
    database = app.extensions["database"]
    now = datetime.now(UTC)
    with database.session_factory() as session:
        route = session.scalar(select(RouteModel).where(RouteModel.slug == "nantou-time-layers"))
        arc = session.scalar(select(StoryArcModel).where(StoryArcModel.route_id == route.id))
        fragments = list(arc.fragments)

        def profile(identity, order, status="published"):
            item = NarrationVoiceProfileModel(
                id=identity,
                slug=identity,
                display_name=f"讲述 {identity}",
                description=f"{identity} 的公开说明",
                provider="private-provider",
                model="private-model",
                voice_id="private-voice-id",
                emotion="neutral",
                speed=1.0,
                pitch=0,
                preview_media_path=fragments[0].audio_path,
                display_order=order,
                status=status,
                is_default=False,
                created_at=now,
                updated_at=now,
                published_at=now if status == "published" else None,
            )
            session.add(item)
            return item

        complete_early = profile("complete-early", 2)
        complete_late = profile("complete-late", 9)
        missing = profile("missing-track", 3)
        stale = profile("stale-track", 4)
        draft = profile("draft-complete", 1, "draft")
        archived = profile("archived-complete", 1, "archived")
        session.flush()

        def add_track(fragment, voice, *, stale_hash=False):
            transcript_hash = hashlib.sha256(fragment.narration_script.strip().encode()).hexdigest()
            session.add(
                FragmentNarrationTrackModel(
                    id=str(uuid4()),
                    fragment_id=fragment.id,
                    profile_id=voice.id,
                    transcript_hash="0" * 64 if stale_hash else transcript_hash,
                    script_version=fragment.script_version,
                    media_path=fragment.audio_path,
                    mime_type=fragment.audio_mime_type,
                    size_bytes=fragment.audio_size_bytes,
                    generation_metadata_json={"test": True},
                    approved_at=now,
                    published_at=now,
                )
            )

        for fragment in fragments:
            for voice in (complete_early, complete_late, draft, archived):
                add_track(fragment, voice)
            add_track(fragment, stale, stale_hash=True)
        for fragment in fragments[:-1]:
            add_track(fragment, missing)
        session.commit()

    route_payload = client.get("/api/v1/routes/nantou-time-layers").get_json()["data"]
    tour = route_payload["audio_tour"]
    profile_ids = [item["id"] for item in tour["narration_profiles"]]
    assert profile_ids == ["default-narration-voice", "complete-early", "complete-late"]
    assert tour["default_narration_profile_id"] == "default-narration-voice"
    assert not (
        {"provider", "model", "voice_id", "emotion", "speed", "pitch"}
        & set(tour["narration_profiles"][1])
    )
    first_fragment = tour["fragments"][0]
    assert set(first_fragment["narration_tracks"]) == set(profile_ids)
    assert all(
        item["audio_url"].startswith("http://localhost/")
        for item in first_fragment["narration_tracks"].values()
    )
    assert (
        first_fragment["audio"]["url"]
        == first_fragment["narration_tracks"]["default-narration-voice"]["audio_url"]
    )

    _, journey = _start(client, user_headers)
    with database.session_factory() as session:
        route = session.scalar(select(RouteModel).where(RouteModel.slug == "nantou-time-layers"))
        route.content_status = "archived"
        session.commit()
    ledger = client.get(
        f"/api/v1/journeys/{journey['id']}/ledger", headers=user_headers
    ).get_json()["data"]
    assert [item["id"] for item in ledger["narration_profiles"]] == profile_ids
    assert ledger["default_narration_profile_id"] == "default-narration-voice"


def test_trigger_accuracy_distance_and_idempotency(client, guest_headers, caplog):
    route, journey = _start(client, guest_headers)
    fragment = route["audio_tour"]["fragments"][0]
    endpoint = f"/api/v1/journeys/{journey['id']}/fragments/{fragment['id']}/triggers"
    inaccurate = client.post(
        endpoint,
        json={
            "method": "location",
            "latitude": fragment["trigger_region"]["latitude"],
            "longitude": fragment["trigger_region"]["longitude"],
            "accuracy_m": 80,
            "idempotency_key": str(uuid4()),
        },
        headers=guest_headers,
    )
    assert inaccurate.status_code == 409
    assert inaccurate.get_json()["error"]["code"] == "location_accuracy_insufficient"
    far = client.post(
        endpoint,
        json={
            "method": "location",
            "latitude": 39.9,
            "longitude": 116.4,
            "accuracy_m": 10,
            "idempotency_key": str(uuid4()),
        },
        headers=guest_headers,
    )
    assert far.status_code == 409
    assert far.get_json()["error"]["code"] == "trigger_too_far"
    key = str(uuid4())
    payload = {
        "method": "location",
        "latitude": fragment["trigger_region"]["latitude"],
        "longitude": fragment["trigger_region"]["longitude"],
        "accuracy_m": 10,
        "idempotency_key": key,
    }
    accepted = client.post(endpoint, json=payload, headers=guest_headers)
    repeated = client.post(endpoint, json=payload, headers=guest_headers)
    assert accepted.status_code == 200
    assert accepted.get_json() == repeated.get_json()
    revealed = accepted.get_json()["data"]["fragment"]
    assert revealed["transcript"]
    assert revealed["mission"]["required"] is False
    assert all(
        revealed["mission"][key]
        for key in ("vantage_point", "shooting_direction", "composition_tip")
    )
    assert "fragment_trigger_requested" in caplog.text
    assert "fragment_trigger_accepted" in caplog.text


def test_real_location_can_trigger_out_of_order_but_demo_stays_dependency_ordered(
    client, guest_headers
):
    route, journey = _start(client, guest_headers)
    later = route["audio_tour"]["fragments"][3]
    endpoint = f"/api/v1/journeys/{journey['id']}/fragments/{later['id']}/triggers"

    located = client.post(
        endpoint,
        json={
            "method": "location",
            "latitude": later["trigger_region"]["latitude"],
            "longitude": later["trigger_region"]["longitude"],
            "accuracy_m": 10,
            "idempotency_key": str(uuid4()),
        },
        headers=guest_headers,
    )
    assert located.status_code == 200
    assert located.get_json()["data"]["fragment"]["id"] == later["id"]

    first = route["audio_tour"]["fragments"][0]
    returned = client.post(
        f"/api/v1/journeys/{journey['id']}/fragments/{first['id']}/triggers",
        json={
            "method": "location",
            "latitude": first["trigger_region"]["latitude"],
            "longitude": first["trigger_region"]["longitude"],
            "accuracy_m": 10,
            "idempotency_key": str(uuid4()),
        },
        headers=guest_headers,
    )
    assert returned.status_code == 200
    ledger = client.get(
        f"/api/v1/journeys/{journey['id']}/ledger", headers=guest_headers
    ).get_json()["data"]
    revealed = {item["id"] for item in ledger["entries"] if item.get("title")}
    assert revealed == {later["id"], first["id"]}

    demo = client.post(
        endpoint,
        json={"method": "demo", "idempotency_key": str(uuid4())},
        headers=guest_headers,
    )
    assert demo.status_code == 409
    assert demo.get_json()["error"]["code"] == "fragment_locked"


def test_real_trigger_requires_current_public_route_but_saved_progress_remains_readable(
    app, client, guest_headers
):
    route, journey = _start(client, guest_headers)
    first, second = route["audio_tour"]["fragments"][:2]
    accepted = client.post(
        f"/api/v1/journeys/{journey['id']}/fragments/{first['id']}/triggers",
        json={
            "method": "location",
            "latitude": first["trigger_region"]["latitude"],
            "longitude": first["trigger_region"]["longitude"],
            "accuracy_m": 10,
            "idempotency_key": str(uuid4()),
        },
        headers=guest_headers,
    )
    assert accepted.status_code == 200

    database = app.extensions["database"]
    with database.session_factory() as session:
        stored_route = session.get(RouteModel, route["id"])
        stored_route.content_status = "archived"
        stored_route.published_at = None
        session.commit()

    blocked = client.post(
        f"/api/v1/journeys/{journey['id']}/fragments/{second['id']}/triggers",
        json={
            "method": "location",
            "latitude": second["trigger_region"]["latitude"],
            "longitude": second["trigger_region"]["longitude"],
            "accuracy_m": 10,
            "idempotency_key": str(uuid4()),
        },
        headers=guest_headers,
    )
    assert blocked.status_code == 409
    assert blocked.get_json()["error"]["code"] == "fragment_unavailable"

    ledger = client.get(
        f"/api/v1/journeys/{journey['id']}/ledger", headers=guest_headers
    ).get_json()["data"]
    saved = next(item for item in ledger["entries"] if item["id"] == first["id"])
    assert saved["state"] == "triggered"
    assert saved["transcript"]


def test_fragment_display_theme_preserves_arbitrary_backend_label(app, client):
    database = app.extensions["database"]
    with database.session_factory() as session:
        fragment = session.get(StoryFragmentModel, "nantou-fragment-1")
        fragment.experience_tags_json = ["潮汐里的旧城"]
        session.commit()

    route = client.get("/api/v1/routes/nantou-time-layers").get_json()["data"]
    fragment = route["audio_tour"]["fragments"][0]
    assert fragment["display_theme"] == "潮汐里的旧城"
    assert fragment["experience_tags"] == ["潮汐里的旧城"]
    assert fragment["expected_duration_seconds"] > 0


def test_legacy_photo_guidance_uses_safe_runtime_fallbacks(app, client, guest_headers):
    database = app.extensions["database"]
    with database.session_factory() as session:
        mission = session.get(PhotoMissionModel, "nantou-mission-1")
        mission.vantage_point = None
        mission.shooting_direction = None
        mission.composition_tip = None
        session.commit()
    route, journey = _start(client, guest_headers)
    fragment = route["audio_tour"]["fragments"][0]
    response = client.post(
        f"/api/v1/journeys/{journey['id']}/fragments/{fragment['id']}/triggers",
        json={"method": "demo", "idempotency_key": str(uuid4())},
        headers=guest_headers,
    )
    mission = response.get_json()["data"]["fragment"]["mission"]
    assert mission["vantage_point"] == mission["field_subject"]
    assert mission["shooting_direction"] == mission["prompt"]
    assert mission["composition_tip"] == mission["prompt"]


def test_ledger_logs_state_summary(client, guest_headers, caplog):
    _, journey = _start(client, guest_headers)

    response = client.get(f"/api/v1/journeys/{journey['id']}/ledger", headers=guest_headers)

    assert response.status_code == 200
    assert "journey_ledger_loaded" in caplog.text
    assert "undiscovered:5" in caplog.text


def test_complete_fragment_arc_with_private_evidence_and_reconstruction(client, guest_headers):
    route, journey = _start(client, guest_headers)
    journey_id = journey["id"]
    assert (
        client.post(f"/api/v1/journeys/{journey_id}/active-tour", headers=guest_headers).get_json()[
            "data"
        ]["status"]
        == "monitoring"
    )
    evidence_ids = []
    for fragment in route["audio_tour"]["fragments"]:
        trigger = client.post(
            f"/api/v1/journeys/{journey_id}/fragments/{fragment['id']}/triggers",
            json={"method": "demo", "idempotency_key": str(uuid4())},
            headers=guest_headers,
        )
        assert trigger.status_code == 200
        playback = client.post(
            f"/api/v1/journeys/{journey_id}/fragments/{fragment['id']}/playback",
            json={"progress": 0.95, "idempotency_key": str(uuid4())},
            headers=guest_headers,
        )
        assert playback.status_code == 200
        if fragment["interaction_type"] == "photo":
            uploaded = client.post(
                f"/api/v1/journeys/{journey_id}/fragments/{fragment['id']}/evidence",
                data={"photo": (_image(), "clue.jpg"), "idempotency_key": str(uuid4())},
                headers=guest_headers,
                content_type="multipart/form-data",
            )
            assert uploaded.status_code == 201
            evidence_ids.append(uploaded.get_json()["data"]["id"])
    ledger = client.get(f"/api/v1/journeys/{journey_id}/ledger", headers=guest_headers).get_json()[
        "data"
    ]
    assert ledger["collected_count"] == 5
    assert ledger["reconstruction_unlocked"] is True
    assert len(ledger["reconstruction_items"]) == 5
    assert all(set(item) == {"id", "text"} for item in ledger["reconstruction_items"])
    expected = [
        "行政建置早于现存城垣",
        "县治迁走，不等于地点失去所有功能",
        "军事所城后来承载新安县治",
        "国家政策可以让行政中心和居民生活同时中断",
        "现代中心迁走后，旧城被重新赋予历史与文化角色",
    ]
    wrong = client.post(
        f"/api/v1/journeys/{journey_id}/reconstruction",
        json={"relationships": list(reversed(expected))},
        headers=guest_headers,
    ).get_json()["data"]
    assert wrong["correct"] is False
    assert wrong["feedback"]
    assert "expected_hint" not in wrong["feedback"][0]
    configured_order = [
        next(item["id"] for item in ledger["reconstruction_items"] if item["text"] == text)
        for text in expected
    ]
    success = client.post(
        f"/api/v1/journeys/{journey_id}/reconstruction",
        json={"relationships": configured_order},
        headers=guest_headers,
    ).get_json()["data"]
    assert success["correct"] is True
    recap = client.get(f"/api/v1/journeys/{journey_id}/recap", headers=guest_headers).get_json()[
        "data"
    ]
    assert "每次身份改变以后" in recap["complete_story"]
    assert len(recap["evidence"]) == 3
    photo = client.get(
        f"/api/v1/journeys/{journey_id}/evidence/{evidence_ids[0]}", headers=guest_headers
    )
    assert photo.status_code == 200
    assert photo.content_type == "image/jpeg"
    deleted_after_completion = client.delete(
        f"/api/v1/journeys/{journey_id}/evidence/{evidence_ids[0]}",
        headers=guest_headers,
    )
    assert deleted_after_completion.status_code == 200
    after_delete = client.get(
        f"/api/v1/journeys/{journey_id}/ledger", headers=guest_headers
    ).get_json()["data"]
    assert after_delete["collected_count"] == 5
    assert after_delete["reconstruction_unlocked"] is True


def test_evidence_is_private_between_guests(app, client, guest_headers):
    route, journey = _start(client, guest_headers)
    fragment = route["audio_tour"]["fragments"][0]
    base = f"/api/v1/journeys/{journey['id']}/fragments/{fragment['id']}"
    client.post(
        f"{base}/triggers",
        json={"method": "demo", "idempotency_key": str(uuid4())},
        headers=guest_headers,
    )
    client.post(
        f"{base}/playback",
        json={"progress": 1.0, "idempotency_key": str(uuid4())},
        headers=guest_headers,
    )
    evidence = client.post(
        f"{base}/evidence",
        data={"photo": (_image(), "clue.jpg"), "idempotency_key": str(uuid4())},
        headers=guest_headers,
        content_type="multipart/form-data",
    ).get_json()["data"]
    listed = client.get(f"/api/v1/journeys/{journey['id']}/evidence", headers=guest_headers)
    assert listed.status_code == 200
    metadata = listed.get_json()["data"]
    assert len(metadata) == 1
    assert metadata[0]["fragment_id"] == fragment["id"]
    assert metadata[0]["url"].endswith(f"/journeys/{journey['id']}/evidence/{evidence['id']}")
    assert not (
        {"object_key", "storage_provider", "canonical_reference", "sha256"} & set(metadata[0])
    )
    restarted_style_read = client.get(
        f"/api/v1/journeys/{journey['id']}/evidence/{evidence['id']}",
        headers=guest_headers,
    )
    assert restarted_style_read.status_code == 200
    assert restarted_style_read.content_type == "image/jpeg"
    other_token = client.post("/api/v1/sessions/guest").get_json()["data"]["token"]
    other_headers = {"Authorization": f"Bearer {other_token}"}
    assert (
        client.get(f"/api/v1/journeys/{journey['id']}/evidence", headers=other_headers).status_code
        == 404
    )
    response = client.get(
        f"/api/v1/journeys/{journey['id']}/evidence/{evidence['id']}",
        headers=other_headers,
    )
    assert response.status_code == 404

    database = app.extensions["database"]
    with database.session_factory() as session:
        stored = session.get(EvidenceModel, evidence["id"])
        stored.expires_at = datetime.now(UTC) - timedelta(seconds=1)
        session.commit()
    expired = client.get(
        f"/api/v1/journeys/{journey['id']}/evidence/{evidence['id']}",
        headers=guest_headers,
    )
    assert expired.status_code == 410
    assert expired.get_json()["error"]["code"] == "evidence_expired"
    assert (
        client.get(f"/api/v1/journeys/{journey['id']}/evidence", headers=guest_headers).get_json()[
            "data"
        ][0]["is_expired"]
        is True
    )

    deleted = client.delete(
        f"/api/v1/journeys/{journey['id']}/evidence/{evidence['id']}",
        headers=guest_headers,
    )
    assert deleted.status_code == 200
    assert (
        client.get(f"/api/v1/journeys/{journey['id']}/evidence", headers=guest_headers).get_json()[
            "data"
        ]
        == []
    )
    assert (
        client.get(
            f"/api/v1/journeys/{journey['id']}/evidence/{evidence['id']}",
            headers=guest_headers,
        ).status_code
        == 404
    )


def test_invalid_evidence_does_not_change_progress_and_delete_preserves_collection(
    client, guest_headers
):
    route, journey = _start(client, guest_headers)
    fragment = route["audio_tour"]["fragments"][0]
    base = f"/api/v1/journeys/{journey['id']}/fragments/{fragment['id']}"
    client.post(
        f"{base}/triggers",
        json={"method": "demo", "idempotency_key": str(uuid4())},
        headers=guest_headers,
    )
    client.post(
        f"{base}/playback",
        json={"progress": 1.0, "idempotency_key": str(uuid4())},
        headers=guest_headers,
    )
    invalid = client.post(
        f"{base}/evidence",
        data={
            "photo": (BytesIO(b"not-an-image"), "clue.jpg"),
            "idempotency_key": str(uuid4()),
        },
        headers=guest_headers,
        content_type="multipart/form-data",
    )
    assert invalid.status_code == 422
    assert invalid.get_json()["error"]["code"] == "evidence_invalid"

    upload_key = str(uuid4())
    accepted_response = client.post(
        f"{base}/evidence",
        data={
            "photo": (_image(), "clue.jpg"),
            "idempotency_key": upload_key,
        },
        headers=guest_headers,
        content_type="multipart/form-data",
    )
    accepted = accepted_response.get_json()["data"]
    repeated = client.post(
        f"{base}/evidence",
        data={"photo": (_image(), "clue.jpg"), "idempotency_key": upload_key},
        headers=guest_headers,
        content_type="multipart/form-data",
    )
    assert repeated.status_code == 201
    assert repeated.get_json()["data"]["id"] == accepted["id"]
    deleted = client.delete(
        f"/api/v1/journeys/{journey['id']}/evidence/{accepted['id']}",
        headers=guest_headers,
    )
    assert deleted.status_code == 200
    ledger = client.get(
        f"/api/v1/journeys/{journey['id']}/ledger", headers=guest_headers
    ).get_json()["data"]
    assert ledger["entries"][0]["state"] == "collected"
    assert ledger["entries"][0]["collected_at"] is not None


def test_photo_clue_collects_without_upload_and_legacy_pending_reconciles(
    app, client, guest_headers
):
    route, journey = _start(client, guest_headers)
    first, second = route["audio_tour"]["fragments"][:2]
    first_base = f"/api/v1/journeys/{journey['id']}/fragments/{first['id']}"
    client.post(
        f"{first_base}/triggers",
        json={"method": "demo", "idempotency_key": str(uuid4())},
        headers=guest_headers,
    )
    completed = client.post(
        f"{first_base}/playback",
        json={"progress": 1.0, "idempotency_key": str(uuid4())},
        headers=guest_headers,
    )
    assert completed.get_json()["data"]["fragment"]["state"] == "collected"
    assert (
        client.get(f"/api/v1/journeys/{journey['id']}/evidence", headers=guest_headers).get_json()[
            "data"
        ]
        == []
    )
    next_trigger = client.post(
        f"/api/v1/journeys/{journey['id']}/fragments/{second['id']}/triggers",
        json={"method": "demo", "idempotency_key": str(uuid4())},
        headers=guest_headers,
    )
    assert next_trigger.status_code == 200
    for index, fragment in enumerate(route["audio_tour"]["fragments"][1:], start=1):
        if index > 1:
            trigger = client.post(
                f"/api/v1/journeys/{journey['id']}/fragments/{fragment['id']}/triggers",
                json={"method": "demo", "idempotency_key": str(uuid4())},
                headers=guest_headers,
            )
            assert trigger.status_code == 200
        playback = client.post(
            f"/api/v1/journeys/{journey['id']}/fragments/{fragment['id']}/playback",
            json={"progress": 1.0, "idempotency_key": str(uuid4())},
            headers=guest_headers,
        )
        assert playback.status_code == 200
    no_photo_ledger = client.get(
        f"/api/v1/journeys/{journey['id']}/ledger", headers=guest_headers
    ).get_json()["data"]
    assert no_photo_ledger["collected_count"] == no_photo_ledger["total_count"] == 5
    assert no_photo_ledger["reconstruction_unlocked"] is True
    assert (
        client.get(f"/api/v1/journeys/{journey['id']}/evidence", headers=guest_headers).get_json()[
            "data"
        ]
        == []
    )

    database = app.extensions["database"]
    with database.session_factory() as session:
        state = session.scalar(
            select(JourneyFragmentModel).where(
                JourneyFragmentModel.journey_id == journey["id"],
                JourneyFragmentModel.fragment_id == first["id"],
            )
        )
        state.state = "mission_pending"
        state.collected_at = None
        session.commit()
    reconciled = client.get(
        f"/api/v1/journeys/{journey['id']}/ledger", headers=guest_headers
    ).get_json()["data"]
    assert reconciled["entries"][0]["state"] == "collected"
    assert reconciled["entries"][0]["collected_at"] is not None
