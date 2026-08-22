from __future__ import annotations

from hashlib import sha256
from io import BytesIO
from typing import BinaryIO
from uuid import uuid4

from PIL import Image, ImageOps, UnidentifiedImageError

from app.domain.errors import DomainError
from app.domain.evidence import StoredEvidence


class CommunityMediaInvalidError(DomainError):
    code = "community_media_invalid"
    status_code = 422
    default_message = "图片格式无效，仅支持 JPEG、PNG 或 WebP"


class CommunityMediaTooLargeError(DomainError):
    code = "community_media_too_large"
    status_code = 413
    default_message = "图片超过允许的大小"


class CommunityMediaUnavailableError(DomainError):
    code = "community_media_unavailable"
    status_code = 503
    default_message = "现场图片暂时无法安全保存，请稍后重试"


class CommunityMediaStorage:
    supported = {
        "JPEG": ("image/jpeg", ".jpg", "JPEG"),
        "PNG": ("image/png", ".png", "PNG"),
        "WEBP": ("image/webp", ".webp", "WEBP"),
    }

    def __init__(
        self,
        object_storage,
        max_bytes: int,
        max_edge: int,
        accepted_mime_types: tuple[str, ...] = ("image/jpeg", "image/png", "image/webp"),
        prefix: str = "community",
    ):
        self.object_storage = object_storage
        self.max_bytes = max_bytes
        self.max_edge = max_edge
        self.accepted_mime_types = frozenset(accepted_mime_types)
        self.prefix = prefix.strip("/")

    @property
    def provider(self) -> str:
        return self.object_storage.provider

    def put(self, stream: BinaryIO, declared_mime: str, *, scope: str) -> StoredEvidence:
        raw = stream.read(self.max_bytes + 1)
        if len(raw) > self.max_bytes:
            raise CommunityMediaTooLargeError()
        try:
            with Image.open(BytesIO(raw)) as opened:
                opened.verify()
            with Image.open(BytesIO(raw)) as opened:
                image_format = opened.format
                if image_format not in self.supported:
                    raise CommunityMediaInvalidError()
                output_mime, suffix, save_format = self.supported[image_format]
                if output_mime not in self.accepted_mime_types:
                    raise CommunityMediaInvalidError("该图片格式当前未开放")
                if declared_mime and declared_mime not in {output_mime, "application/octet-stream"}:
                    raise CommunityMediaInvalidError("文件内容与声明格式不一致")
                image = ImageOps.exif_transpose(opened)
                image.load()
                image.thumbnail((self.max_edge, self.max_edge), Image.Resampling.LANCZOS)
                if save_format == "JPEG" and image.mode != "RGB":
                    image = image.convert("RGB")
                elif image.mode not in {"RGB", "RGBA", "L"}:
                    image = image.convert("RGB")
                normalized = BytesIO()
                args = (
                    {"quality": 88, "optimize": True}
                    if save_format in {"JPEG", "WEBP"}
                    else {"optimize": True}
                )
                image.save(normalized, format=save_format, **args)
                payload = normalized.getvalue()
                width, height = image.size
        except CommunityMediaInvalidError:
            raise
        except (UnidentifiedImageError, OSError, ValueError) as exc:
            raise CommunityMediaInvalidError() from exc
        safe_scope = "/".join(
            part for part in scope.strip("/").split("/") if part and part not in {".", ".."}
        )
        object_key = f"{self.prefix}/{safe_scope}/{uuid4().hex}{suffix}"
        try:
            self.object_storage.put(object_key, payload, output_mime)
        except Exception as exc:
            raise CommunityMediaUnavailableError() from exc
        return StoredEvidence(
            object_key, output_mime, len(payload), sha256(payload).hexdigest(), width, height
        )

    def open(self, object_key: str):
        return self.object_storage.open(object_key)

    def delete(self, object_key: str) -> None:
        self.object_storage.delete(object_key)

    def canonical_reference(self, object_key: str) -> str:
        if self.provider == "oss":
            return f"oss://{self.object_storage.bucket}/{object_key}"
        return f"local://{object_key}"
