"""Add fragment-scoped traveler community tables.

Revision ID: 20260823_0009
Revises: 20260823_0008
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "20260823_0009"
down_revision = "20260823_0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "community_posts",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "fragment_id", sa.String(36), sa.ForeignKey("story_fragments.id"), nullable=False
        ),
        sa.Column("author_user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("category", sa.String(40), nullable=False),
        sa.Column("title", sa.String(120), nullable=True),
        sa.Column("body", sa.Text(), nullable=False, server_default=""),
        sa.Column("status", sa.String(20), nullable=False, server_default="visible"),
        sa.Column("report_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("idempotency_key", sa.String(80), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("author_user_id", "idempotency_key", name="uq_community_post_retry"),
    )
    op.create_index("ix_community_posts_fragment_id", "community_posts", ["fragment_id"])
    op.create_index("ix_community_posts_author_user_id", "community_posts", ["author_user_id"])
    op.create_index("ix_community_posts_category", "community_posts", ["category"])
    op.create_index("ix_community_posts_status", "community_posts", ["status"])
    op.create_index("ix_community_posts_created_at", "community_posts", ["created_at"])
    op.create_index(
        "ix_community_posts_fragment_status_created",
        "community_posts",
        ["fragment_id", "status", "created_at", "id"],
    )

    op.create_table(
        "community_media",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "post_id",
            sa.String(36),
            sa.ForeignKey("community_posts.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("storage_provider", sa.String(20), nullable=False),
        sa.Column("object_key", sa.String(500), nullable=False, unique=True),
        sa.Column("canonical_reference", sa.String(1000), nullable=True),
        sa.Column("mime_type", sa.String(80), nullable=False),
        sa.Column("size_bytes", sa.Integer(), nullable=False),
        sa.Column("sha256", sa.String(64), nullable=False),
        sa.Column("width", sa.Integer(), nullable=False),
        sa.Column("height", sa.Integer(), nullable=False),
        sa.Column("source_kind", sa.String(30), nullable=False, server_default="upload"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("post_id", "position", name="uq_community_media_position"),
    )
    op.create_index("ix_community_media_post_id", "community_media", ["post_id"])

    op.create_table(
        "community_post_likes",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "post_id",
            sa.String(36),
            sa.ForeignKey("community_posts.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("post_id", "user_id", name="uq_community_post_like"),
    )
    op.create_index("ix_community_post_likes_post_id", "community_post_likes", ["post_id"])
    op.create_index("ix_community_post_likes_user_id", "community_post_likes", ["user_id"])
    op.create_index(
        "ix_community_likes_post_created", "community_post_likes", ["post_id", "created_at", "id"]
    )

    op.create_table(
        "community_comments",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "post_id",
            sa.String(36),
            sa.ForeignKey("community_posts.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("author_user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="visible"),
        sa.Column("report_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("idempotency_key", sa.String(80), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("author_user_id", "idempotency_key", name="uq_community_comment_retry"),
    )
    op.create_index("ix_community_comments_post_id", "community_comments", ["post_id"])
    op.create_index(
        "ix_community_comments_author_user_id", "community_comments", ["author_user_id"]
    )
    op.create_index("ix_community_comments_status", "community_comments", ["status"])
    op.create_index(
        "ix_community_comments_post_status_created",
        "community_comments",
        ["post_id", "status", "created_at", "id"],
    )

    op.create_table(
        "community_reports",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("reporter_user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("target_type", sa.String(20), nullable=False),
        sa.Column("target_id", sa.String(36), nullable=False),
        sa.Column("reason", sa.String(40), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint(
            "reporter_user_id", "target_type", "target_id", name="uq_community_report_target"
        ),
    )
    op.create_index(
        "ix_community_reports_reporter_user_id", "community_reports", ["reporter_user_id"]
    )
    op.create_index(
        "ix_community_reports_target", "community_reports", ["target_type", "target_id"]
    )


def downgrade() -> None:
    op.drop_table("community_reports")
    op.drop_table("community_comments")
    op.drop_table("community_post_likes")
    op.drop_table("community_media")
    op.drop_table("community_posts")
