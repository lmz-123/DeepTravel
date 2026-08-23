"""Add reusable city stories, pre-trip guidance, favorites, and import audit.

Revision ID: 20260823_0013
Revises: 20260823_0012
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "20260823_0013"
down_revision = "20260823_0012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "story_catalog_items",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("city_id", sa.String(36), sa.ForeignKey("cities.id"), nullable=False),
        sa.Column("source_kind", sa.String(30), nullable=False),
        sa.Column("source_id", sa.String(36), nullable=False),
        sa.Column("canonical_revision", sa.String(64), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False),
        sa.Column("cover_image", sa.String(500), nullable=False, server_default=""),
        sa.Column("district", sa.String(120), nullable=True),
        sa.Column("themes_json", sa.JSON(), nullable=False),
        sa.Column("point_ids_json", sa.JSON(), nullable=False),
        sa.Column("related_stories_json", sa.JSON(), nullable=False),
        sa.Column("content_type", sa.String(80), nullable=False),
        sa.Column("place_context", sa.Text(), nullable=False),
        sa.Column("observable_detail", sa.Text(), nullable=False),
        sa.Column("attention_hint", sa.Text(), nullable=True),
        sa.Column("sources_json", sa.JSON(), nullable=False),
        sa.Column("fact_status", sa.String(40), nullable=False, server_default="documented"),
        sa.Column("review_status", sa.String(40), nullable=False, server_default="in_review"),
        sa.Column("status", sa.String(20), nullable=False, server_default="draft"),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("reviewed_by", sa.String(120), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("source_kind", "source_id", name="uq_story_catalog_source"),
    )
    op.create_index("ix_story_catalog_items_city_id", "story_catalog_items", ["city_id"])
    op.create_index("ix_story_catalog_items_source_id", "story_catalog_items", ["source_id"])
    op.create_index("ix_story_catalog_items_status", "story_catalog_items", ["status"])
    op.create_index(
        "ix_story_catalog_city_status",
        "story_catalog_items",
        ["city_id", "status", "published_at"],
    )

    op.create_table(
        "story_catalog_variants",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "catalog_item_id",
            sa.String(36),
            sa.ForeignKey("story_catalog_items.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("role", sa.String(30), nullable=False),
        sa.Column("source_kind", sa.String(30), nullable=False),
        sa.Column("source_id", sa.String(36), nullable=False),
        sa.Column("track_kind", sa.String(30), nullable=False),
        sa.Column("track_id", sa.String(36), nullable=False),
        sa.Column("transcript_hash", sa.String(64), nullable=False),
        sa.Column("script_version", sa.String(40), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="draft"),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("catalog_item_id", "role", name="uq_story_catalog_variant_role"),
    )
    op.create_index(
        "ix_story_catalog_variants_catalog_item_id",
        "story_catalog_variants",
        ["catalog_item_id"],
    )
    op.create_index("ix_story_catalog_variants_source_id", "story_catalog_variants", ["source_id"])
    op.create_index("ix_story_catalog_variants_track_id", "story_catalog_variants", ["track_id"])
    op.create_index("ix_story_catalog_variants_status", "story_catalog_variants", ["status"])

    op.create_table(
        "story_placements",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "catalog_item_id",
            sa.String(36),
            sa.ForeignKey("story_catalog_items.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("channel", sa.String(30), nullable=False),
        sa.Column("module_key", sa.String(80), nullable=True),
        sa.Column("route_id", sa.String(36), sa.ForeignKey("routes.id"), nullable=True),
        sa.Column("variant_role", sa.String(30), nullable=False, server_default="short_preview"),
        sa.Column("display_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("weight", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("status", sa.String(20), nullable=False, server_default="draft"),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("ends_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint(
            "catalog_item_id",
            "channel",
            "module_key",
            "route_id",
            name="uq_story_catalog_placement",
        ),
    )
    op.create_index("ix_story_placements_catalog_item_id", "story_placements", ["catalog_item_id"])
    op.create_index("ix_story_placements_channel", "story_placements", ["channel"])
    op.create_index("ix_story_placements_module_key", "story_placements", ["module_key"])
    op.create_index("ix_story_placements_route_id", "story_placements", ["route_id"])
    op.create_index("ix_story_placements_status", "story_placements", ["status"])
    op.create_index(
        "ix_story_placement_public",
        "story_placements",
        ["channel", "module_key", "status"],
    )

    op.create_table(
        "route_pretrip_guidance",
        sa.Column("route_id", sa.String(36), sa.ForeignKey("routes.id"), primary_key=True),
        sa.Column(
            "theme_story_catalog_id",
            sa.String(36),
            sa.ForeignKey("story_catalog_items.id"),
            nullable=True,
        ),
        sa.Column("story_directions_json", sa.JSON(), nullable=False),
        sa.Column("companion_tags_json", sa.JSON(), nullable=False),
        sa.Column("safety_tips_json", sa.JSON(), nullable=False),
        sa.Column("rest_tips_json", sa.JSON(), nullable=False),
        sa.Column("accessibility_tips_json", sa.JSON(), nullable=False),
        sa.Column("weather_tips_json", sa.JSON(), nullable=False),
        sa.Column("offline_roles_json", sa.JSON(), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="draft"),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        "ix_route_pretrip_guidance_theme_story_catalog_id",
        "route_pretrip_guidance",
        ["theme_story_catalog_id"],
    )
    op.create_index("ix_route_pretrip_guidance_status", "route_pretrip_guidance", ["status"])

    op.create_table(
        "traveler_favorites",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("target_kind", sa.String(30), nullable=False),
        sa.Column("target_id", sa.String(120), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("user_id", "target_kind", "target_id", name="uq_traveler_favorite"),
    )
    op.create_index("ix_traveler_favorites_user_id", "traveler_favorites", ["user_id"])
    op.create_index(
        "ix_traveler_favorite_user_created", "traveler_favorites", ["user_id", "created_at"]
    )

    op.create_table(
        "content_import_previews",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("package_id", sa.String(120), nullable=False),
        sa.Column("package_version", sa.String(80), nullable=False),
        sa.Column("package_checksum", sa.String(64), nullable=False),
        sa.Column("editor_id", sa.String(120), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="ready"),
        sa.Column("plan_json", sa.JSON(), nullable=False),
        sa.Column("target_revisions_json", sa.JSON(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        "ix_content_import_previews_package_id", "content_import_previews", ["package_id"]
    )
    op.create_index(
        "ix_content_import_previews_editor_id", "content_import_previews", ["editor_id"]
    )
    op.create_index("ix_content_import_previews_status", "content_import_previews", ["status"])
    op.create_index(
        "ix_content_import_previews_expires_at", "content_import_previews", ["expires_at"]
    )
    op.create_index(
        "ix_content_import_preview_expiry", "content_import_previews", ["status", "expires_at"]
    )

    op.create_table(
        "content_import_batches",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("package_id", sa.String(120), nullable=False),
        sa.Column("package_version", sa.String(80), nullable=False),
        sa.Column("package_checksum", sa.String(64), nullable=False),
        sa.Column("editor_id", sa.String(120), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="completed"),
        sa.Column("result_json", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint(
            "package_id", "package_version", name="uq_content_import_package_version"
        ),
    )
    op.create_index(
        "ix_content_import_batches_package_id", "content_import_batches", ["package_id"]
    )
    op.create_index("ix_content_import_batches_editor_id", "content_import_batches", ["editor_id"])
    op.create_index("ix_content_import_batches_status", "content_import_batches", ["status"])


def downgrade() -> None:
    op.drop_table("content_import_batches")
    op.drop_table("content_import_previews")
    op.drop_table("traveler_favorites")
    op.drop_table("route_pretrip_guidance")
    op.drop_table("story_placements")
    op.drop_table("story_catalog_variants")
    op.drop_table("story_catalog_items")
