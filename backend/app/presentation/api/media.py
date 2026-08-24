from __future__ import annotations

from urllib.parse import quote

from flask import abort, current_app, redirect


def asset_url(value: str | None) -> str | None:
    if not value:
        return None
    if value.startswith(("http://", "https://")):
        return value
    path = value.lstrip("/")
    public_base = str(current_app.config.get("OSS_PUBLIC_BASE_URL", "")).rstrip("/")
    if not public_base:
        abort(503, description="OSS public CDN is not configured")
    return f"{public_base}/{quote(path, safe='/')}"


def send_media_asset(asset_path: str):
    clean = asset_path.lstrip("/")
    if not clean or any(part in {".", ".."} for part in clean.split("/")):
        abort(404)
    public_base = str(current_app.config.get("OSS_PUBLIC_BASE_URL", "")).rstrip("/")
    if not public_base:
        abort(503, description="OSS public CDN is not configured")
    return redirect(f"{public_base}/{quote(clean, safe='/')}", code=308)
