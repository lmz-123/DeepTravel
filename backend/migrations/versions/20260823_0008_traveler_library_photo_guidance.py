"""Add traveler-library indexes and optional photo guidance.

Revision ID: 20260823_0008
Revises: 20260822_0007
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "20260823_0008"
down_revision = "20260822_0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    photo_columns = {
        column["name"] for column in sa.inspect(bind).get_columns("photo_missions")
    }
    with op.batch_alter_table("photo_missions") as batch:
        if "vantage_point" not in photo_columns:
            batch.add_column(sa.Column("vantage_point", sa.Text(), nullable=True))
        if "shooting_direction" not in photo_columns:
            batch.add_column(sa.Column("shooting_direction", sa.Text(), nullable=True))
        if "composition_tip" not in photo_columns:
            batch.add_column(sa.Column("composition_tip", sa.Text(), nullable=True))

    indexes = {item["name"] for item in sa.inspect(bind).get_indexes("journeys")}
    if "ix_journeys_user_status_updated" not in indexes:
        op.create_index(
            "ix_journeys_user_status_updated",
            "journeys",
            ["user_id", "status", "updated_at"],
        )
    if "ix_journeys_user_route_status_completed" not in indexes:
        op.create_index(
            "ix_journeys_user_route_status_completed",
            "journeys",
            ["user_id", "route_id", "status", "completed_at"],
        )


def downgrade() -> None:
    bind = op.get_bind()
    indexes = {item["name"] for item in sa.inspect(bind).get_indexes("journeys")}
    if "ix_journeys_user_route_status_completed" in indexes:
        op.drop_index(
            "ix_journeys_user_route_status_completed", table_name="journeys"
        )
    if "ix_journeys_user_status_updated" in indexes:
        op.drop_index("ix_journeys_user_status_updated", table_name="journeys")

    photo_columns = {
        column["name"] for column in sa.inspect(bind).get_columns("photo_missions")
    }
    with op.batch_alter_table("photo_missions") as batch:
        for name in ("composition_tip", "shooting_direction", "vantage_point"):
            if name in photo_columns:
                batch.drop_column(name)
