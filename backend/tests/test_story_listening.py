from __future__ import annotations

import hashlib
from datetime import UTC, datetime

from app.infrastructure.persistence.models import (
    HomeStoryPublicationModel,
    NarrationVoiceProfileModel,
    RouteModel,
    StoryArcModel,
    StoryNarrationTrackModel,
)


def _publish_story(app, *, identity: str, title: str, weight: int = 1):
    now = datetime.now(UTC)
    database = app.extensions["database"]
    with database.session_factory() as session:
        route = session.query(RouteModel).filter(RouteModel.slug == "nantou-time-layers").one()
        arc = session.query(StoryArcModel).filter(StoryArcModel.route_id == route.id).one()
        profile = session.query(NarrationVoiceProfileModel).first()
        profile.status = "published"
        profile.published_at = now
        transcript_hash = hashlib.sha256(arc.complete_story.strip().encode()).hexdigest()
        track = StoryNarrationTrackModel(
            id=f"track-{identity}",
            arc_id=arc.id,
            profile_id=profile.id,
            transcript_hash=transcript_hash,
            script_version=arc.script_version,
            media_path="audio/story.mp3",
            mime_type="audio/mpeg",
            size_bytes=1024,
            duration_ms=65000,
            checksum_sha256="a" * 64,
            generation_metadata_json={},
            status="published",
            reviewed_by="editor",
            reviewed_at=now,
            published_at=now,
            created_at=now,
            updated_at=now,
        )
        session.add(track)
        session.flush()
        publication = HomeStoryPublicationModel(
            id=f"story-{identity}",
            arc_id=arc.id,
            selected_track_id=track.id,
            title=title,
            introduction="坐下来，听一段深圳的旧时光。",
            cover_image=route.hero_image,
            selection_weight=weight,
            status="published",
            reviewed_by="editor",
            reviewed_at=now,
            published_at=now,
            created_at=now,
            updated_at=now,
        )
        session.add(publication)
        session.commit()
        return publication.id, track.id


def _publish_additional_story(app, *, identity: str, title: str, weight: int = 1):
    now = datetime.now(UTC)
    database = app.extensions["database"]
    with database.session_factory() as session:
        source_route = session.query(RouteModel).filter_by(slug="nantou-time-layers").one()
        source_arc = session.query(StoryArcModel).filter_by(route_id=source_route.id).one()
        profile = session.query(NarrationVoiceProfileModel).first()
        profile.status = "published"
        profile.published_at = now
        route = RouteModel(
            id=f"route-{identity}",
            city_id=source_route.city_id,
            slug=f"route-{identity}",
            title=f"路线 {identity}",
            subtitle=source_route.subtitle,
            description=source_route.description,
            duration_minutes=source_route.duration_minutes,
            distance_km=source_route.distance_km,
            difficulty=source_route.difficulty,
            theme=source_route.theme,
            hero_image=source_route.hero_image,
            is_featured=False,
            content_status="published",
            published_at=now,
        )
        session.add(route)
        arc = StoryArcModel(
            id=f"arc-{identity}",
            route_id=route.id,
            title=title,
            central_question=source_arc.central_question,
            complete_story=f"{title}的完整正文。",
            causal_model_json=[],
            pronunciation_notes_json=[],
            script_version=f"story-{identity}-v1",
            review_state="reviewed",
            field_audit_state="reviewed",
        )
        session.add(arc)
        transcript_hash = hashlib.sha256(arc.complete_story.encode()).hexdigest()
        track = StoryNarrationTrackModel(
            id=f"track-{identity}",
            arc_id=arc.id,
            profile_id=profile.id,
            transcript_hash=transcript_hash,
            script_version=arc.script_version,
            media_path=f"audio/{identity}.mp3",
            mime_type="audio/mpeg",
            size_bytes=2048,
            duration_ms=42000,
            generation_metadata_json={},
            status="published",
            reviewed_at=now,
            published_at=now,
            created_at=now,
            updated_at=now,
        )
        session.add(track)
        publication = HomeStoryPublicationModel(
            id=f"story-{identity}",
            arc_id=arc.id,
            selected_track_id=track.id,
            title=title,
            introduction="另一段经过审核的城市故事。",
            cover_image=route.hero_image,
            selection_weight=weight,
            status="published",
            reviewed_at=now,
            published_at=now,
            created_at=now,
            updated_at=now,
        )
        session.add(publication)
        session.commit()
        return publication.id


def test_random_story_returns_only_safe_published_metadata(app, client):
    story_id, _ = _publish_story(app, identity="one", title="南头慢慢讲")
    response = client.get("/api/v1/stories/random?city_slug=shenzhen")
    assert response.status_code == 200
    story = response.get_json()["data"]
    assert story["id"] == story_id
    assert story["duration_ms"] == 65000
    assert story["audio_url"]
    serialized = str(story).lower()
    assert "voice_id" not in serialized
    assert "object_key" not in serialized
    assert "reviewed_by" not in serialized
    assert client.get(f"/api/v1/stories/{story_id}").status_code == 200


def test_random_story_excludes_stale_and_empty_pools(app, client):
    story_id, track_id = _publish_story(app, identity="stale", title="旧音轨")
    database = app.extensions["database"]
    with database.session_factory() as session:
        track = session.get(StoryNarrationTrackModel, track_id)
        track.transcript_hash = "0" * 64
        session.commit()
    empty = client.get("/api/v1/stories/random?city_slug=shenzhen")
    assert empty.status_code == 404
    assert empty.get_json()["error"]["code"] == "story_pool_empty"
    assert client.get(f"/api/v1/stories/{story_id}").status_code == 404
    assert client.get("/api/v1/stories/random?city_slug=unknown").status_code == 404


def test_random_story_honors_exclusion_weights_and_zero_weight(app, client):
    first_id, _ = _publish_story(app, identity="first", title="第一篇", weight=2)
    second_id = _publish_additional_story(app, identity="second", title="第二篇", weight=7)
    service = app.extensions["services"]["story_listening"]
    observed: dict[str, object] = {}

    def choose(population, *, weights, k):
        observed["weights"] = list(weights)
        observed["k"] = k
        return [population[-1]]

    service.chooser = choose
    response = client.get(
        f"/api/v1/stories/random?city_slug=shenzhen&exclude_id={first_id}"
    )
    assert response.status_code == 200
    assert response.get_json()["data"]["id"] == second_id
    assert observed == {"weights": [7], "k": 1}

    database = app.extensions["database"]
    with database.session_factory() as session:
        second = session.get(HomeStoryPublicationModel, second_id)
        second.selection_weight = 0
        session.commit()
    response = client.get(
        f"/api/v1/stories/random?city_slug=shenzhen&exclude_id={first_id}"
    )
    assert response.status_code == 200
    assert response.get_json()["data"]["id"] == first_id
