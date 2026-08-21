from __future__ import annotations

from dataclasses import dataclass
from typing import BinaryIO, Protocol


@dataclass(frozen=True, slots=True)
class StoredEvidence:
    object_key: str
    mime_type: str
    size_bytes: int
    sha256: str
    width: int
    height: int


class EvidenceStorage(Protocol):
    def put(self, stream: BinaryIO, declared_mime: str) -> StoredEvidence: ...

    def open(self, object_key: str) -> BinaryIO: ...

    def delete(self, object_key: str) -> None: ...

    def healthy(self) -> bool: ...
