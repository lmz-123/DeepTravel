from __future__ import annotations

import hashlib
from datetime import UTC, datetime
from urllib.parse import urlparse

from sqlalchemy import func, or_, select

from app.infrastructure.persistence.models import MediaAssetModel


def _identity(value: str) -> str | None:
    clean = value.strip()
    if not clean:
        return None
    return hashlib.sha256(clean.encode()).hexdigest()[:16]


class MediaReadinessService:
    def __init__(self, session_factory, config):
        self.session_factory = session_factory
        self.config = config

    def audit(self) -> dict:
        with self.session_factory() as session:
            public_count = (
                session.scalar(
                    select(func.count())
                    .select_from(MediaAssetModel)
                    .where(MediaAssetModel.visibility == "public")
                )
                or 0
            )
            private_count = (
                session.scalar(
                    select(func.count())
                    .select_from(MediaAssetModel)
                    .where(MediaAssetModel.visibility != "public")
                )
                or 0
            )
            local_references = (
                session.scalar(
                    select(func.count())
                    .select_from(MediaAssetModel)
                    .where(
                        or_(
                            MediaAssetModel.storage_provider != "oss",
                            MediaAssetModel.object_key.is_(None),
                        )
                    )
                )
                or 0
            )
        cdn = str(self.config.get("OSS_PUBLIC_BASE_URL", "")).rstrip("/")
        provider = (
            "memory"
            if self.config.get("TESTING")
            else str(self.config.get("OBJECT_STORAGE_PROVIDER", ""))
        )
        configured = provider in {"oss", "memory"} and bool(cdn)
        ready = configured and local_references == 0
        return {
            "status": "ready" if ready else "blocked",
            "environment": str(self.config.get("ENVIRONMENT", "unknown")),
            "provider": provider,
            "configured": configured,
            "shared_resource_contract": True,
            "public_bucket_identity": _identity(
                str(self.config.get("OSS_PUBLIC_BUCKET", "shared-public-test"))
            ),
            "private_bucket_identity": _identity(
                str(self.config.get("OSS_PRIVATE_BUCKET", "shared-private-test"))
            ),
            "cdn_host": urlparse(cdn).netloc or None,
            "counts": {"public": public_count, "private": private_count},
            "local_blockers": {
                "references": local_references,
                "reads": 0,
                "mounts": 0,
            },
            "test_fixture_prefix": str(self.config.get("OSS_TEST_PREFIX", "")),
            "audited_at": datetime.now(UTC).isoformat(),
        }
