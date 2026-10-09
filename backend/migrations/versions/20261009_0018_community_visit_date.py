"""Keep the shared place visit date separate from publication time."""

import sqlalchemy as sa
from alembic import op

revision = "20261009_0018"
down_revision = "20260915_0017"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("community_posts", sa.Column("visited_on", sa.String(10), nullable=True))


def downgrade():
    op.drop_column("community_posts", "visited_on")
