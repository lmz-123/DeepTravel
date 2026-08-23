from __future__ import annotations

import importlib.util
from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect, text


def test_node_community_migration_uses_mysql_compatible_text_columns(monkeypatch):
    migration_path = (
        Path(__file__).parents[1] / "migrations" / "versions" / "20260823_0009_node_community.py"
    )
    spec = importlib.util.spec_from_file_location("node_community_migration", migration_path)
    assert spec is not None and spec.loader is not None
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)

    tables = {}
    monkeypatch.setattr(
        migration.op,
        "create_table",
        lambda name, *columns, **_kwargs: tables.setdefault(name, columns),
    )
    monkeypatch.setattr(migration.op, "create_index", lambda *_args, **_kwargs: None)

    migration.upgrade()

    post_body = next(column for column in tables["community_posts"] if column.name == "body")
    assert post_body.server_default is None


def test_content_review_migration_is_safe_when_model_created_audit_columns(tmp_path):
    database_path = tmp_path / "migration.db"
    engine = create_engine(f"sqlite:///{database_path}")
    config = Config(str(Path(__file__).parents[1] / "alembic.ini"))
    config.set_main_option("sqlalchemy.url", f"sqlite:///{database_path}")

    command.upgrade(config, "20260822_0004")

    columns = {column["name"] for column in inspect(engine).get_columns("historical_claims")}
    assert {"reviewed_by", "reviewed_at"}.issubset(columns)

    with engine.begin() as connection:
        version = connection.execute(text("SELECT version_num FROM alembic_version")).scalar_one()
    assert version == "20260822_0004"


def test_managed_content_migration_round_trips(tmp_path):
    database_path = tmp_path / "managed-content-migration.db"
    engine = create_engine(f"sqlite:///{database_path}")
    config = Config(str(Path(__file__).parents[1] / "alembic.ini"))
    config.set_main_option("sqlalchemy.url", f"sqlite:///{database_path}")

    command.upgrade(config, "head")
    route_columns = {column["name"] for column in inspect(engine).get_columns("routes")}
    trigger_columns = {column["name"] for column in inspect(engine).get_columns("trigger_regions")}
    assert {"managed_package_id", "managed_package_version"} <= route_columns
    assert {
        "coordinate_system",
        "source_coordinate_system",
        "coordinate_source",
        "field_notes",
    } <= trigger_columns

    command.downgrade(config, "20260822_0004")
    route_columns = {column["name"] for column in inspect(engine).get_columns("routes")}
    assert "managed_package_id" not in route_columns

    command.upgrade(config, "head")
    with engine.begin() as connection:
        version = connection.execute(text("SELECT version_num FROM alembic_version")).scalar_one()
    assert version == "20260823_0013"


def test_city_story_catalog_migration_round_trips(tmp_path):
    database_path = tmp_path / "city-story-catalog.db"
    engine = create_engine(f"sqlite:///{database_path}")
    config = Config(str(Path(__file__).parents[1] / "alembic.ini"))
    config.set_main_option("sqlalchemy.url", f"sqlite:///{database_path}")

    command.upgrade(config, "20260823_0012")
    command.upgrade(config, "head")
    expected = {
        "story_catalog_items",
        "story_catalog_variants",
        "story_placements",
        "route_pretrip_guidance",
        "traveler_favorites",
        "content_import_previews",
        "content_import_batches",
    }
    assert expected <= set(inspect(engine).get_table_names())
    favorite_unique = {
        item["name"] for item in inspect(engine).get_unique_constraints("traveler_favorites")
    }
    assert "uq_traveler_favorite" in favorite_unique
    import_unique = {
        item["name"] for item in inspect(engine).get_unique_constraints("content_import_batches")
    }
    assert "uq_content_import_package_version" in import_unique

    command.downgrade(config, "20260823_0012")
    assert expected.isdisjoint(inspect(engine).get_table_names())


