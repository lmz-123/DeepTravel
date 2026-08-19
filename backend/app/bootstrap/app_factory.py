from __future__ import annotations

from collections.abc import Mapping

import click
from flask import Flask
from flask_cors import CORS

from app.application.services import CatalogService, GuestSessionService, JourneyService
from app.bootstrap.config import Config
from app.infrastructure.persistence.database import Database
from app.infrastructure.persistence.repositories import SqlAlchemyUnitOfWork
from app.infrastructure.persistence.seed import seed_database
from app.infrastructure.security import JwtTokenCodec
from app.presentation.api.errors import register_error_handlers
from app.presentation.api.routes import api


def create_app(test_config: Mapping[str, object] | None = None) -> Flask:
    app = Flask(__name__)
    app.config.from_object(Config)
    if test_config:
        app.config.update(test_config)

    database = Database(str(app.config["DATABASE_URL"]))
    app.extensions["database"] = database

    def uow_factory():
        return SqlAlchemyUnitOfWork(database.session_factory)

    token_codec = JwtTokenCodec(str(app.config["SECRET_KEY"]))
    app.extensions["services"] = {
        "catalog": CatalogService(uow_factory),
        "guest_sessions": GuestSessionService(
            uow_factory,
            token_codec,
            int(app.config["GUEST_TOKEN_TTL_HOURS"]),
        ),
        "journeys": JourneyService(
            uow_factory,
            bool(app.config["ALLOW_DEMO_ARRIVAL"]),
        ),
    }

    CORS(app, resources={r"/api/*": {"origins": app.config["CORS_ORIGINS"]}})
    app.register_blueprint(api)
    register_error_handlers(app)

    @app.teardown_appcontext
    def remove_session(_: object) -> None:
        database.remove_session()

    @app.cli.command("init-db")
    def init_db_command() -> None:
        database.create_all()
        click.echo("Database schema ready.")

    @app.cli.command("seed")
    def seed_command() -> None:
        session = database.session_factory()
        try:
            created = seed_database(session)
            click.echo("Seed data created." if created else "Seed data already present.")
        finally:
            session.close()

    return app
