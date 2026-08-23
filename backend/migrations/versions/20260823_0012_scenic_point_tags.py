"""Add backend-configured experience tags to scenic point records.

Revision ID: 20260823_0012
Revises: 20260823_0011
"""

from __future__ import annotations

import json

import sqlalchemy as sa
from alembic import op

revision = "20260823_0012"
down_revision = "20260823_0011"
branch_labels = None
depends_on = None


_POINT_TABLES = ("stops", "story_fragments")


def upgrade() -> None:
    bind = op.get_bind()
    for table_name in _POINT_TABLES:
        columns = {
            column["name"]: column
            for column in sa.inspect(bind).get_columns(table_name)
        }
        if "experience_tags_json" not in columns:
            op.add_column(
                table_name,
                sa.Column("experience_tags_json", sa.JSON(), nullable=True),
            )
        bind.execute(
            sa.text(
                f"UPDATE {table_name} "
                "SET experience_tags_json = :empty "
                "WHERE experience_tags_json IS NULL"
            ),
            {"empty": json.dumps([], ensure_ascii=False)},
        )
        current = next(
            column
            for column in sa.inspect(bind).get_columns(table_name)
            if column["name"] == "experience_tags_json"
        )
        if current["nullable"]:
            with op.batch_alter_table(table_name) as batch:
                batch.alter_column(
                    "experience_tags_json",
                    existing_type=sa.JSON(),
                    nullable=False,
                )


def downgrade() -> None:
    bind = op.get_bind()
    for table_name in reversed(_POINT_TABLES):
        columns = {
            column["name"] for column in sa.inspect(bind).get_columns(table_name)
        }
        if "experience_tags_json" in columns:
            op.drop_column(table_name, "experience_tags_json")
