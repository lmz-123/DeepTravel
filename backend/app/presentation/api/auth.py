from __future__ import annotations

from functools import wraps

from flask import current_app, g, request

from app.domain.errors import UnauthorizedError


def require_user(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            raise UnauthorizedError()
        token = header.removeprefix("Bearer ").strip()
        if not token:
            raise UnauthorizedError()
        service = current_app.extensions["services"]["authentication"]
        g.current_user = service.authenticate(token)
        return view(*args, **kwargs)

    return wrapped


require_guest = require_user