def test_narration_voice_migration_backfills_once_and_round_trips(tmp_path):
    database_path = tmp_path / "narration-voices.db"
    engine = create_engine(f"sqlite:///{database_path}")
    config = Config(str(Path(__file__).parents[1] / "alembic.ini"))
    config.set_main_option("sqlalchemy.url", f"sqlite:///{database_path}")
    command.upgrade(config, "20260822_0006")
    with engine.begin() as connection:
        connection.execute(
            text(
                "INSERT INTO cities (id, slug, name, subtitle, hero_image, latitude, longitude) "
                "VALUES ('voice-city', 'voice-city', '音色城', '测试', 'cover.jpg', 0, 0)"
            )
        )
        connection.execute(
            text(
                "INSERT INTO routes (id, city_id, slug, title, subtitle, description, "
                "duration_minutes, distance_km, difficulty, theme, hero_image, is_featured, "
                "content_status, published_at) VALUES ('voice-route', 'voice-city', "
                "'voice-route', '音色路线', '测试', '测试', 30, 1, '轻松', '历史', "
                "'cover.jpg', 0, 'published', '2026-08-22 00:00:00')"
            )
        )
        connection.execute(
            text(
                "INSERT INTO story_arcs (id, route_id, title, central_question, complete_story, "
                "causal_model_json, pronunciation_notes_json, script_version, review_state, "
                "field_audit_state) VALUES ('voice-arc', 'voice-route', '故事', '为何', '完整', "
                "'[]', '[]', 'v1', 'reviewed', 'reviewed')"
            )
        )
        connection.execute(
            text(
                "INSERT INTO story_fragments (id, arc_id, position, title, safe_preview, "
                "narration_script, transcript, audio_path, audio_mime_type, audio_size_bytes, "
                "script_version, interaction_type, completion_threshold, key_claim, "
                "answers_question, raises_question, authenticity_label, review_state) "
                "VALUES ('voice-fragment', 'voice-arc', 1, '线索', '预告', '最终文字稿', "
                "'最终文字稿', 'audio/default.m4a', 'audio/mp4', 321, 'v1', 'passive', "
                "0.9, '主张', '回答', '问题', 'documented', 'reviewed')"
            )
        )
    command.upgrade(config, "head")

    inspector = inspect(engine)
    assert {"narration_voice_profiles", "fragment_narration_tracks"} <= set(
        inspector.get_table_names()
    )
    assert "profile_id" in {
        column["name"] for column in inspector.get_columns("narration_previews")
    }
    with engine.begin() as connection:
        profile_count = connection.execute(
            text("SELECT COUNT(*) FROM narration_voice_profiles WHERE is_default = 1")
        ).scalar_one()
        tracks = (
            connection.execute(
                text(
                    "SELECT media_path, transcript_hash, script_version "
                    "FROM fragment_narration_tracks"
                )
            )
            .mappings()
            .all()
        )
        singular_path = connection.execute(
            text("SELECT audio_path FROM story_fragments WHERE id = 'voice-fragment'")
        ).scalar_one()
    assert profile_count == 1
    assert len(tracks) == 1
    assert tracks[0]["media_path"] == singular_path == "audio/default.m4a"
    assert tracks[0]["script_version"] == "v1"

    command.downgrade(config, "20260822_0006")
    assert "narration_voice_profiles" not in set(inspect(engine).get_table_names())
    command.upgrade(config, "head")
    with engine.begin() as connection:
        second_track_count = connection.execute(
            text("SELECT COUNT(*) FROM fragment_narration_tracks")
        ).scalar_one()
    assert second_track_count == 1


def test_account_cloud_migration_preserves_known_public_routes_and_keeps_drafts_offline(
    tmp_path,
):
    database_path = tmp_path / "publication-backfill.db"
    engine = create_engine(f"sqlite:///{database_path}")
    config = Config(str(Path(__file__).parents[1] / "alembic.ini"))
    config.set_main_option("sqlalchemy.url", f"sqlite:///{database_path}")
    command.upgrade(config, "20260822_0005")

    with engine.begin() as connection:
        connection.execute(
            text(
                "INSERT INTO cities "
                "(id, slug, name, subtitle, hero_image, latitude, longitude) "
                "VALUES ('city-test', 'test-city', '测试城市', '测试', 'cover.jpg', 0, 0)"
            )
        )
        for index, slug in enumerate(
            ("nantou-time-layers", "dameisha-remade-coast", "shanghai-old-quiz"),
            start=1,
        ):
            connection.execute(
                text(
                    "INSERT INTO routes "
                    "(id, city_id, slug, title, subtitle, description, duration_minutes, "
                    "distance_km, difficulty, theme, hero_image, is_featured, "
                    "content_status, published_at) "
                    "VALUES (:id, 'city-test', :slug, :slug, '副标题', '描述', 30, "
                    "1.0, '轻松', '历史', 'cover.jpg', 0, 'demo_unverified', "
                    "'2026-08-21 00:00:00')"
                ),
                {"id": f"route-{index}", "slug": slug},
            )
        connection.execute(
            text(
                "INSERT INTO routes "
                "(id, city_id, slug, title, subtitle, description, duration_minutes, "
                "distance_km, difficulty, theme, hero_image, is_featured, "
                "content_status, published_at) "
                "VALUES ('route-draft', 'city-test', 'offline-draft', '草稿', '副标题', "
                "'描述', 30, 1.0, '轻松', '历史', 'cover.jpg', 0, "
                "'demo_unverified', NULL)"
            )
        )

    command.upgrade(config, "head")

    with engine.begin() as connection:
        rows = dict(
            connection.execute(text("SELECT slug, content_status FROM routes ORDER BY slug")).all()
        )
    assert rows["nantou-time-layers"] == "published"
    assert rows["dameisha-remade-coast"] == "published"
    assert rows["shanghai-old-quiz"] == "published"
    assert rows["offline-draft"] == "in_review"


