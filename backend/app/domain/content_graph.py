from __future__ import annotations

from collections.abc import Iterable
from hashlib import sha256
from math import asin, cos, radians, sin, sqrt
from random import Random
from typing import Any


def normalize_reconstruction_items(values: Iterable[dict[str, Any] | str]) -> list[dict[str, str]]:
    """Normalize legacy text entries and managed entries to stable id/text pairs."""
    items: list[dict[str, str]] = []
    for index, raw in enumerate(values):
        if isinstance(raw, dict):
            item_id = str(raw.get("id") or "").strip()
            text = str(raw.get("text") or "").strip()
        else:
            text = str(raw).strip()
            digest = sha256(text.encode("utf-8")).hexdigest()[:12]
            item_id = f"legacy-{index + 1}-{digest}"
        items.append({"id": item_id, "text": text})
    return items


def shuffled_reconstruction_items(
    values: Iterable[dict[str, Any] | str], *, journey_id: str
) -> list[dict[str, str]]:
    items = normalize_reconstruction_items(values)
    seed = int.from_bytes(sha256(journey_id.encode("utf-8")).digest()[:8], "big")
    Random(seed).shuffle(items)
    if len(items) > 1 and items == normalize_reconstruction_items(values):
        items = items[1:] + items[:1]
    return items


def reconstruction_ids(values: Iterable[dict[str, Any] | str]) -> list[str]:
    return [item["id"] for item in normalize_reconstruction_items(values)]


