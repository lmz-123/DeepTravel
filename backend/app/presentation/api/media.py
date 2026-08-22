from __future__ import annotations

import mimetypes
from pathlib import Path
from urllib.parse import quote

from flask import abort, current_app, send_from_directory, url_for


def asset_url(value: str | None) -> str | None:
    if not value:
        return None
    if value.startswith(("http://", "https://")):
        return value
    path = value.lstrip("/")
    public_base = str(current_app.config.get("PUBLIC_BASE_URL", "")).rstrip("/")
    if public_base:
        return f"{public_base}/api/v1/assets/{quote(path, safe='/')}"
    return url_for("api.media_asset", asset_path=path, _external=True)


def send_media_asset(asset_path: str):
    media_root = Path(str(current_app.config["MEDIA_ROOT"])).resolve()
    candidate = (media_root / asset_path).resolve()
    if media_root != candidate and media_root not in candidate.parents:
        abort(404)
    if not candidate.is_file():
        abort(404)
    mime_type = mimetypes.guess_type(candidate.name)[0]
    if candidate.suffix.lower() == ".m4a":
        mime_type = "audio/mp4"
    return send_from_directory(
        media_root,
        candidate.relative_to(media_root).as_posix(),
        mimetype=mime_type,
    )
