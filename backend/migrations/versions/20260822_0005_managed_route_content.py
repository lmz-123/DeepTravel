"""Add managed content package and trigger coordinate provenance.

Revision ID: 20260822_0005
Revises: 20260822_0004
"""

import sqlalchemy as sa
from alembic import op

revision = "20260822_0005"
down_revision = "20260822_0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    _add_column_if_missing(bind, "routes", sa.Column("managed_package_id", sa.String(120)))
    _add_column_if_missing(
        bind, "routes", sa.Column("managed_package_version", sa.String(80))
    )
    route_indexes = {item["name"] for item in sa.inspect(bind).get_indexes("routes")}
    if "ix_routes_managed_package_id" not in route_indexes:
        op.create_index(
            "ix_routes_managed_package_id", "routes", ["managed_package_id"], unique=False
        )

    _add_column_if_missing(
        bind,
        "trigger_regions",
        sa.Column("coordinate_system", sa.String(20), nullable=False, server_default="WGS84"),
    )
    _add_column_if_missing(
        bind, "trigger_regions", sa.Column("source_coordinate_system", sa.String(20))
    )
    _add_column_if_missing(
        bind, "trigger_regions", sa.Column("coordinate_source", sa.Text())
    )
    _add_column_if_missing(bind, "trigger_regions", sa.Column("field_notes", sa.Text()))


def downgrade() -> None:
    bind = op.get_bind()
    _drop_column_if_present(bind, "trigger_regions", "field_notes")
    _drop_column_if_present(bind, "trigger_regions", "coordinate_source")
    _drop_column_if_present(bind, "trigger_regions", "source_coordinate_system")
    _drop_column_if_present(bind, "trigger_regions", "coordinate_system")
    indexes = {item["name"] for item in sa.inspect(bind).get_indexes("routes")}
    if "ix_routes_managed_package_id" in indexes:
        op.drop_index("ix_routes_managed_package_id", table_name="routes")
    _drop_column_if_present(bind, "routes", "managed_package_version")
    _drop_column_if_present(bind, "routes", "managed_package_id")


def _column_names(bind, table_name: str) -> set[str]:
    return {column["name"] for column in sa.inspect(bind).get_columns(table_name)}


def _add_column_if_missing(bind, table_name: str, column: sa.Column) -> None:
    if column.name not in _column_names(bind, table_name):
        op.add_column(table_name, column)


def _drop_column_if_present(bind, table_name: str, column_name: str) -> None:
    if column_name in _column_names(bind, table_name):
        op.drop_column(table_name, column_name)
