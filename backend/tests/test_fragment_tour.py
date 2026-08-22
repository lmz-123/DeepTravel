from __future__ import annotations

import hashlib
from datetime import UTC, datetime
from io import BytesIO
from uuid import uuid4

from PIL import Image
from sqlalchemy import select

from app.infrastructure.persistence.models import (
    FragmentNarrationTrackModel,
    NarrationVoiceProfileModel,
    RouteModel,
    StoryArcModel,
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
    assert tour["download_size_bytes"] > 0
    assert "transcript" not in tour["fragments"][0]
    assert tour["fragments"][0]["audio"]["url"].endswith(".m4a")
    audio = client.get("/api/v1/assets/audio/nantou-fragment-1-nantou-2026.08-review.1.m4a")
    assert audio.status_code == 200
    assert audio.content_type == "audio/mp4"


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
            transcript_hash = hashlib.sha256(
                fragment.narration_script.strip().encode()
            ).hexdigest()
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
    assert not ({"provider", "model", "voice_id", "emotion", "speed", "pitch"} & set(tour["narration_profiles"][1]))
    first_fragment = tour["fragments"][0]
    assert set(first_fragment["narration_tracks"]) == set(profile_ids)
    assert all(
        item["audio_url"].startswith("http://localhost/")
        for item in first_fragment["narration_tracks"].values()
    )
    assert first_fragment["audio"]["url"] == first_fragment["narration_tracks"]["default-narration-voice"]["audio_url"]

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
    assert accepted.get_json()["data"]["fragment"]["transcript"]
    assert "fragment_trigger_requested" in caplog.text
    assert "fragment_trigger_accepted" in caplog.text


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
    assert "不同制度反复使用" in recap["complete_story"]
    assert len(recap["evidence"]) == 3
    photo = client.get(
        f"/api/v1/journeys/{journey_id}/evidence/{evidence_ids[0]}", headers=guest_headers
    )
    assert photo.status_code == 200
    assert photo.content_type == "image/jpeg"


def test_evidence_is_private_between_guests(client, guest_headers):
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
    other_token = client.post("/api/v1/sessions/guest").get_json()["data"]["token"]
    response = client.get(
        f"/api/v1/journeys/{journey['id']}/evidence/{evidence['id']}",
        headers={"Authorization": f"Bearer {other_token}"},
    )
    assert response.status_code == 404


def test_invalid_evidence_does_not_collect_and_delete_rolls_back_mission(client, guest_headers):
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

    accepted = client.post(
        f"{base}/evidence",
        data={
            "photo": (_image(), "clue.jpg"),
            "idempotency_key": str(uuid4()),
        },
        headers=guest_headers,
        content_type="multipart/form-data",
    ).get_json()["data"]
    deleted = client.delete(
        f"/api/v1/journeys/{journey['id']}/evidence/{accepted['id']}",
        headers=guest_headers,
    )
    assert deleted.status_code == 200
    ledger = client.get(
        f"/api/v1/journeys/{journey['id']}/ledger", headers=guest_headers
    ).get_json()["data"]
    assert ledger["entries"][0]["state"] == "mission_pending"
