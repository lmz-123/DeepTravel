"""Add account ownership, cloud media metadata, narration previews, and lifecycle states.

Revision ID: 20260822_0006
Revises: 20260822_0005
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import NAMESPACE_URL, uuid5

import sqlalchemy as sa
from alembic import op

revision = "20260822_0006"
down_revision = "20260822_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())
    if "users" not in tables:
        op.create_table(
            "users",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("username", sa.String(80), nullable=True),
            sa.Column("password_hash", sa.String(255), nullable=True),
            sa.Column("account_kind", sa.String(20), nullable=False, server_default="registered"),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("auth_version", sa.Integer(), nullable=False, server_default="1"),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.UniqueConstraint("username", name="uq_users_username"),
        )
        op.create_index("ix_users_username", "users", ["username"], unique=True)
        op.create_index("ix_users_account_kind", "users", ["account_kind"], unique=False)

    _add_fk_column("guest_sessions", sa.Column("user_id", sa.String(36)), "users.id")
    _add_fk_column("journeys", sa.Column("user_id", sa.String(36)), "users.id")
    _backfill_legacy_users(bind)

    with op.batch_alter_table("guest_sessions") as batch:
        batch.alter_column("user_id", existing_type=sa.String(36), nullable=False)
    with op.batch_alter_table("journeys") as batch:
        batch.alter_column("user_id", existing_type=sa.String(36), nullable=False)
        batch.alter_column("guest_session_id", existing_type=sa.String(36), nullable=True)
    _create_index_if_missing("guest_sessions", "ix_guest_sessions_user_id", ["user_id"])
    _create_index_if_missing("journeys", "ix_journeys_user_id", ["user_id"])

    _add_column("media_assets", sa.Column("storage_provider", sa.String(20), nullable=False, server_default="local"))
    _add_column("media_assets", sa.Column("object_key", sa.String(500), nullable=True))
    _add_column("media_assets", sa.Column("canonical_url", sa.String(1000), nullable=True))
    _add_column("media_assets", sa.Column("visibility", sa.String(20), nullable=False, server_default="public"))
    _add_column("media_assets", sa.Column("size_bytes", sa.Integer(), nullable=True))
    _add_column("media_assets", sa.Column("checksum_sha256", sa.String(64), nullable=True))
    _add_column("media_assets", sa.Column("metadata_json", sa.JSON(), nullable=True))
    bind.execute(
        sa.text("UPDATE media_assets SET metadata_json = :empty WHERE metadata_json IS NULL"),
        {"empty": "{}"},
    )
    with op.batch_alter_table("media_assets") as batch:
        batch.alter_column(
            "metadata_json", existing_type=sa.JSON(), nullable=False
        )
    _create_index_if_missing("media_assets", "ix_media_assets_object_key", ["object_key"])

    _add_column("evidence", sa.Column("storage_provider", sa.String(20), nullable=False, server_default="local"))
    _add_column("evidence", sa.Column("canonical_reference", sa.String(1000), nullable=True))

    if "narration_previews" not in set(sa.inspect(bind).get_table_names()):
        op.create_table(
            "narration_previews",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("fragment_id", sa.String(36), sa.ForeignKey("story_fragments.id"), nullable=False),
            sa.Column("transcript_hash", sa.String(64), nullable=False),
            sa.Column("provider", sa.String(40), nullable=False),
            sa.Column("model", sa.String(80), nullable=False),
            sa.Column("voice_id", sa.String(120), nullable=False),
            sa.Column("emotion", sa.String(40), nullable=False, server_default="calm"),
            sa.Column("speed", sa.Float(), nullable=False, server_default="1"),
            sa.Column("pitch", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("pronunciation_json", sa.JSON(), nullable=False),
            sa.Column("object_key", sa.String(500), nullable=True),
            sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
            sa.Column("error_code", sa.String(80), nullable=True),
            sa.Column("metadata_json", sa.JSON(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("approved_at", sa.DateTime(timezone=True), nullable=True),
        )
        op.create_index("ix_narration_previews_fragment_id", "narration_previews", ["fragment_id"])
        op.create_index("ix_narration_previews_transcript_hash", "narration_previews", ["transcript_hash"])
        op.create_index("ix_narration_previews_status", "narration_previews", ["status"])
        op.create_index("ix_narration_previews_expires_at", "narration_previews", ["expires_at"])

    bind.execute(
        sa.text(
            "UPDATE routes SET content_status = 'published' "
            "WHERE published_at IS NOT NULL AND content_status <> 'archived'"
        )
    )
    # Normalize statuses emitted by earlier admin builds without accidentally
    # publishing timestamp-free editorial rows.
    bind.execute(
        sa.text(
            "UPDATE routes SET content_status = 'in_review' "
            "WHERE published_at IS NULL "
            "AND content_status IN ('review', 'demo_unverified')"
        )
    )
    _create_index_if_missing(
        "routes", "ix_routes_publication_visibility", ["content_status", "published_at"]
    )


def downgrade() -> None:
    bind = op.get_bind()
    _restore_guest_sessions_for_registered_journeys(bind)
    _drop_index_if_present("routes", "ix_routes_publication_visibility")
    if "narration_previews" in set(sa.inspect(bind).get_table_names()):
        op.drop_table("narration_previews")

    _drop_column("evidence", "canonical_reference")
    _drop_column("evidence", "storage_provider")
    _drop_index_if_present("media_assets", "ix_media_assets_object_key")
    for name in (
        "metadata_json",
        "checksum_sha256",
        "size_bytes",
        "visibility",
        "canonical_url",
        "object_key",
        "storage_provider",
    ):
        _drop_column("media_assets", name)

    _drop_fk_if_present("journeys", "fk_journeys_user_id_users")
    _drop_fk_if_present("guest_sessions", "fk_guest_sessions_user_id_users")
    _drop_index_if_present("journeys", "ix_journeys_user_id")
    _drop_index_if_present("guest_sessions", "ix_guest_sessions_user_id")
    with op.batch_alter_table("journeys") as batch:
        batch.alter_column("guest_session_id", existing_type=sa.String(36), nullable=False)
        batch.drop_column("user_id")
    with op.batch_alter_table("guest_sessions") as batch:
        batch.drop_column("user_id")
    if "users" in set(sa.inspect(bind).get_table_names()):
        op.drop_table("users")


def _backfill_legacy_users(bind) -> None:
    now = datetime.now(UTC)
    rows = bind.execute(sa.text("SELECT id FROM guest_sessions")).mappings().all()
    for row in rows:
        session_id = str(row["id"])
        user_id = str(uuid5(NAMESPACE_URL, f"jiandi:legacy-user:{session_id}"))
        exists = bind.execute(
            sa.text("SELECT id FROM users WHERE id = :id"), {"id": user_id}
        ).first()
        if exists is None:
            bind.execute(
                sa.text(
                    "INSERT INTO users "
                    "(id, username, password_hash, account_kind, is_active, auth_version, created_at, updated_at) "
                    "VALUES (:id, NULL, NULL, 'legacy', :active, 1, :created_at, :updated_at)"
                ),
                {"id": user_id, "active": True, "created_at": now, "updated_at": now},
            )
        bind.execute(
            sa.text("UPDATE guest_sessions SET user_id = :user_id WHERE id = :session_id"),
            {"user_id": user_id, "session_id": session_id},
        )
        bind.execute(
            sa.text(
                "UPDATE journeys SET user_id = :user_id "
                "WHERE guest_session_id = :session_id"
            ),
            {"user_id": user_id, "session_id": session_id},
        )


def _restore_guest_sessions_for_registered_journeys(bind) -> None:
    now = datetime.now(UTC)
    expires_at = now + timedelta(days=3650)
    user_ids = bind.execute(
        sa.text("SELECT DISTINCT user_id FROM journeys WHERE guest_session_id IS NULL")
    ).scalars().all()
    for user_id in user_ids:
        session_id = str(uuid5(NAMESPACE_URL, f"jiandi:downgrade-session:{user_id}"))
        exists = bind.execute(
            sa.text("SELECT id FROM guest_sessions WHERE id = :id"), {"id": session_id}
        ).first()
        if exists is None:
            bind.execute(
                sa.text(
                    "INSERT INTO guest_sessions (id, user_id, created_at, expires_at) "
                    "VALUES (:id, :user_id, :created_at, :expires_at)"
                ),
                {
                    "id": session_id,
                    "user_id": user_id,
                    "created_at": now,
                    "expires_at": expires_at,
                },
            )
        bind.execute(
            sa.text(
                "UPDATE journeys SET guest_session_id = :session_id "
                "WHERE user_id = :user_id AND guest_session_id IS NULL"
            ),
            {"session_id": session_id, "user_id": user_id},
        )


def _add_fk_column(table_name: str, column: sa.Column, target: str) -> None:
    if column.name in _columns(table_name):
        return
    column.append_foreign_key(
        sa.ForeignKey(target, name=f"fk_{table_name}_{column.name}_{target.split('.')[0]}")
    )
    with op.batch_alter_table(table_name) as batch:
        batch.add_column(column)


def _add_column(table_name: str, column: sa.Column) -> None:
    if column.name not in _columns(table_name):
        op.add_column(table_name, column)


def _drop_column(table_name: str, column_name: str) -> None:
    if column_name in _columns(table_name):
        with op.batch_alter_table(table_name) as batch:
            batch.drop_column(column_name)


def _drop_fk_if_present(table_name: str, name: str) -> None:
    names = {item.get("name") for item in sa.inspect(op.get_bind()).get_foreign_keys(table_name)}
    if name in names:
        with op.batch_alter_table(table_name) as batch:
            batch.drop_constraint(name, type_="foreignkey")


def _columns(table_name: str) -> set[str]:
    return {item["name"] for item in sa.inspect(op.get_bind()).get_columns(table_name)}


def _create_index_if_missing(table_name: str, name: str, columns: list[str]) -> None:
    indexes = {item["name"] for item in sa.inspect(op.get_bind()).get_indexes(table_name)}
    if name not in indexes:
        op.create_index(name, table_name, columns, unique=False)


def _drop_index_if_present(table_name: str, name: str) -> None:
    indexes = {item["name"] for item in sa.inspect(op.get_bind()).get_indexes(table_name)}
    if name in indexes:
        op.drop_index(name, table_name=table_name)
