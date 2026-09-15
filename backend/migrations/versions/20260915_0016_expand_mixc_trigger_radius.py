"""Expand the published MixC route trigger radius for field testing.

Revision ID: 20260915_0016
Revises: 20260825_0015
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "20260915_0016"
down_revision = "20260825_0015"
branch_labels = None
depends_on = None


ROUTE_SLUG = "mixc-world-block-and-memory"
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
            WHERE fragment_id IN (
                SELECT story_fragments.id
                FROM story_fragments
                JOIN story_arcs ON story_arcs.id = story_fragments.arc_id
                JOIN routes ON routes.id = story_arcs.route_id
                WHERE routes.slug = :route_slug
            )
            """
        ),
        {
            "entry_radius_m": ENTRY_RADIUS_M,
            "exit_radius_m": EXIT_RADIUS_M,
            "route_slug": ROUTE_SLUG,
        },
    )
    connection.execute(
        sa.text(
            """
            UPDATE stops
            SET arrival_radius_m = :entry_radius_m
            WHERE route_id IN (
                SELECT id FROM routes WHERE slug = :route_slug
            )
            """
        ),
        {"entry_radius_m": ENTRY_RADIUS_M, "route_slug": ROUTE_SLUG},
    )


def downgrade() -> None:
    connection = op.get_bind()
    connection.execute(
        sa.text(
            """
            UPDATE trigger_regions
            SET entry_radius_m = 50,
                exit_radius_m = 75
            WHERE fragment_id IN (
                SELECT story_fragments.id
                FROM story_fragments
                JOIN story_arcs ON story_arcs.id = story_fragments.arc_id
                JOIN routes ON routes.id = story_arcs.route_id
                WHERE routes.slug = :route_slug
            )
            """
        ),
        {"route_slug": ROUTE_SLUG},
    )
    connection.execute(
        sa.text(
            """
            UPDATE stops
            SET arrival_radius_m = 50
            WHERE route_id IN (
                SELECT id FROM routes WHERE slug = :route_slug
            )
            """
        ),
        {"route_slug": ROUTE_SLUG},
    )
