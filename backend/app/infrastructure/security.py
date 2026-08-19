from __future__ import annotations

from datetime import datetime

import jwt

from app.domain.errors import UnauthorizedError


class JwtTokenCodec:
    def __init__(self, secret_key: str):
        self.secret_key = secret_key

    def encode(self, session_id: str, expires_at: datetime) -> str:
        return jwt.encode(
            {"sub": session_id, "exp": expires_at, "kind": "guest"},
            self.secret_key,
            algorithm="HS256",
        )

    def decode(self, token: str) -> str:
        try:
            payload = jwt.decode(token, self.secret_key, algorithms=["HS256"])
            if payload.get("kind") != "guest" or not payload.get("sub"):
                raise UnauthorizedError("游客令牌无效")
            return str(payload["sub"])
        except jwt.ExpiredSignatureError as exc:
            raise UnauthorizedError("游客令牌已过期") from exc
        except jwt.InvalidTokenError as exc:
            raise UnauthorizedError("游客令牌无效") from exc
