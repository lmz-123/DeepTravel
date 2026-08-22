from __future__ import annotations

import logging
from collections.abc import Mapping

import click
from flask import Flask
from flask_cors import CORS

from app.application.community_service import CommunityService
from app.application.fragment_services import FragmentTourService
from app.application.historical_content_service import HistoricalContentService
from app.application.media_migration import MediaMigrationService
from app.application.services import (
    AuthenticationService,
    CatalogService,
    GuestSessionService,
    JourneyService,
)
from app.bootstrap.config import Config
from app.infrastructure.community_media_storage import CommunityMediaStorage
from app.infrastructure.evidence_storage import EvidenceStorage, LocalEvidenceStorage
from app.infrastructure.object_storage import AlibabaOssObjectStorage, LocalObjectStorage
from app.infrastructure.persistence.database import Database
from app.infrastructure.persistence.repositories import SqlAlchemyUnitOfWork
from app.infrastructure.persistence.seed import seed_database
from app.infrastructure.security import JwtTokenCodec
from app.presentation.api.errors import register_error_handlers
from app.presentation.api.media import asset_url
from app.presentation.api.routes import api


def create_app(test_config: Mapping[str, object] | None = None) -> Flask:
    app = Flask(__name__)
    app.config.from_object(Config)
    if test_config:
        app.config.update(test_config)
    if app.config["ENVIRONMENT"] == "production" and app.config["TEST_AUTH_ENABLED"]:
        raise RuntimeError("TEST_AUTH_ENABLED must be false in production")
    if app.config["OBJECT_STORAGE_PROVIDER"] not in {"local", "oss"}:
        raise RuntimeError("OBJECT_STORAGE_PROVIDER must be local or oss")
    if app.config["OBJECT_STORAGE_PROVIDER"] == "oss":
        required = ("OSS_REGION", "OSS_PUBLIC_BUCKET", "OSS_PRIVATE_BUCKET")
        missing = [name for name in required if not app.config[name]]
        if missing:
            raise RuntimeError(f"Missing OSS configuration: {', '.join(missing)}")
    app.logger.setLevel(logging.INFO)

    database = Database(str(app.config["DATABASE_URL"]))
    app.extensions["database"] = database

    def uow_factory():
        return SqlAlchemyUnitOfWork(database.session_factory)

    token_codec = JwtTokenCodec(str(app.config["SECRET_KEY"]))
    if app.config["OBJECT_STORAGE_PROVIDER"] == "oss":
        public_storage = AlibabaOssObjectStorage(
            region=str(app.config["OSS_REGION"]),
            endpoint=str(app.config["OSS_ENDPOINT"]),
            bucket=str(app.config["OSS_PUBLIC_BUCKET"]),
            public_base_url=str(app.config["OSS_PUBLIC_BASE_URL"]),
            access_key_id=str(app.config["OSS_ACCESS_KEY_ID"]),
            access_key_secret=str(app.config["OSS_ACCESS_KEY_SECRET"]),
        )
        private_storage = AlibabaOssObjectStorage(
            region=str(app.config["OSS_REGION"]),
            endpoint=str(app.config["OSS_ENDPOINT"]),
            bucket=str(app.config["OSS_PRIVATE_BUCKET"]),
            access_key_id=str(app.config["OSS_ACCESS_KEY_ID"]),
            access_key_secret=str(app.config["OSS_ACCESS_KEY_SECRET"]),
        )
        evidence_storage = EvidenceStorage(
            private_storage,
            int(app.config["EVIDENCE_MAX_BYTES"]),
            int(app.config["EVIDENCE_MAX_EDGE"]),
            prefix="private/evidence",
        )
    else:
        public_base = str(app.config["PUBLIC_BASE_URL"]).rstrip("/")
        public_storage = LocalObjectStorage(
            str(app.config["MEDIA_ROOT"]),
            f"{public_base}/api/v1/assets" if public_base else "",
        )
        private_storage = LocalObjectStorage(str(app.config["EVIDENCE_ROOT"]))
        evidence_storage = LocalEvidenceStorage(
            str(app.config["EVIDENCE_ROOT"]),
            int(app.config["EVIDENCE_MAX_BYTES"]),
            int(app.config["EVIDENCE_MAX_EDGE"]),
        )
    app.extensions["object_storage"] = {
        "public": public_storage,
        "private": private_storage,
    }
    media_migration = MediaMigrationService(
        database.session_factory, public_storage, str(app.config["MEDIA_ROOT"])
    )
    community_media_storage = CommunityMediaStorage(
        private_storage,
        int(app.config["COMMUNITY_MEDIA_MAX_BYTES"]),
        int(app.config["COMMUNITY_MEDIA_MAX_EDGE"]),
        tuple(app.config["COMMUNITY_MEDIA_ALLOWED_MIME_TYPES"]),
        prefix="community",
    )
    app.extensions["services"] = {
        "catalog": CatalogService(uow_factory),
        "guest_sessions": GuestSessionService(
            uow_factory,
            token_codec,
            int(app.config["GUEST_TOKEN_TTL_HOURS"]),
        ),
        "authentication": AuthenticationService(
            uow_factory,
            token_codec,
            int(app.config["AUTH_TOKEN_TTL_HOURS"]),
            test_auth_enabled=bool(app.config["TEST_AUTH_ENABLED"]),
            test_auth_users=tuple(app.config["TEST_AUTH_USERS"]),
        ),
        "journeys": JourneyService(
            uow_factory,
            bool(app.config["ALLOW_DEMO_ARRIVAL"]),
        ),
        "fragment_tours": FragmentTourService(
            database.session_factory,
            evidence_storage,
            enabled=bool(app.config["ENABLE_FRAGMENT_AUDIO_TOURS"]),
            allow_demo=bool(app.config["ALLOW_DEMO_ARRIVAL"]),
            evidence_enabled=bool(app.config["EVIDENCE_UPLOAD_ENABLED"]),
            evidence_retention_days=int(app.config["EVIDENCE_RETENTION_DAYS"]),
            media_root=str(app.config["MEDIA_ROOT"]),
            asset_url_builder=asset_url,
        ),
        "historical_content": HistoricalContentService(database.session_factory),
        "community": CommunityService(
            database.session_factory,
            community_media_storage,
            evidence_storage,
            enabled=bool(app.config["COMMUNITY_ENABLED"]),
            secret_key=str(app.config["SECRET_KEY"]),
            categories=tuple(app.config["COMMUNITY_CATEGORIES"]),
            report_reasons=tuple(app.config["COMMUNITY_REPORT_REASONS"]),
            title_max=int(app.config["COMMUNITY_TITLE_MAX_LENGTH"]),
            body_max=int(app.config["COMMUNITY_BODY_MAX_LENGTH"]),
            comment_max=int(app.config["COMMUNITY_COMMENT_MAX_LENGTH"]),
            max_media=int(app.config["COMMUNITY_MAX_MEDIA"]),
            report_threshold=int(app.config["COMMUNITY_AUTO_HOLD_REPORT_THRESHOLD"]),
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

    @app.cli.command("migrate-media")
    @click.option("--dry-run", is_flag=True, help="Report changes without writing.")
    def migrate_media_command(dry_run: bool) -> None:
        report = media_migration.migrate(dry_run=dry_run)
        click.echo(
            f"uploaded={report['uploaded']} skipped={report['skipped']} "
            f"updated={report['updated']} missing={len(report['missing'])}"
        )
        for missing in report["missing"]:
            click.echo(f"missing: {missing}")

    return app
