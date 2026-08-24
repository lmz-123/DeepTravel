from __future__ import annotations

import hashlib
from datetime import UTC, datetime

from app.application.city_story_service import HOME_MODULES
from app.infrastructure.persistence.models import (
    NarrationVoiceProfileModel,
    RouteModel,
    RoutePredepartureTrackModel,
    RoutePretripGuidanceModel,
    StoryArcModel,
    StoryCatalogItemModel,
    StoryCatalogVariantModel,
    StoryNarrationTrackModel,
    StoryPlacementModel,
)


def _publish_catalog(app):
    now = datetime.now(UTC)
    with app.extensions["database"].session_factory() as session:
        route = session.query(RouteModel).filter_by(slug="nantou-time-layers").one()
        route.content_status = "published"
        route.published_at = now
        arc = session.query(StoryArcModel).filter_by(route_id=route.id).one()
        arc.review_state = "reviewed"
        profile = session.query(NarrationVoiceProfileModel).first()
        profile.status = "published"
        profile.published_at = now
        revision = hashlib.sha256(arc.complete_story.strip().encode()).hexdigest()
        track = StoryNarrationTrackModel(
            id="catalog-track",
            arc_id=arc.id,
            profile_id=profile.id,
            transcript_hash=revision,
            script_version=arc.script_version,
            media_path="audio/catalog.mp3",
            mime_type="audio/mpeg",
            size_bytes=4096,
            duration_ms=240000,
            checksum_sha256="b" * 64,
            generation_metadata_json={},
            status="published",
            reviewed_at=now,
            published_at=now,
            created_at=now,
            updated_at=now,
        )
        item = StoryCatalogItemModel(
            id="catalog-story",
            city_id=route.city_id,
            source_kind="story_arc",
            source_id=arc.id,
            canonical_revision=revision,
            title="城墙拐角的一件小事",
            summary="四分钟，先认识一个真正看得见的细节。",
            cover_image=route.hero_image,
            district="南头",
            themes_json=["城市历史", "未来新标签"],
            point_ids_json=[],
            related_stories_json=[],
            content_type="city_small_thing",
            place_context="深圳南头古城",
            observable_detail="留意墙砖之间不同年代的灰缝。",
            attention_hint="走到转角时抬头看看檐口。",
            sources_json=[{"title": "地方志", "fact_status": "documented"}],
            fact_status="documented",
            review_status="reviewed",
            status="published",
            version=1,
            reviewed_at=now,
            published_at=now,
            created_at=now,
            updated_at=now,
        )
        variant = StoryCatalogVariantModel(
            id="catalog-variant",
            catalog_item_id=item.id,
            role="short_preview",
            source_kind="story_arc",
            source_id=arc.id,
            track_kind="story",
            track_id=track.id,
            transcript_hash=revision,
            script_version=arc.script_version,
            status="published",
            reviewed_at=now,
            published_at=now,
            created_at=now,
            updated_at=now,
        )
        session.add_all([track, item, variant])
        for index, (key, _, _) in enumerate(HOME_MODULES):
            session.add(
                StoryPlacementModel(
                    id=f"placement-{index}",
                    catalog_item_id=item.id,
                    channel="home",
                    module_key=key,
                    variant_role="short_preview",
                    display_order=index,
                    weight=1,
                    status="published",
                    reviewed_at=now,
                    published_at=now,
                    created_at=now,
                    updated_at=now,
                )
            )
        predeparture_text = "出发前，先认识城墙转角里叠在一起的时间。"
        predeparture_hash = hashlib.sha256(predeparture_text.encode()).hexdigest()
        intro_track = RoutePredepartureTrackModel(
            id="predeparture-track",
            route_id=route.id,
            profile_id=profile.id,
            transcript_hash=predeparture_hash,
            script_version="predeparture-v1",
            media_path="public/predeparture/catalog.mp3",
            mime_type="audio/mpeg",
            size_bytes=2048,
            duration_ms=12000,
            checksum_sha256="c" * 64,
            generation_metadata_json={"source": "test"},
            status="published",
            reviewed_at=now,
            published_at=now,
            created_at=now,
            updated_at=now,
        )
        session.add_all(
            [
                intro_track,
                RoutePretripGuidanceModel(
                    route_id=route.id,
                    theme_story_catalog_id=item.id,
                    story_directions_json=[
                        {"catalog_id": item.id, "title": "城墙的时间", "order": 2}
                    ],
                    companion_tags_json=["适合一个人", "适合朋友同行"],
                    safety_tips_json=["在人行区域停留"],
                    rest_tips_json=["入口处可以休息"],
                    accessibility_tips_json=["主要路面较平整"],
                    weather_tips_json=["雨天注意石板湿滑"],
                    offline_roles_json=["short_preview"],
                    introduction_text=predeparture_text,
                    introduction_transcript_hash=predeparture_hash,
                    introduction_script_version="predeparture-v1",
                    selected_intro_track_id=intro_track.id,
                    status="published",
                    version=1,
                    reviewed_at=now,
                    published_at=now,
                    updated_at=now,
                ),
            ]
        )
        session.commit()
        return route.slug, arc.id


