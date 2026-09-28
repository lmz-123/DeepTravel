from datetime import UTC, datetime

from app.infrastructure.persistence.models import (
    ActiveTourModel,
    JourneyFragmentModel,
    JourneyModel,
    MediaAssetModel,
    RouteModel,
    StoryArcModel,
    StoryFragmentModel,
)


def _progress_counts(app):
    with app.extensions["database"].session_factory() as session:
        return tuple(
            session.query(model).count()
            for model in (JourneyModel, JourneyFragmentModel, ActiveTourModel)
        )


def test_manual_directory_exposes_published_text_without_arrival_or_playback(app, client):
    before = _progress_counts(app)
    response = client.get("/api/v1/routes/nantou-time-layers")
    assert response.status_code == 200
    payload = response.get_json()["data"]
    assert payload["city"]["name"] == "深圳"
    assert payload["city"]["slug"] == "shenzhen"
    chapters = payload["manual_chapters"]
    assert len(chapters) == payload["audio_tour"]["fragment_count"]
    assert [item["position"] for item in chapters] == sorted(
        item["position"] for item in chapters
    )
    assert all(item["title"] and item["transcript"] for item in chapters)
    assert all(item["state"] == "undiscovered" for item in chapters)
    assert all(item["playback_progress"] == 0 for item in chapters)
    assert all(item["triggered_at"] is None for item in chapters)
    assert all(item["collected_at"] is None for item in chapters)
    assert all("transcript" not in item for item in payload["audio_tour"]["fragments"])
    assert _progress_counts(app) == before
    # Catalog lists remain lightweight and cannot imply reading progress.
    listing = client.get("/api/v1/cities/shenzhen/routes").get_json()["data"]["routes"]
    assert all("manual_chapters" not in item for item in listing)


def test_manual_directory_preserves_canonical_oss_media(app, client):
    with app.extensions["database"].session_factory() as session:
        route = session.query(RouteModel).filter_by(slug="nantou-time-layers").one()
        arc = session.query(StoryArcModel).filter_by(route_id=route.id).one()
        chapter = session.query(StoryFragmentModel).filter_by(arc_id=arc.id).first()
        chapter.audio_path = "audio/manual-test.mp3"
        asset = MediaAssetModel(
            key="manual-test-audio", storage_path=chapter.audio_path,
            mime_type="audio/mpeg", created_at=datetime.now(UTC),
            updated_at=datetime.now(UTC),
        )
        session.add(asset)
        canonical = "https://travel.oss-cn-shenzhen.aliyuncs.com/original/voice.mp3"
        asset.canonical_url = canonical
        hero = "https://travel.oss-cn-shenzhen.aliyuncs.com/original/route.jpg"
        route.hero_image = hero
        chapter_id = chapter.id
        session.flush()
        media_count = session.query(MediaAssetModel).count()
        session.commit()
    payload = client.get("/api/v1/routes/nantou-time-layers").get_json()["data"]
    assert payload["hero_image"] == hero
    assert next(item for item in payload["manual_chapters"] if item["id"] == chapter_id)[
        "audio"
    ]["url"] == canonical
    with app.extensions["database"].session_factory() as session:
        assert session.query(MediaAssetModel).count() == media_count
        assert session.get(MediaAssetModel, asset.key).canonical_url == canonical


def test_draft_routes_never_publish_manual_chapters(app, client):
    with app.extensions["database"].session_factory() as session:
        route = session.query(RouteModel).filter_by(slug="nantou-time-layers").one()
        route.content_status = "draft"
        route_id = route.id
        session.commit()
    assert app.extensions["services"]["fragment_tours"].manual_chapters(route_id) == []
    response = client.get("/api/v1/routes/nantou-time-layers")
    assert response.status_code == 404 or "manual_chapters" not in response.get_json()["data"]
