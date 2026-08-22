from __future__ import annotations

from dataclasses import dataclass
from typing import BinaryIO, Protocol


@dataclass(frozen=True, slots=True)
class StoredObject:
    provider: str
    object_key: str
    canonical_reference: str
    public_url: str | None = None


class ObjectStorage(Protocol):
    provider: str

    def put(self, object_key: str, payload: bytes, mime_type: str) -> StoredObject: ...

    def open(self, object_key: str) -> BinaryIO: ...

    def exists(self, object_key: str) -> bool: ...

    def delete(self, object_key: str) -> None: ...

    def public_url(self, object_key: str) -> str: ...

    def sign_get(self, object_key: str, expires_seconds: int) -> str: ...
