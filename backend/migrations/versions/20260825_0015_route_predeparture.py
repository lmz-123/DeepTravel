"""Add versioned scenic pre-departure introductions and tracks.

Revision ID: 20260825_0015
Revises: 20260823_0014
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "20260825_0015"
down_revision = "20260823_0014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "route_pretrip_guidance",
        sa.Column("introduction_text", sa.Text(), nullable=True),
    )
    op.add_column(
        "route_pretrip_guidance",
        sa.Column("introduction_transcript_hash", sa.String(64), nullable=True),
    )
    op.add_column(
        "route_pretrip_guidance",
        sa.Column("introduction_script_version", sa.String(40), nullable=True),
    )
    op.add_column(
        "route_pretrip_guidance",
        sa.Column("selected_intro_track_id", sa.String(36), nullable=True),
    )
    op.create_index(
        "ix_route_pretrip_selected_intro_track",
        "route_pretrip_guidance",
        ["selected_intro_track_id"],
    )
    op.create_table(
        "route_predeparture_tracks",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "route_id",
            sa.String(36),
            sa.ForeignKey("routes.id", ondelete="CASCADE"),
            nullable=False,
        ),
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
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint(
            "route_id",
            "profile_id",
            "transcript_hash",
            "script_version",
            name="uq_route_predeparture_voice_script",
        ),
    )
    op.create_index(
        "ix_route_predeparture_tracks_route_id", "route_predeparture_tracks", ["route_id"]
    )
    op.create_index(
        "ix_route_predeparture_tracks_profile_id",
        "route_predeparture_tracks",
        ["profile_id"],
    )
    op.create_index(
        "ix_route_predeparture_tracks_hash_status",
        "route_predeparture_tracks",
        ["transcript_hash", "status"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_route_predeparture_tracks_hash_status", table_name="route_predeparture_tracks"
    )
    op.drop_index("ix_route_predeparture_tracks_profile_id", table_name="route_predeparture_tracks")
    op.drop_index("ix_route_predeparture_tracks_route_id", table_name="route_predeparture_tracks")
    op.drop_table("route_predeparture_tracks")
    op.drop_index("ix_route_pretrip_selected_intro_track", table_name="route_pretrip_guidance")
    op.drop_column("route_pretrip_guidance", "selected_intro_track_id")
    op.drop_column("route_pretrip_guidance", "introduction_script_version")
    op.drop_column("route_pretrip_guidance", "introduction_transcript_hash")
    op.drop_column("route_pretrip_guidance", "introduction_text")
