"""Add private city footprint entries and durable photos.

Revision ID: 20260823_0014
Revises: 20260823_0013
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "20260823_0014"
down_revision = "20260823_0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    existing_fragment_columns = {
        column["name"] for column in sa.inspect(op.get_bind()).get_columns("story_fragments")
    }
    if "footprint_editorial_summary" not in existing_fragment_columns:
        op.add_column(
            "story_fragments",
            sa.Column("footprint_editorial_summary", sa.Text(), nullable=True),
        )
    if "footprint_summary_options_json" not in existing_fragment_columns:
        op.add_column(
            "story_fragments",
            sa.Column("footprint_summary_options_json", sa.JSON(), nullable=True),
        )

    op.create_table(
        "footprint_entries",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("journey_id", sa.String(36), sa.ForeignKey("journeys.id"), nullable=False),
        sa.Column("source_kind", sa.String(30), nullable=False),
        sa.Column("source_id", sa.String(36), nullable=False),
        sa.Column("city_id", sa.String(36), sa.ForeignKey("cities.id"), nullable=False),
        sa.Column("city_slug", sa.String(80), nullable=False),
        sa.Column("city_name", sa.String(80), nullable=False),
        sa.Column("scene_id", sa.String(36), nullable=False),
        sa.Column("scene_title", sa.String(160), nullable=False),
        sa.Column("story_title", sa.String(255), nullable=False),
        sa.Column("editorial_summary", sa.Text(), nullable=False),
        sa.Column("source_revision", sa.String(80), nullable=True),
        sa.Column("summary_options_json", sa.JSON(), nullable=False),
        sa.Column("themes_json", sa.JSON(), nullable=False),
        sa.Column("selected_summary_id", sa.String(80), nullable=True),
        sa.Column("selected_summary_text", sa.String(160), nullable=True),
        sa.Column("user_observation", sa.String(280), nullable=True),
        sa.Column("user_sentence", sa.String(160), nullable=True),
        sa.Column("organization_state", sa.String(20), nullable=False, server_default="draft"),
        sa.Column("journey_completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint(
            "user_id", "journey_id", "source_kind", "source_id", name="uq_footprint_source"
        ),
    )
    op.create_index("ix_footprint_entries_user_id", "footprint_entries", ["user_id"])
    op.create_index("ix_footprint_entries_journey_id", "footprint_entries", ["journey_id"])
    op.create_index("ix_footprint_entries_source_id", "footprint_entries", ["source_id"])
    op.create_index("ix_footprint_entries_city_id", "footprint_entries", ["city_id"])
    op.create_index("ix_footprint_entries_city_slug", "footprint_entries", ["city_slug"])
    op.create_index(
        "ix_footprint_entries_organization_state", "footprint_entries", ["organization_state"]
    )

    op.create_table(
        "footprint_themes",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "footprint_id",
            sa.String(36),
            sa.ForeignKey("footprint_entries.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("theme", sa.String(80), nullable=False),
        sa.UniqueConstraint("footprint_id", "theme", name="uq_footprint_theme"),
    )
    op.create_index("ix_footprint_themes_footprint_id", "footprint_themes", ["footprint_id"])
    op.create_index("ix_footprint_themes_user_id", "footprint_themes", ["user_id"])
    op.create_index("ix_footprint_themes_theme", "footprint_themes", ["theme"])
    op.create_index(
        "ix_footprint_themes_user_theme",
        "footprint_themes",
        ["user_id", "theme", "footprint_id"],
    )
    op.create_index(
        "ix_footprints_user_created", "footprint_entries", ["user_id", "created_at", "id"]
    )
    op.create_index(
        "ix_footprints_user_city_created",
        "footprint_entries",
        ["user_id", "city_slug", "created_at"],
    )
    op.create_index(
        "ix_footprints_user_journey_state",
        "footprint_entries",
        ["user_id", "journey_id", "organization_state"],
    )

    op.create_table(
        "footprint_photos",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "footprint_id",
            sa.String(36),
            sa.ForeignKey("footprint_entries.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column("object_key", sa.String(500), nullable=False, unique=True),
        sa.Column("storage_provider", sa.String(20), nullable=False, server_default="local"),
        sa.Column("canonical_reference", sa.String(1000), nullable=True),
        sa.Column("mime_type", sa.String(80), nullable=False),
        sa.Column("size_bytes", sa.Integer(), nullable=False),
        sa.Column("sha256", sa.String(64), nullable=False),
        sa.Column("width", sa.Integer(), nullable=False),
        sa.Column("height", sa.Integer(), nullable=False),
        sa.Column("idempotency_key", sa.String(80), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_footprint_photos_footprint_id", "footprint_photos", ["footprint_id"])


def downgrade() -> None:
    op.drop_index("ix_footprint_photos_footprint_id", table_name="footprint_photos")
    op.drop_table("footprint_photos")
    op.drop_index("ix_footprint_themes_user_theme", table_name="footprint_themes")
    op.drop_index("ix_footprint_themes_theme", table_name="footprint_themes")
    op.drop_index("ix_footprint_themes_user_id", table_name="footprint_themes")
    op.drop_index("ix_footprint_themes_footprint_id", table_name="footprint_themes")
    op.drop_table("footprint_themes")
    op.drop_index("ix_footprints_user_journey_state", table_name="footprint_entries")
    op.drop_index("ix_footprints_user_city_created", table_name="footprint_entries")
    op.drop_index("ix_footprints_user_created", table_name="footprint_entries")
    op.drop_index("ix_footprint_entries_organization_state", table_name="footprint_entries")
    op.drop_index("ix_footprint_entries_city_slug", table_name="footprint_entries")
    op.drop_index("ix_footprint_entries_city_id", table_name="footprint_entries")
    op.drop_index("ix_footprint_entries_source_id", table_name="footprint_entries")
    op.drop_index("ix_footprint_entries_journey_id", table_name="footprint_entries")
    op.drop_index("ix_footprint_entries_user_id", table_name="footprint_entries")
    op.drop_table("footprint_entries")
    existing_fragment_columns = {
        column["name"] for column in sa.inspect(op.get_bind()).get_columns("story_fragments")
    }
    if "footprint_summary_options_json" in existing_fragment_columns:
        op.drop_column("story_fragments", "footprint_summary_options_json")
    if "footprint_editorial_summary" in existing_fragment_columns:
        op.drop_column("story_fragments", "footprint_editorial_summary")
