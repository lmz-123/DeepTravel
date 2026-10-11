import json

import pytest

from tests.test_community import _login
from tests.test_community_discovery import _publish_place, _share


def test_guide_roundtrip_filter_idempotency_and_hidden_content(app, client):
    _, author = _login(client, "tester-a")
    _, viewer = _login(client, "tester-b")
    place = _publish_place(app, client, author)
    items = [{"title": "带好证件", "body": "和入园凭证放在一起"}, {"title": "雨具"}]
    fields = dict(
        category="guide",
        title="出发前准备",
        preparation_items=json.dumps(items),
        idempotency_key="guide-one",
    )
    response = _share(client, author, place, **fields)
    assert response.status_code == 201, response.get_json()
    post = response.get_json()["data"]
    assert post["category_label"] == "攻略"
    assert post["preparation_items"][1] == {"title": "雨具", "body": ""}
    assert _share(client, author, place, **fields).get_json()["data"]["id"] == post["id"]
    url = f"/api/v1/community-posts/{post['id']}"
    assert (
        client.get(url, headers=viewer).get_json()["data"]["preparation_items"]
        == post["preparation_items"]
    )
    feed = "/api/v1/community-posts?category=guide&route=" + place["route_slug"]
    assert client.get(feed, headers=viewer).get_json()["data"]["items"][0]["id"] == post["id"]
    assert not client.get(
        "/api/v1/community-posts?category=guide&route=other", headers=viewer
    ).get_json()["data"]["items"]
    assert client.delete(url, headers=author).status_code == 200
    assert not client.get(feed, headers=viewer).get_json()["data"]["items"]


@pytest.mark.parametrize(
    "items",
    [
        "{",
        "null",
        "{}",
        "[]",
        "[1]",
        '[{"title":" "}]',
        '[{"title":"a","body":12}]',
        json.dumps([{"title": "x" * 61}]),
        json.dumps([{"title": "x", "body": "x" * 301}]),
        json.dumps([{"title": "x"}] * 13),
    ],
)
def test_guide_invalid_checklists(app, client, items):
    _, author = _login(client, "tester-a")
    place = _publish_place(app, client, author)
    response = _share(
        client, author, place, category="guide", title="准备", preparation_items=items
    )
    assert response.status_code == 422, response.get_json()


def test_guide_requires_title_and_only_guides_accept_checklists(app, client):
    _, author = _login(client, "tester-a")
    place = _publish_place(app, client, author)
    items = json.dumps([{"title": "帽子"}])
    assert (
        _share(client, author, place, category="guide", preparation_items=items).status_code == 422
    )
    assert (
        _share(client, author, place, category="on_site", preparation_items=items).status_code
        == 422
    )
