from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

import jwt

from app.domain.errors import UnauthorizedError


@dataclass(frozen=True, slots=True)
class TokenIdentity:
    subject: str
    kind: str
    auth_version: int = 1


class JwtTokenCodec:
    def __init__(self, secret_key: str):
        self.secret_key = secret_key

    def encode(self, session_id: str, expires_at: datetime) -> str:
        return jwt.encode(
            {"sub": session_id, "exp": expires_at, "kind": "guest"},
            self.secret_key,
            algorithm="HS256",
        )

    def encode_user(self, user_id: str, auth_version: int, expires_at: datetime) -> str:
        return jwt.encode(
            {
                "sub": user_id,
                "exp": expires_at,
                "kind": "user",
                "auth_version": auth_version,
            },
            self.secret_key,
            algorithm="HS256",
        )

    def decode_identity(self, token: str) -> TokenIdentity:
        try:
            payload = jwt.decode(token, self.secret_key, algorithms=["HS256"])
            kind = str(payload.get("kind") or "")
            subject = str(payload.get("sub") or "")
            if kind not in {"guest", "user"} or not subject:
                raise UnauthorizedError("登录令牌无效")
            return TokenIdentity(
                subject=subject,
                kind=kind,
                auth_version=int(payload.get("auth_version") or 1),
            )
        except jwt.ExpiredSignatureError as exc:
            raise UnauthorizedError("登录已过期，请重新登录") from exc
        except (jwt.InvalidTokenError, TypeError, ValueError) as exc:
            raise UnauthorizedError("登录令牌无效") from exc

    def decode(self, token: str) -> str:
        identity = self.decode_identity(token)
        if identity.kind != "guest":
            raise UnauthorizedError("游客令牌无效")
        return identity.subject
