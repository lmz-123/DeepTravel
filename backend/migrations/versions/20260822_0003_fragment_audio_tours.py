"""Add sourced fragmented audio tours and private evidence.

Revision ID: 20260822_0003
Revises: 20260820_0002
"""

from alembic import op

from app.infrastructure.persistence.models import Base

revision = "20260822_0003"
down_revision = "20260820_0002"
branch_labels = None
depends_on = None


TABLE_NAMES = (
    "historical_sources",
    "historical_claims",
    "claim_sources",
    "story_arcs",
    "story_fragments",
    "fragment_claims",
    "fragment_dependencies",
    "trigger_regions",
    "photo_missions",
    "journey_fragments",
    "active_tours",
    "evidence",
    "reconstructions",
    "idempotency_records",
)


def upgrade() -> None:
    bind = op.get_bind()
    for name in TABLE_NAMES:
        Base.metadata.tables[name].create(bind=bind, checkfirst=True)


def downgrade() -> None:
    bind = op.get_bind()
    for name in reversed(TABLE_NAMES):
        Base.metadata.tables[name].drop(bind=bind, checkfirst=True)
