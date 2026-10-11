"""Configurable official booking links and travel preparation."""
import sqlalchemy as sa
from alembic import op

revision = "20261011_0020"
down_revision = "20261011_0019"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("routes", sa.Column("travel_preparation", sa.JSON(), nullable=True))


def downgrade():
    op.drop_column("routes", "travel_preparation")