def test_traveler_library_migration_preserves_journey_and_evidence_rows(tmp_path):
    database_path = tmp_path / "traveler-library.db"
    engine = create_engine(f"sqlite:///{database_path}")
    config = Config(str(Path(__file__).parents[1] / "alembic.ini"))
    config.set_main_option("sqlalchemy.url", f"sqlite:///{database_path}")
    command.upgrade(config, "20260822_0007")

    with engine.begin() as connection:
        connection.execute(
            text(
                "INSERT INTO users (id, username, account_kind, is_active, auth_version, "
                "created_at, updated_at) VALUES ('history-user', 'history-user', "
                "'registered', 1, 1, '2026-08-23 00:00:00', '2026-08-23 00:00:00')"
            )
        )
        connection.execute(
            text(
                "INSERT INTO cities (id, slug, name, subtitle, hero_image, latitude, longitude) "
                "VALUES ('history-city', 'history-city', '历史城', '测试', 'cover.jpg', 0, 0)"
            )
        )
        connection.execute(
            text(
                "INSERT INTO routes (id, city_id, slug, title, subtitle, description, "
                "duration_minutes, distance_km, difficulty, theme, hero_image, is_featured, "
                "content_status, published_at) VALUES ('history-route', 'history-city', "
                "'history-route', '历史路线', '测试', '测试', 30, 1, '轻松', '历史', "
                "'cover.jpg', 0, 'published', '2026-08-23 00:00:00')"
            )
        )
        connection.execute(
            text(
                "INSERT INTO story_arcs (id, route_id, title, central_question, complete_story, "
                "causal_model_json, pronunciation_notes_json, script_version, review_state, "
                "field_audit_state) VALUES ('history-arc', 'history-route', '故事', '为何', "
                "'完整', '[]', '[]', 'v1', 'reviewed', 'reviewed')"
            )
        )
        connection.execute(
            text(
                "INSERT INTO story_fragments (id, arc_id, position, title, safe_preview, "
                "narration_script, transcript, audio_path, audio_mime_type, audio_size_bytes, "
                "script_version, interaction_type, completion_threshold, key_claim, "
                "answers_question, raises_question, authenticity_label, review_state) "
                "VALUES ('history-fragment', 'history-arc', 1, '线索', '预告', '旁白', '旁白', "
                "'audio/test.mp3', 'audio/mpeg', 10, 'v1', 'photo', 0.9, '主张', '回答', "
                "'问题', 'documented', 'reviewed')"
            )
        )
        connection.execute(
            text(
                "INSERT INTO photo_missions (id, fragment_id, prompt, field_subject, "
                "safety_copy, accessibility_alternative, authenticity_label, required, "
                "audit_state) VALUES ('history-mission', 'history-fragment', '拍摄', '建筑', "
                "'注意安全', '可以跳过', 'interpretive', 1, 'reviewed')"
            )
        )
        connection.execute(
            text(
                "INSERT INTO journeys (id, user_id, route_id, status, current_stop_position, "
                "started_at, updated_at) VALUES ('history-journey', 'history-user', "
                "'history-route', 'active', 1, '2026-08-23 00:00:00', "
                "'2026-08-23 00:00:00')"
            )
        )
        connection.execute(
            text(
                "INSERT INTO evidence (id, journey_id, mission_id, object_key, storage_provider, "
                "mime_type, size_bytes, sha256, width, height, uploaded_at, expires_at, "
                "idempotency_key) VALUES ('history-evidence', 'history-journey', "
                "'history-mission', 'private/history.jpg', 'local', 'image/jpeg', 10, "
                "'abc', 10, 10, '2026-08-23 00:00:00', '2026-09-23 00:00:00', 'retry-1')"
            )
        )

    command.upgrade(config, "head")
    inspector = inspect(engine)
    assert {"vantage_point", "shooting_direction", "composition_tip"} <= {
        column["name"] for column in inspector.get_columns("photo_missions")
    }
    assert {
        "ix_journeys_user_status_updated",
        "ix_journeys_user_route_status_completed",
    } <= {item["name"] for item in inspector.get_indexes("journeys")}
    with engine.begin() as connection:
        assert (
            connection.execute(
                text("SELECT status FROM journeys WHERE id = 'history-journey'")
            ).scalar_one()
            == "active"
        )
        assert (
            connection.execute(
                text("SELECT object_key FROM evidence WHERE id = 'history-evidence'")
            ).scalar_one()
            == "private/history.jpg"
        )

    command.downgrade(config, "20260822_0007")
    assert "vantage_point" not in {
        column["name"] for column in inspect(engine).get_columns("photo_missions")
    }
    with engine.begin() as connection:
        assert (
            connection.execute(
                text("SELECT COUNT(*) FROM journeys WHERE id = 'history-journey'")
            ).scalar_one()
            == 1
        )
        assert (
            connection.execute(
                text("SELECT COUNT(*) FROM evidence WHERE id = 'history-evidence'")
            ).scalar_one()
            == 1
        )

    command.upgrade(config, "head")
    with engine.begin() as connection:
        version = connection.execute(text("SELECT version_num FROM alembic_version")).scalar_one()
        assert version == "20260823_0013"


