#!/usr/bin/env python3
"""Idempotently import, validate, verify and publish an admin content package."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
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
    args = parser.parse_args()
    base = os.getenv("ADMIN_API_BASE", "http://127.0.0.1:5100")
    token = os.getenv("ADMIN_TOKEN", "").strip()
    if not token:
        parser.error("ADMIN_TOKEN must be supplied through the environment")
    package = json.loads(args.package.read_text())
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
