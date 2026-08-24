from __future__ import annotations

from hashlib import sha256
from pathlib import Path

from sqlalchemy import select

from app.infrastructure.persistence.models import (
    CityModel,
    CommunityMediaModel,
    EvidenceModel,
    FootprintPhotoModel,
    MediaAssetModel,
    NarrationPreviewModel,
    RouteModel,
    StopModel,
    StoryFragmentModel,
)


class MediaMigrationService:
    def __init__(
        self,
        session_factory,
        object_storage,
        media_root: str,
        *,
        private_storage=None,
        private_roots: list[str] | None = None,
    ):
        self.session_factory = session_factory
        self.object_storage = object_storage
        self.media_root = Path(media_root).resolve()
        self.private_storage = private_storage
        self.private_roots = [Path(value).resolve() for value in (private_roots or [])]

    def migrate(self, *, dry_run: bool = False) -> dict:
        report = {
            "uploaded": 0,
            "skipped": 0,
            "private_uploaded": 0,
            "private_skipped": 0,
            "missing": [],
            "updated": 0,
            "categories": {},
        }
        session = self.session_factory()
        try:
            assets = list(session.scalars(select(MediaAssetModel).order_by(MediaAssetModel.key)))
            for asset in assets:
                if (
                    asset.storage_provider == "oss"
                    and asset.object_key
                    and self.object_storage.exists(asset.object_key)
                ):
                    report["skipped"] += 1
                    continue
                source = (self.media_root / asset.storage_path).resolve()
                if self.media_root not in source.parents or not source.is_file():
                    report["missing"].append(asset.storage_path)
                    continue
                payload = source.read_bytes()
                checksum = sha256(payload).hexdigest()
                object_key = f"public/content/{checksum[:2]}/{checksum}{source.suffix.lower()}"
                if self.object_storage.exists(object_key):
                    report["skipped"] += 1
                else:
                    report["uploaded"] += 1
                    if not dry_run:
                        self.object_storage.put(object_key, payload, asset.mime_type)
                if dry_run:
                    continue
                canonical_url = self.object_storage.public_url(object_key)
                asset.storage_provider = self.object_storage.provider
                asset.object_key = object_key
                asset.canonical_url = canonical_url
                asset.visibility = "public"
                asset.size_bytes = len(payload)
                asset.checksum_sha256 = checksum
                asset.metadata_json = {"migrated_from": asset.storage_path}
                report["updated"] += self._replace_references(
                    session, asset.storage_path, canonical_url
                )
            if self.private_storage is not None:
                self._migrate_private(session, report, dry_run=dry_run)
            if dry_run:
                session.rollback()
            else:
                session.commit()
            return report
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()

    @staticmethod
    def _replace_references(session, old: str, new: str) -> int:
        count = 0
        for model, fields in (
            (CityModel, ("hero_image",)),
            (RouteModel, ("hero_image",)),
            (StopModel, ("image", "audio_url")),
            (StoryFragmentModel, ("audio_path",)),
        ):
            for field in fields:
                column = getattr(model, field)
                rows = list(session.scalars(select(model).where(column == old)))
                for row in rows:
                    setattr(row, field, new)
                    count += 1
        return count

    def _migrate_private(self, session, report: dict, *, dry_run: bool) -> None:
        categories = (
            ("evidence", EvidenceModel, "object_key", "mime_type", "sha256"),
            ("footprint", FootprintPhotoModel, "object_key", "mime_type", "sha256"),
            ("community", CommunityMediaModel, "object_key", "mime_type", "sha256"),
            ("preview", NarrationPreviewModel, "object_key", None, None),
        )
        roots = [*self.private_roots, self.media_root, self.media_root / "private-previews"]
        for category, model, key_field, mime_field, checksum_field in categories:
            counts = {"uploaded": 0, "skipped": 0, "missing": 0}
            rows = list(session.scalars(select(model)))
            for row in rows:
                object_key = str(getattr(row, key_field) or "").strip()
                if not object_key:
                    continue
                provider = str(getattr(row, "storage_provider", "") or "")
                if provider == "oss" and self.private_storage.exists(object_key):
                    report["private_skipped"] += 1
                    counts["skipped"] += 1
                    continue
                source = self._find_private_source(roots, object_key)
                if source is None:
                    report["missing"].append({"category": category, "object_key": object_key})
                    counts["missing"] += 1
                    continue
                payload = source.read_bytes()
                checksum = sha256(payload).hexdigest()
                expected = str(getattr(row, checksum_field) or "").strip() if checksum_field else ""
                if expected and checksum != expected:
                    report["missing"].append(
                        {
                            "category": category,
                            "object_key": object_key,
                            "error": "checksum_mismatch",
                        }
                    )
                    counts["missing"] += 1
                    continue
                if self.private_storage.exists(object_key):
                    report["private_skipped"] += 1
                    counts["skipped"] += 1
                else:
                    report["private_uploaded"] += 1
                    counts["uploaded"] += 1
                    if not dry_run:
                        mime = (
                            str(getattr(row, mime_field) or "application/octet-stream")
                            if mime_field
                            else "audio/mpeg"
                        )
                        self.private_storage.put(object_key, payload, mime)
                if dry_run:
                    continue
                canonical = f"oss://{self.private_storage.bucket}/{object_key}"
                if hasattr(row, "storage_provider"):
                    row.storage_provider = "oss"
                if hasattr(row, "canonical_reference"):
                    row.canonical_reference = canonical
                if isinstance(row, NarrationPreviewModel):
                    row.metadata_json = {
                        **(row.metadata_json or {}),
                        "storage_provider": "oss",
                        "canonical_reference": canonical,
                    }
            report["categories"][category] = counts

    @staticmethod
    def _find_private_source(roots: list[Path], object_key: str) -> Path | None:
        for root in roots:
            candidate = (root / object_key).resolve()
            if (candidate == root or root in candidate.parents) and candidate.is_file():
                return candidate
        return None
