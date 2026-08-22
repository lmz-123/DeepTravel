import hashlib
import json
from copy import deepcopy
from pathlib import Path

from app.domain.content_graph import (
    normalize_reconstruction_items,
    shuffled_reconstruction_items,
    validate_content_graph,
)


def _graph() -> dict:
    fragments = []
    claims = []
    for index in range(3):
        position = index + 1
        fragment_id = f"fragment-{position}"
        claim_id = f"claim-{position}"
        claims.append(
            {
                "id": claim_id,
                "canonical_text": f"事实 {position}",
                "source_ids": ["source-1"],
            }
        )
        fragments.append(
            {
                "id": fragment_id,
                "position": position,
                "title": f"线索 {position}",
                "narration_script": f"旁白 {position}",
                "transcript": f"旁白 {position}",
                "audio_path": f"audio/{position}.m4a",
                "script_version": "route-v1",
                "claim_ids": [claim_id],
                "dependency_ids": [] if index == 0 else [f"fragment-{index}"],
                "trigger_region": {
                    "latitude": 22.60 - index * 0.003,
                    "longitude": 114.30,
                    "entry_radius_m": 55,
                    "exit_radius_m": 90,
                    "max_accuracy_m": 35,
                    "qualifying_samples": 2,
                    "sample_window_seconds": 15,
                    "coordinate_system": "WGS84",
                    "source_coordinate_system": "WGS84",
                    "coordinate_source": "field candidate",
                    "audit_state": "in_review",
                },
                "photo_mission": {
                    "prompt": "拍摄现场",
                    "field_subject": "公共空间",
                    "safety_copy": "仅在安全时拍摄",
                    "accessibility_alternative": "可以稍后完成",
                    "required": True,
                }
                if index == 0
                else None,
            }
        )
    return {
        "route": {
            "id": "route-1",
            "slug": "generic-route",
            "title": "通用路线",
            "hero_image": "images/cover.webp",
        },
        "story_arc": {
            "id": "arc-1",
            "title": "故事弧",
            "central_question": "这里为何改变？",
            "complete_story": "完整故事",
            "script_version": "route-v1",
            "review_state": "in_review",
            "causal_model": [
                {"id": f"cause-{index + 1}", "text": f"关系 {index + 1}"} for index in range(3)
            ],
        },
        "sources": [
            {
                "id": "source-1",
                "title": "来源",
                "publisher": "测试机构",
                "url": "https://example.test/source",
            }
        ],
        "claims": claims,
        "fragments": fragments,
        "required_photo_mission_count": 1,
    }


def _media() -> dict[str, str]:
    return {
        "images/cover.webp": "image/webp",
        "audio/1.m4a": "audio/mp4",
        "audio/2.m4a": "audio/mp4",
        "audio/3.m4a": "audio/mp4",
    }


def test_valid_graph_passes_with_review_warnings():
    result = validate_content_graph(_graph(), media_assets=_media())
    assert result["valid"] is True
    assert result["errors"] == []
    assert {item["code"] for item in result["warnings"]} == {
        "editorial_review_required",
        "field_review_required",
    }


def test_graph_rejects_overlap_bad_dependencies_and_missing_media():
    graph = deepcopy(_graph())
    graph["fragments"][1]["trigger_region"]["latitude"] = 22.6001
    graph["fragments"][1]["dependency_ids"] = ["fragment-3"]
    graph["fragments"][1]["audio_path"] = "audio/missing.m4a"
    result = validate_content_graph(graph, media_assets=_media())
    assert result["valid"] is False
    codes = {item["code"] for item in result["errors"]}
    assert {"trigger_regions_overlap", "dependency_invalid", "media_missing"} <= codes


def test_legacy_reconstruction_items_get_stable_ids_and_deterministic_shuffle():
    legacy = ["第一层关系", "第二层关系", "第三层关系"]
    first = normalize_reconstruction_items(legacy)
    second = normalize_reconstruction_items(legacy)
    assert first == second
    assert [item["text"] for item in first] == legacy
    shuffled = shuffled_reconstruction_items(legacy, journey_id="journey-a")
    assert shuffled == shuffled_reconstruction_items(legacy, journey_id="journey-a")
    assert {item["id"] for item in shuffled} == {item["id"] for item in first}
    assert shuffled != first


def test_dameisha_package_graph_and_media_are_complete():
    root = Path(__file__).parents[2]
    package = json.loads((root / "docs/content-packages/dameisha-remade-coast-v1.json").read_text())
    media = {item["storage_path"]: item["mime_type"] for item in package["media"]}

    result = validate_content_graph(package, media_assets=media)

    assert result["valid"] is True, result["errors"]
    assert len(package["fragments"]) == 5
    assert (
        sum(
            bool((item.get("photo_mission") or {}).get("required")) for item in package["fragments"]
        )
        == 3
    )
    for item in package["media"]:
        path = root / "backend/media" / item["storage_path"]
        assert path.is_file()
        assert hashlib.sha256(path.read_bytes()).hexdigest() == item["sha256"]
    for fragment in package["fragments"]:
        assert fragment["narration_script"] == fragment["transcript"]


def test_shanghai_readable_city_package_is_generic_audio_photo_content():
    root = Path(__file__).parents[2]
    package = json.loads(
        (root / "docs/content-packages/shanghai-readable-city-v1.json").read_text()
    )
    media = {item["storage_path"]: item["mime_type"] for item in package["media"]}

    result = validate_content_graph(package, media_assets=media)

    assert result["valid"] is True, result["errors"]
    assert package["route"]["slug"] == "shanghai-readable-city"
    assert len(package["fragments"]) == 5
    assert sum(item["interaction_type"] == "photo" for item in package["fragments"]) == 3
    assert {item["interaction_type"] for item in package["fragments"]} <= {
        "passive",
        "photo",
    }
    assert all(
        item["trigger_region"]["coordinate_system"] == "WGS84" for item in package["fragments"]
    )
    assert all("answer" not in item for item in package["fragments"])
    for item in package["media"]:
        path = root / "backend/media" / item["storage_path"]
        assert path.is_file()
        assert hashlib.sha256(path.read_bytes()).hexdigest() == item["sha256"]
