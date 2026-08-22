from __future__ import annotations

from hashlib import sha256
from io import BytesIO
from typing import BinaryIO
from uuid import uuid4

from PIL import Image, ImageOps, UnidentifiedImageError

from app.domain.errors import DomainError
from app.domain.evidence import StoredEvidence
from app.infrastructure.object_storage import LocalObjectStorage


class EvidenceInvalidError(DomainError):
    code = "evidence_invalid"
    status_code = 422
    default_message = "照片格式无效，仅支持 JPEG、PNG 或 WebP"


class EvidenceTooLargeError(DomainError):
    code = "evidence_too_large"
    status_code = 413
    default_message = "照片超过允许的大小"


class EvidenceStorageUnavailableError(DomainError):
    code = "evidence_storage_unavailable"
    status_code = 503
    default_message = "照片暂时无法安全保存，请稍后重试"


class EvidenceStorage:
    supported = {
        "JPEG": ("image/jpeg", ".jpg"),
        "PNG": ("image/png", ".png"),
        "WEBP": ("image/webp", ".webp"),
    }

    def __init__(self, object_storage, max_bytes: int, max_edge: int, prefix: str):
        self.object_storage = object_storage
        self.max_bytes = max_bytes
        self.max_edge = max_edge
        self.prefix = prefix.strip("/")

    @property
    def provider(self) -> str:
        return self.object_storage.provider

    def healthy(self) -> bool:
        try:
            self.object_storage.exists(f"{self.prefix}/.health")
            return True
        except Exception:
            return False

    def put(
        self, stream: BinaryIO, declared_mime: str, *, scope: str = "unscoped"
    ) -> StoredEvidence:
        raw = stream.read(self.max_bytes + 1)
        if len(raw) > self.max_bytes:
            raise EvidenceTooLargeError()
        try:
            with Image.open(BytesIO(raw)) as opened:
                opened.verify()
            with Image.open(BytesIO(raw)) as opened:
                image_format = opened.format
                image = ImageOps.exif_transpose(opened)
                image.load()
                image.thumbnail((self.max_edge, self.max_edge), Image.Resampling.LANCZOS)
                if image_format not in self.supported:
                    raise EvidenceInvalidError()
                output_mime, suffix = self.supported[image_format]
                if declared_mime and declared_mime not in {output_mime, "application/octet-stream"}:
                    raise EvidenceInvalidError("文件内容与声明格式不一致")
                if image.mode not in {"RGB", "RGBA", "L"}:
                    image = image.convert("RGB")
                normalized = BytesIO()
                save_args = (
                    {"quality": 90, "optimize": True}
                    if image_format in {"JPEG", "WEBP"}
                    else {"optimize": True}
                )
                image.save(normalized, format=image_format, **save_args)
                payload = normalized.getvalue()
                width, height = image.size
        except (UnidentifiedImageError, OSError, ValueError) as exc:
            if isinstance(exc, EvidenceInvalidError):
                raise
            raise EvidenceInvalidError() from exc
        safe_scope = "/".join(
            part for part in scope.strip("/").split("/") if part and part not in {".", ".."}
        )
        object_key = f"{self.prefix}/{safe_scope}/{uuid4().hex}{suffix}"
        try:
            self.object_storage.put(object_key, payload, output_mime)
        except Exception as exc:
            raise EvidenceStorageUnavailableError() from exc
        return StoredEvidence(
            object_key, output_mime, len(payload), sha256(payload).hexdigest(), width, height
        )

    def open(self, object_key: str) -> BinaryIO:
        return self.object_storage.open(object_key)

    def delete(self, object_key: str) -> None:
        self.object_storage.delete(object_key)

    def canonical_reference(self, object_key: str) -> str:
        if self.provider == "oss":
            return f"oss://{self.object_storage.bucket}/{object_key}"
        return f"local://{object_key}"

    def sign_get(self, object_key: str, expires_seconds: int) -> str:
        return self.object_storage.sign_get(object_key, expires_seconds)


class LocalEvidenceStorage(EvidenceStorage):
    def __init__(self, root: str, max_bytes: int, max_edge: int):
        super().__init__(LocalObjectStorage(root), max_bytes, max_edge, prefix="private/evidence")
