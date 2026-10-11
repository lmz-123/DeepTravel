"""Structured preparation checklists in community guides."""

import sqlalchemy as sa
from alembic import op

revision = "20261011_0021"
down_revision = "20261011_0020"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("community_posts", sa.Column("preparation_items", sa.JSON(), nullable=True))


def downgrade():
    op.drop_column("community_posts", "preparation_items")