def test_city_home_has_five_backend_driven_modules_and_canonical_story(app, client):
    _, arc_id = _publish_catalog(app)
    response = client.get("/api/v1/cities/shenzhen/stories")
    assert response.status_code == 200
    data = response.get_json()["data"]
    assert [item["key"] for item in data["modules"]] == [item[0] for item in HOME_MODULES]
    assert data["modules"][0]["primary"] is True
    story = data["modules"][0]["items"][0]
    assert story["arc_id"] == arc_id
    assert story["themes"] == ["城市历史", "未来新标签"]
    assert story["observable_detail"]
    assert story["quiz"] is None
    detail = client.get("/api/v1/city-stories/catalog-story")
    assert detail.status_code == 200
    assert detail.get_json()["data"]["transcript"] == story["transcript"]


def test_city_home_empty_is_actionable_and_stale_story_is_excluded(app, client):
    response = client.get("/api/v1/cities/shenzhen/stories")
    assert response.status_code == 200
    data = response.get_json()["data"]
    assert data["empty"] is True
    assert data["actions"]["switch_city"] is True

    _publish_catalog(app)
    with app.extensions["database"].session_factory() as session:
        item = session.get(StoryCatalogItemModel, "catalog-story")
        arc = session.query(StoryArcModel).filter_by(id=item.source_id).one()
        arc.complete_story += "正文已修改"
        session.commit()
    data = client.get("/api/v1/cities/shenzhen/stories").get_json()["data"]
    assert all(not module["items"] for module in data["modules"])


def test_pretrip_is_available_without_journey_and_has_no_exam(app, client):
    route_slug, _ = _publish_catalog(app)
    response = client.get(f"/api/v1/routes/{route_slug}/pretrip")
    assert response.status_code == 200
    data = response.get_json()["data"]
    assert data["available"] is True
    assert data["requires_arrival"] is False
    assert data["advisory_order"] is True
    assert data["quiz"] is None
    assert data["predeparture"]["text"].startswith("出发前")
    assert data["predeparture"]["audio"]["url"].startswith("https://cdn.test.invalid/")
    assert data["companion_tags"] == ["适合一个人", "适合朋友同行"]
    assert {item["kind"] for item in data["offline_resources"]} == {"audio", "transcript"}

    route = client.get(f"/api/v1/routes/{route_slug}").get_json()["data"]
    assert route["predeparture"] == data["predeparture"]


def test_favorites_are_authenticated_idempotent_and_isolated(app, client, user_headers):
    _publish_catalog(app)
    city = client.get("/api/v1/cities").get_json()["data"][0]
    target = city["slug"]
    first = client.put(f"/api/v1/favorites/city/{target}", headers=user_headers)
    second = client.put(f"/api/v1/favorites/city/{target}", headers=user_headers)
    assert first.status_code == second.status_code == 200
    own = client.get("/api/v1/favorites", headers=user_headers).get_json()["data"]
    assert len(own) == 1 and own[0]["available"] is True
    assert client.get("/api/v1/favorites").status_code == 401

    other = client.post(
        "/api/v1/auth/register",
        json={"username": "traveler-two", "password": "field-test-456"},
    ).get_json()["data"]["token"]
    assert (
        client.get("/api/v1/favorites", headers={"Authorization": f"Bearer {other}"}).get_json()[
            "data"
        ]
        == []
    )
    removed = client.delete(f"/api/v1/favorites/city/{target}", headers=user_headers)
    assert removed.get_json()["data"]["favorite"] is False
