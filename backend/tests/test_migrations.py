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

    columns = {
        column["name"]
        for column in inspect(engine).get_columns("historical_claims")
    }
    assert {"reviewed_by", "reviewed_at"}.issubset(columns)

    with engine.begin() as connection:
        version = connection.execute(text("SELECT version_num FROM alembic_version")).scalar_one()
    assert version == "20260822_0004"
