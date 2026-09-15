"""Set the global field-trigger radius for every route node.

Revision ID: 20260915_0017
Revises: 20260915_0016
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "20260915_0017"
down_revision = "20260915_0016"
branch_labels = None
depends_on = None


ENTRY_RADIUS_M = 100
EXIT_RADIUS_M = 150


def upgrade() -> None:
    connection = op.get_bind()
    connection.execute(
        sa.text(
            """
            UPDATE trigger_regions
            SET entry_radius_m = :entry_radius_m,
                exit_radius_m = :exit_radius_m
            """
        ),
        {"entry_radius_m": ENTRY_RADIUS_M, "exit_radius_m": EXIT_RADIUS_M},
    )
    connection.execute(
        sa.text(
            """
            UPDATE stops
            SET arrival_radius_m = :entry_radius_m
            """
        ),
        {"entry_radius_m": ENTRY_RADIUS_M},
    )


def downgrade() -> None:
    connection = op.get_bind()
    connection.execute(
        sa.text(
            """
            UPDATE trigger_regions
            SET entry_radius_m = 50,
                exit_radius_m = 75
            """
        )
    )
    connection.execute(
        sa.text(
            """
            UPDATE stops
            SET arrival_radius_m = 50
            """
        )
    )
