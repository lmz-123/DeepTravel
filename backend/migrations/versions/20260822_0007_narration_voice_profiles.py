"""Add traveler-selectable narration voice profiles and fragment tracks.

Revision ID: 20260822_0007
Revises: 20260822_0006
"""

from __future__ import annotations

import hashlib
from datetime import UTC, datetime
from uuid import NAMESPACE_URL, uuid5

import sqlalchemy as sa
from alembic import op

revision = "20260822_0007"
down_revision = "20260822_0006"
branch_labels = None
depends_on = None

DEFAULT_PROFILE_ID = "default-narration-voice"


def upgrade() -> None:
    bind = op.get_bind()
    tables = set(sa.inspect(bind).get_table_names())
    if "narration_voice_profiles" not in tables:
        op.create_table(
            "narration_voice_profiles",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("slug", sa.String(80), nullable=False, unique=True),
            sa.Column("display_name", sa.String(120), nullable=False),
            sa.Column("description", sa.String(500), nullable=False, server_default=""),
            sa.Column("provider", sa.String(40), nullable=False),
            sa.Column("model", sa.String(80), nullable=False),
            sa.Column("voice_id", sa.String(120), nullable=False),
            sa.Column("emotion", sa.String(40), nullable=False, server_default="neutral"),
            sa.Column("speed", sa.Float(), nullable=False, server_default="1"),
            sa.Column("pitch", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("preview_media_path", sa.String(500), nullable=True),
            sa.Column("display_order", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("status", sa.String(20), nullable=False, server_default="draft"),
            sa.Column("is_default", sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
        )
        op.create_index("ix_narration_voice_profiles_slug", "narration_voice_profiles", ["slug"], unique=True)
        op.create_index("ix_narration_voice_profiles_status", "narration_voice_profiles", ["status"])
        op.create_index("ix_narration_voice_profiles_is_default", "narration_voice_profiles", ["is_default"])
    if "fragment_narration_tracks" not in tables:
        op.create_table(
            "fragment_narration_tracks",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("fragment_id", sa.String(36), sa.ForeignKey("story_fragments.id"), nullable=False),
            sa.Column("profile_id", sa.String(36), sa.ForeignKey("narration_voice_profiles.id"), nullable=False),
            sa.Column("transcript_hash", sa.String(64), nullable=False),
            sa.Column("script_version", sa.String(40), nullable=False),
            sa.Column("media_path", sa.String(500), nullable=False),
            sa.Column("mime_type", sa.String(80), nullable=False, server_default="audio/mpeg"),
            sa.Column("size_bytes", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("checksum_sha256", sa.String(64), nullable=True),
            sa.Column("generation_metadata_json", sa.JSON(), nullable=False),
            sa.Column("approved_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
            sa.UniqueConstraint(
                "fragment_id",
                "profile_id",
                "transcript_hash",
                "script_version",
                name="uq_fragment_voice_script",
            ),
        )
        op.create_index("ix_fragment_narration_tracks_fragment_id", "fragment_narration_tracks", ["fragment_id"])
        op.create_index("ix_fragment_narration_tracks_profile_id", "fragment_narration_tracks", ["profile_id"])
        op.create_index("ix_fragment_narration_tracks_transcript_hash", "fragment_narration_tracks", ["transcript_hash"])
    preview_columns = {item["name"] for item in sa.inspect(bind).get_columns("narration_previews")}
    if "profile_id" not in preview_columns:
        with op.batch_alter_table("narration_previews") as batch:
            batch.add_column(sa.Column("profile_id", sa.String(36), nullable=True))
            batch.create_foreign_key(
                "fk_narration_previews_profile_id",
                "narration_voice_profiles",
                ["profile_id"],
                ["id"],
            )
            batch.create_index("ix_narration_previews_profile_id", ["profile_id"])
    _backfill_default_profile_and_tracks(bind)


def downgrade() -> None:
    bind = op.get_bind()
    if "narration_previews" in set(sa.inspect(bind).get_table_names()):
        columns = {item["name"] for item in sa.inspect(bind).get_columns("narration_previews")}
        if "profile_id" in columns:
            if bind.dialect.name == "sqlite":
                with op.batch_alter_table("narration_previews") as batch:
                    batch.drop_index("ix_narration_previews_profile_id")
                    batch.drop_constraint(
                        "fk_narration_previews_profile_id", type_="foreignkey"
                    )
                    batch.drop_column("profile_id")
            else:
                op.drop_constraint(
                    "fk_narration_previews_profile_id",
                    "narration_previews",
                    type_="foreignkey",
                )
                op.drop_index(
                    "ix_narration_previews_profile_id",
                    table_name="narration_previews",
                )
                op.drop_column("narration_previews", "profile_id")
    tables = set(sa.inspect(bind).get_table_names())
    if "fragment_narration_tracks" in tables:
        op.drop_table("fragment_narration_tracks")
    if "narration_voice_profiles" in tables:
        op.drop_table("narration_voice_profiles")


def _backfill_default_profile_and_tracks(bind) -> None:
    metadata = sa.MetaData()
    profiles = sa.Table("narration_voice_profiles", metadata, autoload_with=bind)
    tracks = sa.Table("fragment_narration_tracks", metadata, autoload_with=bind)
    fragments = sa.Table("story_fragments", metadata, autoload_with=bind)
    now = datetime.now(UTC)
    existing_profile = bind.execute(
        sa.select(profiles.c.id).where(profiles.c.id == DEFAULT_PROFILE_ID)
    ).first()
    if existing_profile is None:
        bind.execute(
            profiles.insert().values(
                id=DEFAULT_PROFILE_ID,
                slug="default",
                display_name="原声导览",
                description="路线编辑审核通过的默认旁白",
                provider="legacy",
                model="approved-audio",
                voice_id="default",
                emotion="neutral",
                speed=1.0,
                pitch=0,
                display_order=0,
                status="published",
                is_default=True,
                created_at=now,
                updated_at=now,
                published_at=now,
            )
        )
    rows = bind.execute(
        sa.select(
            fragments.c.id,
            fragments.c.narration_script,
            fragments.c.transcript,
            fragments.c.audio_path,
            fragments.c.audio_mime_type,
            fragments.c.audio_size_bytes,
            fragments.c.script_version,
        )
    ).mappings()
    for row in rows:
        media_path = str(row["audio_path"] or "")
        if not media_path:
            continue
        transcript = str(row["narration_script"] or row["transcript"] or "").strip()
        transcript_hash = hashlib.sha256(transcript.encode()).hexdigest()
        track_id = str(
            uuid5(
                NAMESPACE_URL,
                f"jiandi:narration-track:{row['id']}:{DEFAULT_PROFILE_ID}:{transcript_hash}:{row['script_version']}",
            )
        )
        exists = bind.execute(sa.select(tracks.c.id).where(tracks.c.id == track_id)).first()
        if exists is not None:
            continue
        bind.execute(
            tracks.insert().values(
                id=track_id,
                fragment_id=row["id"],
                profile_id=DEFAULT_PROFILE_ID,
                transcript_hash=transcript_hash,
                script_version=row["script_version"],
                media_path=media_path,
                mime_type=row["audio_mime_type"] or "audio/mpeg",
                size_bytes=row["audio_size_bytes"] or 0,
                generation_metadata_json={"backfilled": True},
                approved_at=now,
                published_at=now,
            )
        )
