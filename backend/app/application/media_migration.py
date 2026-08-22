from __future__ import annotations

from hashlib import sha256
from pathlib import Path

from sqlalchemy import select

from app.infrastructure.persistence.models import (
    CityModel,
    MediaAssetModel,
    RouteModel,
    StopModel,
    StoryFragmentModel,
)


class MediaMigrationService:
    def __init__(self, session_factory, object_storage, media_root: str):
        self.session_factory = session_factory
        self.object_storage = object_storage
        self.media_root = Path(media_root).resolve()

    def migrate(self, *, dry_run: bool = False) -> dict:
        report = {"uploaded": 0, "skipped": 0, "missing": [], "updated": 0}
        session = self.session_factory()
        try:
            assets = list(session.scalars(select(MediaAssetModel).order_by(MediaAssetModel.key)))
            for asset in assets:
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
