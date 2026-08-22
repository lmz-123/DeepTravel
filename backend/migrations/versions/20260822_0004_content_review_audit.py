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
    bind = op.get_bind()
    _add_column_if_missing(
        bind, "historical_claims", sa.Column("reviewed_by", sa.String(120))
    )
    _add_column_if_missing(
        bind,
        "historical_claims",
        sa.Column("reviewed_at", sa.DateTime(timezone=True)),
    )
    _add_column_if_missing(
        bind, "story_arcs", sa.Column("reviewed_by", sa.String(120))
    )
    _add_column_if_missing(
        bind, "story_arcs", sa.Column("reviewed_at", sa.DateTime(timezone=True))
    )
    _add_column_if_missing(
        bind, "story_arcs", sa.Column("source_version", sa.String(80))
    )
    _add_column_if_missing(
        bind,
        "story_arcs",
        sa.Column("publication_decision", sa.String(40)),
    )


def downgrade() -> None:
    bind = op.get_bind()
    _drop_column_if_present(bind, "story_arcs", "publication_decision")
    _drop_column_if_present(bind, "story_arcs", "source_version")
    _drop_column_if_present(bind, "story_arcs", "reviewed_at")
    _drop_column_if_present(bind, "story_arcs", "reviewed_by")
    _drop_column_if_present(bind, "historical_claims", "reviewed_at")
    _drop_column_if_present(bind, "historical_claims", "reviewed_by")


def _column_names(bind, table_name: str) -> set[str]:
    return {column["name"] for column in sa.inspect(bind).get_columns(table_name)}


def _add_column_if_missing(bind, table_name: str, column: sa.Column) -> None:
    if column.name not in _column_names(bind, table_name):
        op.add_column(table_name, column)


def _drop_column_if_present(bind, table_name: str, column_name: str) -> None:
    if column_name in _column_names(bind, table_name):
        op.drop_column(table_name, column_name)
