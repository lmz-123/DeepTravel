"""Add backend-owned media asset catalog.

Revision ID: 20260820_0002
Revises: 20260819_0001
"""

from alembic import op
import sqlalchemy as sa

revision = "20260820_0002"
down_revision = "20260819_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "media_assets",
        sa.Column("key", sa.String(120), primary_key=True),
        sa.Column("storage_path", sa.String(255), nullable=False),
        sa.Column("mime_type", sa.String(100), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        "ix_media_assets_storage_path", "media_assets", ["storage_path"], unique=True
    )


def downgrade() -> None:
    op.drop_table("media_assets")
