"""Add threaded comments and curated home story listening.

Revision ID: 20260823_0010
Revises: 20260823_0009
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "20260823_0010"
down_revision = "20260823_0009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("community_comments") as batch:
        batch.add_column(sa.Column("root_comment_id", sa.String(36), nullable=True))
        batch.add_column(sa.Column("reply_to_comment_id", sa.String(36), nullable=True))
        batch.create_foreign_key(
            "fk_community_comment_root",
            "community_comments",
            ["root_comment_id"],
            ["id"],
            ondelete="RESTRICT",
        )
        batch.create_foreign_key(
            "fk_community_comment_reply_to",
            "community_comments",
            ["reply_to_comment_id"],
            ["id"],
            ondelete="RESTRICT",
        )
    op.create_index(
        "ix_community_comments_thread_created",
        "community_comments",
        ["post_id", "root_comment_id", "status", "created_at", "id"],
    )
    op.create_index(
        "ix_community_comments_root_comment_id", "community_comments", ["root_comment_id"]
    )
    op.create_index(
        "ix_community_comments_reply_to_comment_id",
        "community_comments",
        ["reply_to_comment_id"],
    )

    op.create_table(
        "story_narration_tracks",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("arc_id", sa.String(36), sa.ForeignKey("story_arcs.id"), nullable=False),
        sa.Column(
            "profile_id",
            sa.String(36),
            sa.ForeignKey("narration_voice_profiles.id"),
            nullable=False,
        ),
        sa.Column("transcript_hash", sa.String(64), nullable=False),
        sa.Column("script_version", sa.String(40), nullable=False),
        sa.Column("media_path", sa.String(500), nullable=False),
        sa.Column("mime_type", sa.String(80), nullable=False, server_default="audio/mpeg"),
        sa.Column("size_bytes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("duration_ms", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("checksum_sha256", sa.String(64), nullable=True),
        sa.Column("generation_metadata_json", sa.JSON(), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="draft"),
        sa.Column("reviewed_by", sa.String(120), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint(
            "arc_id",
            "profile_id",
            "transcript_hash",
            "script_version",
            name="uq_story_voice_script",
        ),
    )
    op.create_index("ix_story_narration_tracks_arc_id", "story_narration_tracks", ["arc_id"])
    op.create_index(
        "ix_story_narration_tracks_profile_id", "story_narration_tracks", ["profile_id"]
    )
    op.create_index(
        "ix_story_narration_tracks_hash_status",
        "story_narration_tracks",
        ["transcript_hash", "status"],
    )

    op.create_table(
        "home_story_publications",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "arc_id", sa.String(36), sa.ForeignKey("story_arcs.id"), nullable=False, unique=True
        ),
        sa.Column(
            "selected_track_id",
            sa.String(36),
            sa.ForeignKey("story_narration_tracks.id"),
            nullable=True,
        ),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("introduction", sa.Text(), nullable=False),
        sa.Column("cover_image", sa.String(500), nullable=False),
        sa.Column("selection_weight", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("status", sa.String(20), nullable=False, server_default="draft"),
        sa.Column("reviewed_by", sa.String(120), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        "ix_home_story_publications_status_weight",
        "home_story_publications",
        ["status", "selection_weight", "published_at"],
    )
    op.create_index(
        "ix_home_story_publications_selected_track_id",
        "home_story_publications",
        ["selected_track_id"],
    )


def downgrade() -> None:
    op.drop_table("home_story_publications")
    op.drop_table("story_narration_tracks")
    op.drop_index("ix_community_comments_reply_to_comment_id", table_name="community_comments")
    op.drop_index("ix_community_comments_root_comment_id", table_name="community_comments")
    op.drop_index("ix_community_comments_thread_created", table_name="community_comments")
    with op.batch_alter_table("community_comments") as batch:
        batch.drop_constraint("fk_community_comment_reply_to", type_="foreignkey")
        batch.drop_constraint("fk_community_comment_root", type_="foreignkey")
        batch.drop_column("reply_to_comment_id")
        batch.drop_column("root_comment_id")
