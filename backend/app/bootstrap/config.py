from __future__ import annotations

import os
from pathlib import Path


def _as_bool(value: str | None, default: bool = False) -> bool:
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


class Config:
    ENVIRONMENT = os.getenv("APP_ENV", "development").strip().lower()
    DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///jiandi.db")
    SECRET_KEY = os.getenv("SECRET_KEY", "jiandi-local-secret")
    GUEST_TOKEN_TTL_HOURS = int(os.getenv("GUEST_TOKEN_TTL_HOURS", "168"))
    AUTH_TOKEN_TTL_HOURS = int(os.getenv("AUTH_TOKEN_TTL_HOURS", "168"))
    TEST_AUTH_ENABLED = _as_bool(os.getenv("TEST_AUTH_ENABLED"), False)
    TEST_AUTH_USERS = tuple(
        item.strip()
        for item in os.getenv("TEST_AUTH_USERS", "tester-a,tester-b").split(",")
        if item.strip()
    )
    ALLOW_DEMO_ARRIVAL = _as_bool(os.getenv("ALLOW_DEMO_ARRIVAL"), False)
    CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*")
    PUBLIC_BASE_URL = os.getenv("PUBLIC_BASE_URL", "").rstrip("/")
    MEDIA_ROOT = os.getenv("MEDIA_ROOT", str(Path(__file__).resolve().parents[2] / "media"))
    MAX_CONTENT_LENGTH = int(os.getenv("MAX_CONTENT_LENGTH", str(12 * 1024 * 1024)))
    ENABLE_FRAGMENT_AUDIO_TOURS = _as_bool(os.getenv("ENABLE_FRAGMENT_AUDIO_TOURS"), True)
    EVIDENCE_UPLOAD_ENABLED = _as_bool(os.getenv("EVIDENCE_UPLOAD_ENABLED"), True)
    EVIDENCE_ROOT = os.getenv("EVIDENCE_ROOT", "/app/private-evidence")
    EVIDENCE_MAX_BYTES = int(os.getenv("EVIDENCE_MAX_BYTES", str(10 * 1024 * 1024)))
    EVIDENCE_MAX_EDGE = int(os.getenv("EVIDENCE_MAX_EDGE", "4096"))
    EVIDENCE_RETENTION_DAYS = int(os.getenv("EVIDENCE_RETENTION_DAYS", "30"))
    OBJECT_STORAGE_PROVIDER = os.getenv("OBJECT_STORAGE_PROVIDER", "oss").strip().lower()
    OSS_REGION = os.getenv("OSS_REGION", "")
    OSS_ENDPOINT = os.getenv("OSS_ENDPOINT", "")
    OSS_PUBLIC_BUCKET = os.getenv("OSS_PUBLIC_BUCKET", "")
    OSS_PRIVATE_BUCKET = os.getenv("OSS_PRIVATE_BUCKET", "")
    OSS_PUBLIC_BASE_URL = os.getenv("OSS_PUBLIC_BASE_URL", "").rstrip("/")
    OSS_ACCESS_KEY_ID = os.getenv("OSS_ACCESS_KEY_ID", "")
    OSS_ACCESS_KEY_SECRET = os.getenv("OSS_ACCESS_KEY_SECRET", "")
    OSS_SIGNED_URL_TTL_SECONDS = int(os.getenv("OSS_SIGNED_URL_TTL_SECONDS", "300"))
    OSS_TEST_PREFIX = os.getenv("OSS_TEST_PREFIX", "integration-tests/").strip("/")
    COMMUNITY_ENABLED = _as_bool(os.getenv("COMMUNITY_ENABLED"), True)
    COMMUNITY_TITLE_MAX_LENGTH = int(os.getenv("COMMUNITY_TITLE_MAX_LENGTH", "60"))
    COMMUNITY_BODY_MAX_LENGTH = int(os.getenv("COMMUNITY_BODY_MAX_LENGTH", "1200"))
    COMMUNITY_COMMENT_MAX_LENGTH = int(os.getenv("COMMUNITY_COMMENT_MAX_LENGTH", "300"))
    COMMUNITY_MAX_MEDIA = int(os.getenv("COMMUNITY_MAX_MEDIA", "4"))
    COMMUNITY_MEDIA_MAX_BYTES = int(os.getenv("COMMUNITY_MEDIA_MAX_BYTES", str(10 * 1024 * 1024)))
    COMMUNITY_MEDIA_MAX_EDGE = int(os.getenv("COMMUNITY_MEDIA_MAX_EDGE", "1920"))
    COMMUNITY_MEDIA_RETENTION_DAYS = int(os.getenv("COMMUNITY_MEDIA_RETENTION_DAYS", "0"))
    COMMUNITY_MEDIA_ALLOWED_MIME_TYPES = tuple(
        item.strip()
        for item in os.getenv(
            "COMMUNITY_MEDIA_ALLOWED_MIME_TYPES", "image/jpeg,image/png,image/webp"
        ).split(",")
        if item.strip()
    )
    COMMUNITY_AUTO_HOLD_REPORT_THRESHOLD = int(
        os.getenv("COMMUNITY_AUTO_HOLD_REPORT_THRESHOLD", "3")
    )
    COMMUNITY_CATEGORIES = ("viewpoint", "experience", "fact_supplement", "on_site")
    COMMUNITY_REPORT_REASONS = ("spam", "abuse", "privacy", "misinformation", "other")
