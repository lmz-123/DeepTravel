"""Server-managed city atlas assets and editorial map categories."""

import sqlalchemy as sa
from alembic import op

revision = "20261011_0019"
down_revision = "20261009_0018"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "city_maps",
        sa.Column(
            "city_id",
            sa.String(36),
            sa.ForeignKey("cities.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("adcode", sa.String(6), nullable=True),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("object_key", sa.String(500), nullable=True),
        sa.Column("version", sa.String(64), nullable=True),
        sa.Column("district_count", sa.Integer, nullable=False),
        sa.Column("error", sa.String(255), nullable=True),
        sa.Column("attempts", sa.Integer, nullable=False),
        sa.Column("lease_token", sa.String(36), nullable=True),
        sa.Column("next_attempt_at", sa.DateTime, nullable=False),
        sa.Column("updated_at", sa.DateTime, nullable=False),
    )
    op.add_column("routes", sa.Column("map_category", sa.String(20), nullable=True))


def downgrade():
    op.drop_column("routes", "map_category")
    op.drop_table("city_maps")
