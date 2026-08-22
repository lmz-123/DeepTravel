from __future__ import annotations

from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect, text


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
    assert version == "20260822_0006"


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