def test_scenic_point_tag_migration_backfills_and_round_trips(tmp_path):
    database_path = tmp_path / "scenic-point-tags.db"
    engine = create_engine(f"sqlite:///{database_path}")
    config = Config(str(Path(__file__).parents[1] / "alembic.ini"))
    config.set_main_option("sqlalchemy.url", f"sqlite:///{database_path}")

    command.upgrade(config, "20260823_0011")
    command.upgrade(config, "head")

    inspector = inspect(engine)
    assert "experience_tags_json" in {column["name"] for column in inspector.get_columns("stops")}
    assert "experience_tags_json" in {
        column["name"] for column in inspector.get_columns("story_fragments")
    }

    command.downgrade(config, "20260823_0011")
    inspector = inspect(engine)
    assert "experience_tags_json" not in {
        column["name"] for column in inspector.get_columns("stops")
    }
    assert "experience_tags_json" not in {
        column["name"] for column in inspector.get_columns("story_fragments")
    }

    command.upgrade(config, "head")
    with engine.begin() as connection:
        version = connection.execute(text("SELECT version_num FROM alembic_version")).scalar_one()
    assert version == "20260823_0013"


def test_node_community_migration_round_trips_without_touching_existing_data(tmp_path):
    database_path = tmp_path / "node-community.db"
    engine = create_engine(f"sqlite:///{database_path}")
    config = Config(str(Path(__file__).parents[1] / "alembic.ini"))
    config.set_main_option("sqlalchemy.url", f"sqlite:///{database_path}")

    command.upgrade(config, "20260823_0008")
    with engine.begin() as connection:
        before = {
            table: connection.execute(text(f"SELECT COUNT(*) FROM {table}")).scalar_one()
            for table in ("users", "journeys", "story_fragments", "evidence")
        }

    command.upgrade(config, "head")
    community_tables = {
        "community_posts",
        "community_media",
        "community_post_likes",
        "community_comments",
        "community_reports",
        "home_story_publications",
        "story_narration_tracks",
    }
    assert community_tables <= set(inspect(engine).get_table_names())
    assert {"root_comment_id", "reply_to_comment_id"} <= {
        column["name"] for column in inspect(engine).get_columns("community_comments")
    }

    command.downgrade(config, "20260823_0008")
    assert community_tables.isdisjoint(inspect(engine).get_table_names())
    with engine.begin() as connection:
        after = {
            table: connection.execute(text(f"SELECT COUNT(*) FROM {table}")).scalar_one()
            for table in ("users", "journeys", "story_fragments", "evidence")
        }
    assert after == before
