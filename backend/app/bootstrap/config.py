from __future__ import annotations

import os
from pathlib import Path


def _as_bool(value: str | None, default: bool = False) -> bool:
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


class Config:
    DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///jiandi.db")
    SECRET_KEY = os.getenv("SECRET_KEY", "jiandi-local-secret")
    GUEST_TOKEN_TTL_HOURS = int(os.getenv("GUEST_TOKEN_TTL_HOURS", "168"))
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
