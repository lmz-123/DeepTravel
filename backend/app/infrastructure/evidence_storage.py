from __future__ import annotations

from hashlib import sha256
from io import BytesIO
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import BinaryIO
from uuid import uuid4

from PIL import Image, ImageOps, UnidentifiedImageError

from app.domain.errors import DomainError
from app.domain.evidence import StoredEvidence


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


class LocalEvidenceStorage:
    supported = {
        "JPEG": ("image/jpeg", ".jpg"),
        "PNG": ("image/png", ".png"),
        "WEBP": ("image/webp", ".webp"),
    }

    def __init__(self, root: str, max_bytes: int, max_edge: int):
        self.root = Path(root).resolve()
        self.max_bytes = max_bytes
        self.max_edge = max_edge
        self.root.mkdir(parents=True, exist_ok=True)

    def healthy(self) -> bool:
        try:
            probe = self.root / ".health"
            probe.write_bytes(b"ok")
            probe.unlink(missing_ok=True)
            return True
        except OSError:
            return False

    def put(self, stream: BinaryIO, declared_mime: str) -> StoredEvidence:
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
        object_key = f"{uuid4().hex[:2]}/{uuid4().hex}{suffix}"
        target = (self.root / object_key).resolve()
        if self.root not in target.parents:
            raise EvidenceStorageUnavailableError()
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            with NamedTemporaryFile(dir=target.parent, delete=False) as temporary:
                temporary.write(payload)
                temporary.flush()
                temporary_path = Path(temporary.name)
            temporary_path.replace(target)
        except OSError as exc:
            raise EvidenceStorageUnavailableError() from exc
        return StoredEvidence(
            object_key, output_mime, len(payload), sha256(payload).hexdigest(), width, height
        )

    def open(self, object_key: str) -> BinaryIO:
        target = (self.root / object_key).resolve()
        if self.root not in target.parents or not target.is_file():
            raise FileNotFoundError(object_key)
        return target.open("rb")

    def delete(self, object_key: str) -> None:
        target = (self.root / object_key).resolve()
        if self.root in target.parents:
            target.unlink(missing_ok=True)
