from hashlib import sha256
from io import BytesIO

import pytest
from PIL import Image

from app.infrastructure.community_media_storage import (
    CommunityMediaStorage,
    CommunityMediaUnavailableError,
)
from app.infrastructure.object_storage import InMemoryObjectStorage
from tests.test_community import _image, _login
from tests.test_community_discovery import _publish_place, _share


def test_upload_generates_webp_previews_preserves_detail_and_no_upscale():
    objects = InMemoryObjectStorage("test")
    storage = CommunityMediaStorage(objects, 10 * 1024 * 1024, 1920)
    full = storage.put(_image(size=(1800, 1200)), "image/jpeg", scope="test")
    with storage.open(full.object_key) as source:
        assert sha256(source.read()).hexdigest() == full.sha256
    for variant, size in [("thumbnail", (240, 160)), ("preview", (960, 640))]:
        with storage.open_variant(full.object_key, variant) as source:
            image = Image.open(source)
            assert image.format == "WEBP"
            assert image.size == size
            assert not image.getexif()
    small = storage.put(_image(size=(80, 60)), "image/jpeg", scope="test")
    with storage.open_variant(small.object_key, "preview") as source:
        assert Image.open(source).size == (80, 60)
    storage.delete(full.object_key)
    assert not any(key.startswith(full.object_key) for key in objects._objects)


def test_new_png_is_stored_as_webp_with_transparency():
    objects = InMemoryObjectStorage("test")
    storage = CommunityMediaStorage(objects, 10 * 1024 * 1024, 1920)
    raw = BytesIO()
    Image.new("RGBA", (800, 600), (40, 120, 80, 100)).save(raw, "PNG")
    raw.seek(0)
    full = storage.put(raw, "image/png", scope="test")
    assert full.mime_type == "image/webp"
    assert full.object_key.endswith(".webp")
    assert not any(key.endswith(".png") for key in objects._objects)
    with storage.open(full.object_key) as source:
        assert Image.open(source).getpixel((0, 0))[3] == 100


def test_legacy_derivative_created_once_without_changing_source():
    objects = InMemoryObjectStorage("test")
    storage = CommunityMediaStorage(objects, 10 * 1024 * 1024, 1920)
    source = _image(size=(1600, 1000)).read()
    objects.put("community/legacy.jpg", source, "image/jpeg")
    first = storage.open_variant("community/legacy.jpg", "preview").read()
    # A subsequent request must read the persisted variant, not re-encode.
    storage._resize = lambda *_: pytest.fail("re-encoded existing preview")
    assert storage.open_variant("community/legacy.jpg", "preview").read() == first
    assert objects.open("community/legacy.jpg").read() == source


def test_failed_variant_upload_rolls_back_all_new_objects():
    class FailingStorage(InMemoryObjectStorage):
        def put(self, key, payload, mime_type):
            if ".preview-" in key:
                raise OSError("upload failed")
            return super().put(key, payload, mime_type)

    objects = FailingStorage("test")
    storage = CommunityMediaStorage(objects, 10 * 1024 * 1024, 1920)
    with pytest.raises(CommunityMediaUnavailableError):
        storage.put(_image(), "image/jpeg", scope="test")
    assert objects._objects == {}


def test_variants_require_same_access_as_full_image(app, client):
    _, author = _login(client, "tester-a")
    _, viewer = _login(client, "tester-b")
    place = _publish_place(app, client, author)
    post = _share(client, author, place, photos=(_image(size=(1600, 1000)), "view.jpg")).get_json()[
        "data"
    ]
    url = post["media"][0]["url"]
    for variant, edge in [("thumbnail", 240), ("preview", 960), ("full", 1600)]:
        endpoint = url + "?variant=" + variant
        assert client.get(endpoint).status_code == 401
        response = client.get(endpoint, headers=viewer)
        assert response.status_code == 200
        assert max(Image.open(BytesIO(response.data)).size) == edge
        if variant != "full":
            assert response.mimetype == "image/webp"
    assert client.get(url + "?variant=arbitrary", headers=viewer).status_code == 422
    client.post(
        f"/api/v1/community-posts/{post['id']}/reports", headers=viewer, json={"reason": "spam"}
    )
    for variant in ["thumbnail", "preview", "full"]:
        assert client.get(url + "?variant=" + variant, headers=viewer).status_code == 404
        assert client.get(url + "?variant=" + variant, headers=author).status_code == 200
