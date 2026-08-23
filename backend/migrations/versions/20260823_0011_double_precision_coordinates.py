"""Store field-test coordinates without single-precision truncation.

Revision ID: 20260823_0011
Revises: 20260823_0010
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "20260823_0011"
down_revision = "20260823_0010"
branch_labels = None
depends_on = None


_COORDINATE_TABLES = ("cities", "stops", "trigger_regions")


def upgrade() -> None:
    for table_name in _COORDINATE_TABLES:
        with op.batch_alter_table(table_name) as batch:
            batch.alter_column(
                "latitude",
                existing_type=sa.Float(),
                type_=sa.Double(),
                existing_nullable=False,
            )
            batch.alter_column(
                "longitude",
                existing_type=sa.Float(),
                type_=sa.Double(),
                existing_nullable=False,
            )


def downgrade() -> None:
    for table_name in reversed(_COORDINATE_TABLES):
        with op.batch_alter_table(table_name) as batch:
            batch.alter_column(
                "latitude",
                existing_type=sa.Double(),
                type_=sa.Float(),
                existing_nullable=False,
            )
            batch.alter_column(
                "longitude",
                existing_type=sa.Double(),
                type_=sa.Float(),
                existing_nullable=False,
            )
