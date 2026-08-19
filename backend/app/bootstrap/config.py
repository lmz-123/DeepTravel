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
    MEDIA_ROOT = os.getenv(
        "MEDIA_ROOT", str(Path(__file__).resolve().parents[2] / "media")
    )
    MAX_CONTENT_LENGTH = 32 * 1024