def validate_content_graph(
    graph: dict[str, Any], *, media_assets: dict[str, str] | None = None
) -> dict[str, Any]:
    """Validate a managed fragmented route without depending on Flask/FastAPI."""
    errors: list[dict[str, str]] = []
    warnings: list[dict[str, str]] = []
    media_assets = media_assets or {}
    route = graph.get("route") or {}
    arc = graph.get("story_arc") or {}
    fragments = list(graph.get("fragments") or [])
    sources = list(graph.get("sources") or [])
    claims = list(graph.get("claims") or [])

    def error(path: str, code: str, message: str) -> None:
        errors.append({"path": path, "code": code, "message": message})

    def warning(path: str, code: str, message: str) -> None:
        warnings.append({"path": path, "code": code, "message": message})

    for key in ("id", "slug", "title", "hero_image"):
        if not str(route.get(key) or "").strip():
            error(f"route.{key}", "required", "缺少必填路线字段")
    for key in ("id", "title", "central_question", "complete_story", "script_version"):
        if not str(arc.get(key) or "").strip():
            error(f"story_arc.{key}", "required", "缺少必填故事弧字段")
    if not fragments:
        error("fragments", "required", "碎片路线至少需要一个线索")

    positions = [item.get("position") for item in fragments]
    if positions != list(range(1, len(fragments) + 1)):
        error("fragments", "positions_not_contiguous", "线索顺序必须从 1 连续递增")
    fragment_ids = [str(item.get("id") or "") for item in fragments]
    if any(not item for item in fragment_ids) or len(set(fragment_ids)) != len(fragment_ids):
        error("fragments", "fragment_ids_invalid", "线索标识必须填写且不能重复")

    source_ids = {str(item.get("id") or "") for item in sources}
    claim_ids = {str(item.get("id") or "") for item in claims}
    if len(source_ids) != len(sources) or "" in source_ids:
        error("sources", "source_ids_invalid", "来源标识必须填写且不能重复")
    if len(claim_ids) != len(claims) or "" in claim_ids:
        error("claims", "claim_ids_invalid", "主张标识必须填写且不能重复")
    for index, source in enumerate(sources):
        for key in ("title", "publisher", "url"):
            if not str(source.get(key) or "").strip():
                error(f"sources[{index}].{key}", "required", "来源缺少标题、发布机构或链接")
    claim_sources = {
        str(item.get("id") or ""): set(map(str, item.get("source_ids") or [])) for item in claims
    }
    for index, claim in enumerate(claims):
        claim_id = str(claim.get("id") or "")
        if not claim_id or not str(claim.get("canonical_text") or "").strip():
            error(f"claims[{index}]", "claim_invalid", "史实主张缺少标识或正文")
        linked = claim_sources.get(claim_id, set())
        if not linked or not linked.issubset(source_ids):
            error(f"claims[{index}].source_ids", "claim_source_missing", "每条主张必须关联有效来源")

    required_photo_count = int(graph.get("required_photo_mission_count", 0))
    actual_photo_count = 0
    previous_region: dict[str, Any] | None = None
    previous_index = -1
    for index, fragment in enumerate(fragments):
        path = f"fragments[{index}]"
        for key in ("title", "narration_script", "transcript", "audio_path", "script_version"):
            if not str(fragment.get(key) or "").strip():
                error(f"{path}.{key}", "required", "线索缺少必填内容")
        if fragment.get("narration_script") != fragment.get("transcript"):
            error(f"{path}.transcript", "transcript_mismatch", "试听旁白必须与文字稿完全一致")
        if fragment.get("script_version") != arc.get("script_version"):
            error(f"{path}.script_version", "script_version_mismatch", "线索与故事弧脚本版本不一致")

        audio_path = str(fragment.get("audio_path") or "")
        if audio_path:
            mime = media_assets.get(audio_path)
            if mime is None:
                error(f"{path}.audio_path", "media_missing", "音频资源未在媒体库登记")
            elif not mime.startswith("audio/"):
                error(f"{path}.audio_path", "media_type_invalid", "旁白资源必须是音频")

        linked_claims = set(map(str, fragment.get("claim_ids") or []))
        if not linked_claims or not linked_claims.issubset(claim_ids):
            error(f"{path}.claim_ids", "fragment_claims_missing", "每个线索必须关联有效史实主张")

        dependencies = list(map(str, fragment.get("dependency_ids") or []))
        for dependency in dependencies:
            if dependency not in fragment_ids[:index]:
                error(f"{path}.dependency_ids", "dependency_invalid", "依赖必须指向前序线索")

        region = fragment.get("trigger_region") or {}
        for key in ("latitude", "longitude", "entry_radius_m", "exit_radius_m"):
            if region.get(key) is None:
                error(f"{path}.trigger_region.{key}", "required", "缺少定位区域字段")
        latitude = _float(region.get("latitude"))
        longitude = _float(region.get("longitude"))
        entry = _float(region.get("entry_radius_m"))
        exit_radius = _float(region.get("exit_radius_m"))
        max_accuracy = _float(region.get("max_accuracy_m"))
        qualifying_samples = _float(region.get("qualifying_samples"))
        sample_window = _float(region.get("sample_window_seconds"))
        if latitude is None or not -90 <= latitude <= 90:
            error(f"{path}.trigger_region.latitude", "wgs84_invalid", "纬度不是有效 WGS-84")
        if longitude is None or not -180 <= longitude <= 180:
            error(f"{path}.trigger_region.longitude", "wgs84_invalid", "经度不是有效 WGS-84")
        if entry is None or entry <= 0 or exit_radius is None or exit_radius <= entry:
            error(
                f"{path}.trigger_region.exit_radius_m",
                "hysteresis_invalid",
                "离开半径必须大于进入半径",
            )
        if max_accuracy is None or max_accuracy <= 0:
            error(
                f"{path}.trigger_region.max_accuracy_m",
                "sampling_invalid",
                "定位精度阈值必须大于零",
            )
        if (
            qualifying_samples is None
            or qualifying_samples < 1
            or sample_window is None
            or sample_window <= 0
        ):
            error(
                f"{path}.trigger_region.qualifying_samples",
                "sampling_invalid",
                "定位采样策略无效",
            )
        if str(region.get("coordinate_system") or "").upper().replace("-", "") != "WGS84":
            error(
                f"{path}.trigger_region.coordinate_system",
                "coordinate_system_invalid",
                "运行坐标必须是 WGS-84",
            )
        if not str(region.get("coordinate_source") or "").strip():
            error(
                f"{path}.trigger_region.coordinate_source",
                "coordinate_source_missing",
                "必须记录坐标来源",
            )
        if region.get("audit_state") != "reviewed":
            warning(
                f"{path}.trigger_region.audit_state",
                "field_review_required",
                "坐标仍需现场复核",
            )
        if previous_region and None not in (latitude, longitude, entry):
            prior_lat = _float(previous_region.get("latitude"))
            prior_lon = _float(previous_region.get("longitude"))
            prior_entry = _float(previous_region.get("entry_radius_m"))
            if None not in (prior_lat, prior_lon, prior_entry):
                distance = _distance_m(latitude, longitude, prior_lat, prior_lon)
                if distance <= entry + prior_entry + 30:
                    error(
                        f"{path}.trigger_region",
                        "trigger_regions_overlap",
                        f"与 fragments[{previous_index}] 的安全间距不足",
                    )
        previous_region = region
        previous_index = index

        mission = fragment.get("photo_mission")
        if mission:
            if mission.get("required"):
                actual_photo_count += 1
            for key in (
                "prompt",
                "field_subject",
                "vantage_point",
                "shooting_direction",
                "composition_tip",
                "safety_copy",
                "accessibility_alternative",
            ):
                if not str(mission.get(key) or "").strip():
                    error(f"{path}.photo_mission.{key}", "required", "照片任务缺少安全或替代说明")

    if actual_photo_count != required_photo_count:
        error("required_photo_mission_count", "mission_count_mismatch", "必做照片任务数量不匹配")

    cover_path = str(route.get("hero_image") or "")
    if cover_path:
        cover_mime = media_assets.get(cover_path)
        if cover_mime is None:
            error("route.hero_image", "media_missing", "路线封面未在媒体库登记")
        elif not cover_mime.startswith("image/"):
            error("route.hero_image", "media_type_invalid", "路线封面必须是图片")

    reconstruction = normalize_reconstruction_items(arc.get("causal_model") or [])
    ids = [item["id"] for item in reconstruction]
    texts = [item["text"] for item in reconstruction]
    if len(reconstruction) != len(fragments):
        error("story_arc.causal_model", "causal_count_mismatch", "因果项数量必须与线索数量一致")
    if (
        any(not item for item in ids + texts)
        or len(set(ids)) != len(ids)
        or len(set(texts)) != len(texts)
    ):
        error("story_arc.causal_model", "causal_items_invalid", "因果项标识和文字必须填写且唯一")

    if arc.get("review_state") != "reviewed":
        warning("story_arc.review_state", "editorial_review_required", "故事内容仍处于审核状态")
    return {"valid": not errors, "errors": errors, "warnings": warnings}


def _float(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _distance_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    earth_radius = 6_371_000.0
    phi1, phi2 = radians(lat1), radians(lat2)
    delta_phi = radians(lat2 - lat1)
    delta_lambda = radians(lon2 - lon1)
    value = sin(delta_phi / 2) ** 2 + cos(phi1) * cos(phi2) * sin(delta_lambda / 2) ** 2
    return 2 * earth_radius * asin(sqrt(value))
