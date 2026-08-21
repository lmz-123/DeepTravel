"""Add reviewer and publication audit fields.

Revision ID: 20260822_0004
Revises: 20260822_0003
"""

import sqlalchemy as sa
from alembic import op

revision = "20260822_0004"
down_revision = "20260822_0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("historical_claims", sa.Column("reviewed_by", sa.String(120)))
    op.add_column("historical_claims", sa.Column("reviewed_at", sa.DateTime(timezone=True)))
    op.add_column("story_arcs", sa.Column("reviewed_by", sa.String(120)))
    op.add_column("story_arcs", sa.Column("reviewed_at", sa.DateTime(timezone=True)))
    op.add_column("story_arcs", sa.Column("source_version", sa.String(80)))
    op.add_column("story_arcs", sa.Column("publication_decision", sa.String(40)))


def downgrade() -> None:
    op.drop_column("story_arcs", "publication_decision")
    op.drop_column("story_arcs", "source_version")
    op.drop_column("story_arcs", "reviewed_at")
    op.drop_column("story_arcs", "reviewed_by")
    op.drop_column("historical_claims", "reviewed_at")
    op.drop_column("historical_claims", "reviewed_by")
