from __future__ import annotations

from datetime import UTC, datetime
from io import BytesIO

import pytest
from PIL import Image

from app.application.media_migration import MediaMigrationService
from app.infrastructure.community_media_storage import (
    CommunityMediaInvalidError,
    CommunityMediaStorage,
)
from app.infrastructure.evidence_storage import EvidenceInvalidError, EvidenceStorage
from app.infrastructure.object_storage import LocalObjectStorage
from app.infrastructure.persistence.models import CityModel, MediaAssetModel


def test_local_object_storage_contract(tmp_path):
    storage = LocalObjectStorage(str(tmp_path), "https://cdn.example.test")
    stored = storage.put("public/content/a file.jpg", b"image", "image/jpeg")

    assert stored.provider == "local"
    assert storage.exists(stored.object_key)
    assert storage.open(stored.object_key).read() == b"image"
    assert (
        storage.public_url(stored.object_key)
        == "https://cdn.example.test/public/content/a%20file.jpg"
    )
    assert storage.sign_get(stored.object_key, 30) == storage.public_url(stored.object_key)

    storage.delete(stored.object_key)
    assert not storage.exists(stored.object_key)
    with pytest.raises(ValueError):
        storage.put("../escape", b"bad", "application/octet-stream")


def test_evidence_is_normalized_and_user_scoped(tmp_path):
    storage = LocalObjectStorage(str(tmp_path))
    evidence = EvidenceStorage(storage, 2_000_000, 256, "private/evidence")
    source = BytesIO()
    Image.new("RGB", (640, 480), "navy").save(source, format="JPEG", exif=b"Exif\x00\x00secret")
    source.seek(0)

    saved = evidence.put(source, "image/jpeg", scope="user-a/journey-a")

    assert saved.object_key.startswith("private/evidence/user-a/journey-a/")
    assert saved.width <= 256 and saved.height <= 256
    normalized = storage.open(saved.object_key).read()
    assert b"secret" not in normalized
    with Image.open(BytesIO(normalized)) as image:
        assert not image.getexif()

    with pytest.raises(EvidenceInvalidError):
        evidence.put(BytesIO(b"not an image"), "image/jpeg", scope="user-a/journey-a")


def test_community_media_is_private_normalized_and_independently_deletable(tmp_path):
    objects = LocalObjectStorage(str(tmp_path))
    storage = CommunityMediaStorage(objects, 2_000_000, 256, ("image/jpeg",))
    source = BytesIO()
    Image.new("RGB", (800, 600), "sienna").save(
        source, format="JPEG", exif=b"Exif\x00\x00private-gps"
    )
    source.seek(0)

    saved = storage.put(source, "image/jpeg", scope="fragment/post")

    assert saved.object_key.startswith("community/fragment/post/")
    assert saved.width <= 256 and saved.height <= 256
    assert len(saved.sha256) == 64
    normalized = storage.open(saved.object_key).read()
    assert b"private-gps" not in normalized
    with Image.open(BytesIO(normalized)) as image:
        assert not image.getexif()
    storage.delete(saved.object_key)
    assert not objects.exists(saved.object_key)

    png = BytesIO()
    Image.new("RGBA", (10, 10), "red").save(png, format="PNG")
    png.seek(0)
    with pytest.raises(CommunityMediaInvalidError):
        storage.put(png, "image/png", scope="fragment/post")


def test_media_migration_is_idempotent_and_updates_references(app, tmp_path):
    media_root = tmp_path / "legacy-media"
    source = media_root / "images" / "cover.jpg"
    source.parent.mkdir(parents=True)
    source.write_bytes(b"legacy-cover")
    destination = LocalObjectStorage(str(tmp_path / "objects"), "https://cdn.example.test")
    database = app.extensions["database"]
    session = database.session_factory()
    city = session.query(CityModel).first()
    city.hero_image = "images/cover.jpg"
    now = datetime.now(UTC)
    session.add(
        MediaAssetModel(
            key="migration-cover",
            storage_path="images/cover.jpg",
            mime_type="image/jpeg",
            metadata_json={},
            created_at=now,
            updated_at=now,
        )
    )
    session.commit()
    session.close()
    service = MediaMigrationService(database.session_factory, destination, str(media_root))

    dry_run = service.migrate(dry_run=True)
    first = service.migrate()
    second = service.migrate()

    assert dry_run["uploaded"] == 1 and dry_run["updated"] == 0
    assert "images/cover.jpg" not in dry_run["missing"]
    assert first["uploaded"] == 1 and first["updated"] == 1
    assert second["uploaded"] == 0 and second["skipped"] == 1
    session = database.session_factory()
    asset = session.get(MediaAssetModel, "migration-cover")
    city = (
        session.query(CityModel)
        .filter(CityModel.hero_image.like("https://cdn.example.test/%"))
        .one()
    )
    assert (
        asset.object_key
        == "public/content/77/7758c1fe2412b1ceb5ff90bedaa92e5d282d78c2bc80009ea552cd4fa45a56ad.jpg"
    )
    assert city.hero_image == asset.canonical_url
    session.close()
