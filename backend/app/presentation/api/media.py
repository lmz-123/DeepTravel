from __future__ import annotations

from urllib.parse import quote, urlencode, urlsplit, urlunsplit

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


def public_image_variants(value: str) -> dict:
    """Use OSS image derivatives for owned public assets, never rewrite external URLs."""
    original = asset_url(value) or ""
    parsed = urlsplit(original)
    base = urlsplit(str(current_app.config.get("OSS_PUBLIC_BASE_URL", "")))
    variants = {"full": original, "thumbnail": original, "preview": original}
    if not original or not base.hostname or parsed.hostname != base.hostname or parsed.query:
        return variants
    for name, edge in (("thumbnail", 240), ("preview", 960)):
        query = urlencode(
            {
                "x-oss-process": (
                    f"image/resize,m_lfit,w_{edge},h_{edge},limit_1/format,webp/quality,q_85"
                )
            }
        )
        variants[name] = urlunsplit(parsed._replace(query=query))
    return variants
