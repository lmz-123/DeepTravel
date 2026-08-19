"""Initial catalog, guest session, and journey schema.

Revision ID: 20260819_0001
Revises:
"""

from alembic import op
import sqlalchemy as sa

revision = "20260819_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "cities",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("slug", sa.String(80), nullable=False),
        sa.Column("name", sa.String(80), nullable=False),
        sa.Column("subtitle", sa.String(160), nullable=False),
        sa.Column("hero_image", sa.String(255), nullable=False),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
    )
    op.create_index("ix_cities_slug", "cities", ["slug"], unique=True)

    op.create_table(
        "guest_sessions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_guest_sessions_expires_at", "guest_sessions", ["expires_at"])

    op.create_table(
        "routes",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("city_id", sa.String(36), sa.ForeignKey("cities.id"), nullable=False),
        sa.Column("slug", sa.String(120), nullable=False),
        sa.Column("title", sa.String(160), nullable=False),
        sa.Column("subtitle", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("duration_minutes", sa.Integer(), nullable=False),
        sa.Column("distance_km", sa.Float(), nullable=False),
        sa.Column("difficulty", sa.String(40), nullable=False),
        sa.Column("theme", sa.String(80), nullable=False),
        sa.Column("hero_image", sa.String(255), nullable=False),
        sa.Column("is_featured", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("content_status", sa.String(40), nullable=False),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_routes_city_id", "routes", ["city_id"])
    op.create_index("ix_routes_slug", "routes", ["slug"], unique=True)

    op.create_table(
        "stops",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("route_id", sa.String(36), sa.ForeignKey("routes.id"), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(160), nullable=False),
        sa.Column("kicker", sa.String(120), nullable=False),
        sa.Column("address", sa.String(255), nullable=False),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.Column("arrival_radius_m", sa.Integer(), nullable=False),
        sa.Column("story_title", sa.String(200), nullable=False),
        sa.Column("story_body", sa.Text(), nullable=False),
        sa.Column("audio_url", sa.String(500), nullable=True),
        sa.Column("image", sa.String(255), nullable=False),
        sa.Column("insight", sa.Text(), nullable=False),
        sa.UniqueConstraint("route_id", "position", name="uq_stop_route_position"),
    )
    op.create_index("ix_stops_route_id", "stops", ["route_id"])

    op.create_table(
        "challenges",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("stop_id", sa.String(36), sa.ForeignKey("stops.id"), nullable=False),
        sa.Column("prompt", sa.Text(), nullable=False),
        sa.Column("hint", sa.Text(), nullable=False),
        sa.Column("options_json", sa.JSON(), nullable=False),
        sa.Column("correct_option", sa.Integer(), nullable=False),
        sa.Column("explanation", sa.Text(), nullable=False),
    )
    op.create_index("ix_challenges_stop_id", "challenges", ["stop_id"], unique=True)

    op.create_table(
        "journeys",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "guest_session_id",
            sa.String(36),
            sa.ForeignKey("guest_sessions.id"),
            nullable=False,
        ),
        sa.Column("route_id", sa.String(36), sa.ForeignKey("routes.id"), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("current_stop_position", sa.Integer(), nullable=False),
        sa.Column("arrived_stop_id", sa.String(36), nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_journeys_guest_session_id", "journeys", ["guest_session_id"])
    op.create_index("ix_journeys_route_id", "journeys", ["route_id"])
    op.create_index("ix_journeys_status", "journeys", ["status"])

    op.create_table(
        "journey_answers",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("journey_id", sa.String(36), sa.ForeignKey("journeys.id"), nullable=False),
        sa.Column("stop_id", sa.String(36), sa.ForeignKey("stops.id"), nullable=False),
        sa.Column("selected_option", sa.Integer(), nullable=False),
        sa.Column("is_correct", sa.Boolean(), nullable=False),
        sa.Column("answered_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("journey_id", "stop_id", name="uq_answer_journey_stop"),
    )
    op.create_index("ix_journey_answers_journey_id", "journey_answers", ["journey_id"])
    op.create_index("ix_journey_answers_stop_id", "journey_answers", ["stop_id"])


def downgrade() -> None:
    op.drop_table("journey_answers")
    op.drop_table("journeys")
    op.drop_table("challenges")
    op.drop_table("stops")
    op.drop_table("routes")
    op.drop_table("guest_sessions")
    op.drop_table("cities")

