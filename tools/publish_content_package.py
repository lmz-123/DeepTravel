#!/usr/bin/env python3
"""Idempotently import, validate, verify and publish an admin content package."""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
import os
import sys
from pathlib import Path
from uuid import uuid4
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def request(base: str, token: str, method: str, path: str, payload=None):
    body = json.dumps(payload, ensure_ascii=False).encode() if payload is not None else None
    response = Request(
        f"{base.rstrip('/')}{path}",
        data=body,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urlopen(response, timeout=60) as opened:
            raw = opened.read()
    except HTTPError as error:
        detail = error.read().decode(errors="replace")
        raise RuntimeError(f"{method} {path} failed ({error.code}): {detail}") from error
    return json.loads(raw) if raw else None


def route_by_id(base: str, token: str, route_id: str):
    rows = request(base, token, "GET", "/api/admin/routes")
    return next((item for item in rows if item["id"] == route_id), None)


def upload_media(base: str, token: str, key: str, path: Path, mime_type: str):
    boundary = f"deeptravel-{uuid4().hex}"
    payload = b"".join(
        (
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"key\"\r\n\r\n{key}\r\n".encode(),
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{path.name}\"\r\nContent-Type: {mime_type}\r\n\r\n".encode(),
            path.read_bytes(),
            f"\r\n--{boundary}--\r\n".encode(),
        )
    )
    upload = Request(
        f"{base.rstrip('/')}/api/admin/media",
        data=payload,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
        },
    )
    try:
        with urlopen(upload, timeout=120) as opened:
            return json.loads(opened.read())
    except HTTPError as error:
        detail = error.read().decode(errors="replace")
        raise RuntimeError(f"media upload failed ({error.code}): {detail}") from error


def advance(base: str, token: str, route: dict) -> dict:
    transitions = {
        "draft": ("submit-review", "in_review"),
        "in_review": ("verify", "verified"),
        "verified": ("publish", "published"),
    }
    while route["content_status"] in transitions:
        action, expected = transitions[route["content_status"]]
        result = request(
            base,
            token,
            "POST",
            f"/api/admin/routes/{route['id']}/{action}",
            {},
        )
        route = result["route"]
        if route["content_status"] != expected:
            raise RuntimeError(f"unexpected lifecycle result after {action}: {route}")
    if route["content_status"] != "published" or not route.get("is_public_visible"):
        raise RuntimeError(f"route is not publicly visible: {route}")
    return route


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("package", type=Path)
    parser.add_argument("--archive-route-id")
    parser.add_argument("--media-root", type=Path)
    args = parser.parse_args()
    base = os.getenv("ADMIN_API_BASE", "http://127.0.0.1:5100")
    token = os.getenv("ADMIN_TOKEN", "").strip()
    if not token:
        parser.error("ADMIN_TOKEN must be supplied through the environment")
    package = json.loads(args.package.read_text())
    media_root = args.media_root or args.package.resolve().parents[2] / "backend/media"
    catalog = request(base, token, "GET", "/api/admin/media")
    by_key = {item["key"]: item for item in catalog}
    by_checksum = {
        item["checksum_sha256"]: item
        for item in catalog
        if item.get("checksum_sha256")
    }
    for item in package.get("media") or []:
        key = item["key"]
        expected = item.get("sha256")
        existing = by_key.get(key) or (by_checksum.get(expected) if expected else None)
        if existing:
            actual = existing.get("checksum_sha256")
            if expected and actual and actual != expected:
                raise RuntimeError(f"registered media checksum mismatch: {key}")
            continue
        source = (media_root / item["storage_path"]).resolve()
        if media_root.resolve() not in source.parents or not source.is_file():
            raise RuntimeError(f"media file is missing or outside media root: {source}")
        if expected and sha256(source.read_bytes()).hexdigest() != expected:
            raise RuntimeError(f"local media checksum mismatch: {key}")
        upload_media(base, token, key, source, item["mime_type"])
        print(f"uploaded {key}")
    imported = request(
        base, token, "POST", "/api/admin/fragmented-routes/import", package
    )
    if not imported["validation"]["valid"]:
        print(json.dumps(imported["validation"], ensure_ascii=False, indent=2))
        raise RuntimeError("content graph validation failed")
    route = advance(base, token, imported["route"])
    print(f"published {route['slug']} ({route['id']})")

    old_id = args.archive_route_id
    if old_id and old_id != route["id"]:
        old = route_by_id(base, token, old_id)
        if old and old["content_status"] == "published":
            old = request(
                base,
                token,
                "POST",
                f"/api/admin/routes/{old_id}/archive",
                {},
            )["route"]
        if old and old["content_status"] != "archived":
            raise RuntimeError(f"old route was not archived: {old}")
        print(f"archived {old_id}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
