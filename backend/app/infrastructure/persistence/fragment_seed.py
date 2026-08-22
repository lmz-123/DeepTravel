from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.infrastructure.persistence.models import (
    ClaimSourceModel,
    FragmentClaimModel,
    FragmentDependencyModel,
    HistoricalClaimModel,
    HistoricalSourceModel,
    PhotoMissionModel,
    RouteModel,
    StoryArcModel,
    StoryFragmentModel,
    TriggerRegionModel,
)

ARC_ID = "nantou-arc-v1"
SCRIPT_VERSION = "nantou-2026.08-review.1"
MEDIA_ROOT = Path(__file__).resolve().parents[3] / "media"

SOURCES = (
    {
        "id": "source-nanshan-chronology",
        "title": "建置沿革",
        "publisher": "深圳市南山区人民政府",
        "url": "https://www.szns.gov.cn/mlns/nsgk/content/post_12563286.html",
        "summary": "南山区官方建置沿革，支持郡县设置、迁界复界、县治迁移及深圳设市时间线。",
    },
    {
        "id": "source-nantou-wall",
        "title": "南头古城垣",
        "publisher": "南山区文化广电旅游体育局",
        "url": "https://www.szns.gov.cn/mlns/whns/wwbhdw/content/post_12573705.html",
        "summary": "文物保护单位资料，支持现存城垣与明代东莞守御千户所城的关系。",
    },
    {
        "id": "source-nantou-museum",
        "title": "南头古城博物馆",
        "publisher": "深圳政府在线",
        "url": "https://www.sz.gov.cn/szzt2010/szwtt/wtcg/whcg/content/post_11132704.html",
        "summary": "官方博物馆资料，提供南头行政与海防历史的概览。",
    },
    {
        "id": "source-nantou-renewal",
        "title": "南头古城：深圳首个国家级旅游休闲街区",
        "publisher": "深圳市文化广电旅游体育局",
        "url": "https://wtl.sz.gov.cn/lyfw/lyxw/content/post_10984289.html",
        "summary": "官方文旅资料，支持当代微更新及古城在现代深圳中的再解释。",
    },
)

CLAIMS = (
    (
        "claim-331",
        "331年，东官郡及宝安县行政建置以南头一带为中心。",
        "date_event",
        "documented",
        "行政建置年代不等于现存城门砖石年代。",
        ("source-nanshan-chronology",),
    ),
    (
        "claim-757",
        "757年，宝安县治迁往今天的东莞一带。",
        "date_event",
        "documented",
        "用于说明行政中心迁移，不推断南头完全失去功能。",
        ("source-nanshan-chronology",),
    ),
    (
        "claim-1394",
        "1394年，明代在南头修筑东莞守御千户所城。",
        "date_event",
        "documented",
        "现地构件的原真性仍需逐项现场审计。",
        ("source-nantou-wall", "source-nantou-museum"),
    ),
    (
        "claim-1573",
        "1573年，从东莞县析置新安县，县治设于南头。",
        "date_event",
        "documented",
        "县衙展示空间不得在未核验时称为原构。",
        ("source-nanshan-chronology", "source-nantou-museum"),
    ),
    (
        "claim-evacuation",
        "康熙五年至七年迁界，新安县一度裁撤并入东莞，康熙八年复置。",
        "policy_event",
        "documented",
        "广场不是迁界遗址；叙事明确这是制度史而非眼前物证。",
        ("source-nanshan-chronology",),
    ),
    (
        "claim-1914",
        "1914年，新安县更名为宝安县。",
        "date_event",
        "documented",
        "名称变化不等于城址移动。",
        ("source-nanshan-chronology",),
    ),
    (
        "claim-1953",
        "1953年，宝安县治从南头迁往深圳镇。",
        "date_event",
        "documented",
        "说明现代行政中心再次迁移。",
        ("source-nanshan-chronology",),
    ),
    (
        "claim-1979",
        "1979年宝安县改为深圳市，1980年深圳经济特区建立。",
        "date_event",
        "documented",
        "现代城市扩张与南头古城不是简单线性生长关系。",
        ("source-nanshan-chronology",),
    ),
    (
        "claim-renewal",
        "当代微更新让南头成为现代深圳重新阅读旧有时间层次的场所。",
        "interpretation",
        "editorial_inference",
        "这是基于更新资料的编辑解释，不作为单一因果事实。",
        ("source-nantou-renewal",),
    ),
)

FRAGMENTS = (
    {
        "id": "nantou-fragment-1",
        "stop_id": "7a62d937-205d-40e9-bba0-200000000001",
        "position": 1,
        "title": "两个年份，一道城门",
        "safe_preview": "从南门辨认一座城市为何会拥有两个起点。",
        "script": (
            "很多介绍把南头称为有一千七百年历史的古城。但请看清眼前这道门："
            "三百三十一年，指的是东官郡治和宝安县治设在南头一带；一三九四年，"
            "才是官方资料记载的南头城垣始建年代。行政建置的年龄，不等于眼前砖石的年龄。"
            "抬头寻找宁南两个字，把石匾和门洞一起拍下来。你收集的第一条线索是："
            "一座城，可以同时拥有不止一个起点。接下来要问的是，如果南头已经成为中心，"
            "为什么中心后来又离开了？"
        ),
        "interaction": "photo",
        "claim": "331年的行政起点与1394年的城垣起点不是同一件事。",
        "answers": "深圳城市史为何可从南头讲起。",
        "raises": "既已成为中心，为什么中心后来离开？",
        "authenticity": "field_audit_required",
        "claims": ("claim-331", "claim-1394"),
        "coordinates": (22.53810, 113.92270),
        "mission": {
            "id": "nantou-mission-1",
            "prompt": (
                "将“宁南”石匾与门洞的位置关系拍进同一画面。它帮助你区分建置年代与可见城垣年代。"
            ),
            "subject": "南门“宁南”石匾及其所在门洞",
            "authenticity": "field_audit_required",
        },
    },
    {
        "id": "nantou-fragment-2",
        "stop_id": "7a62d937-205d-40e9-bba0-200000000002",
        "position": 2,
        "title": "中心离开之后，城为什么还在",
        "safe_preview": "寻找行政中心离开后，地点仍被保留的另一种力量。",
        "script": (
            "唐至德二年，宝安县治从南头迁往今天的东莞一带。南头失去了县治，"
            "却没有从地图上消失。数百年后的一三九四年，明朝在这里修筑东莞守御千户所城。"
            "你刚才看到的城门，首先属于这一层海防与守御的历史。中心离开之后，"
            "地点仍可能因为海岸、航路和军事位置而重要。第二条线索是："
            "同一座城的功能可以更换，而旧身份不会自动消失。现在的问题变成了，"
            "一个军事所城，后来为什么又成了县城？"
        ),
        "interaction": "passive",
        "claim": "757年县治迁走后，1394年的海防建城赋予南头不同功能。",
        "answers": "中心离开后南头为何仍重要。",
        "raises": "军事所城后来为何又成为县城？",
        "authenticity": "interpretive_location",
        "claims": ("claim-757", "claim-1394"),
        "coordinates": (22.53903, 113.92314),
    },
    {
        "id": "nantou-fragment-3",
        "stop_id": "7a62d937-205d-40e9-bba0-200000000003",
        "position": 3,
        "title": "“新安”不是景点名，而是一套治理",
        "safe_preview": "从一个县名追踪命令、诉求与资源如何经过一座城。",
        "script": (
            "一五七三年，东莞县析置新安县，县治设在南头。这里重新成为行政中心。"
            "新安不是后来包装出来的古城名称，它意味着县的建置、辖境和日常治理重新落在这里。"
            "县城里的门、街道和衙署不是孤立景点，而是一套让命令、诉求和资源流动起来的空间。"
            "第三条线索是：所谓中心，不只是一栋重要建筑，而是许多事务都必须经过这里。"
            "可一纸行政命令既能建立中心，也能让它突然停止。"
        ),
        "interaction": "photo",
        "claim": "1573年新安县设立并以南头为县治，恢复行政中心地位。",
        "answers": "军事所城如何重新承载县治。",
        "raises": "制度能建立中心，也能怎样让它停止？",
        "authenticity": "exhibition_interpretation",
        "claims": ("claim-1573",),
        "coordinates": (22.53960, 113.92293),
        "mission": {
            "id": "nantou-mission-3",
            "prompt": (
                "拍下一处明确写有说明文字的县治展示。当前展示属于解释性陈列，不把它当作明代原构。"
            ),
            "subject": "公开区域内标明性质的县治解释性展示",
            "authenticity": "exhibition_interpretation",
        },
    },
    {
        "id": "nantou-fragment-4",
        "stop_id": "7a62d937-205d-40e9-bba0-200000000004",
        "position": 4,
        "title": "地图上的三年，居民的一次断裂",
        "safe_preview": "听见没有留下纪念物的历史空白。",
        "script": (
            "清康熙五年至七年，迁界令把沿海居民向内迁移，距离先是五十里，后来扩大到八十里。"
            "新安县一度被裁撤并入东莞，康熙八年才恢复。行政沿革里只是裁撤和复置几个字，"
            "对居民却意味着住房、土地、交易和邻里关系被迫中断。你所在的广场不是迁界遗址，"
            "不能拿眼前一堵旧墙冒充证据。第四条线索因此看不见：历史有时留下建筑，"
            "有时只留下制度造成的空白。恢复县治，也不代表南头从此永远是中心。"
        ),
        "interaction": "passive",
        "claim": "迁界同时中断了县级建置与沿海居民生活。",
        "answers": "行政命令如何让中心与生活同时中断。",
        "raises": "恢复县治后，南头是否会永远保持中心？",
        "authenticity": "no_direct_field_evidence",
        "claims": ("claim-evacuation",),
        "coordinates": (22.54015, 113.92318),
    },
    {
        "id": "nantou-fragment-5",
        "stop_id": "7a62d937-205d-40e9-bba0-200000000005",
        "position": 5,
        "title": "当深圳离开南头，又回来寻找南头",
        "safe_preview": "把旧街与现代用途放进同一个问题。",
        "script": (
            "一九一四年，新安县更名为宝安县。到一九五三年，宝安县治从南头迁往深圳镇。"
            "南头没有失去历史，却再次失去了行政中心的位置。此后二十多年，"
            "宝安县改为深圳市，经济特区建立，新的城市规模远远越过旧城墙。今天，"
            "南头通过微更新保留街巷肌理，又加入展览、商业和新的生活方式。"
            "请拍下一处新旧用途同框的地方。最后一条线索是：深圳并不是简单从南头长成今天的样子；"
            "城市中心一次次迁移，而现代深圳又回到南头寻找自己的时间深度。"
        ),
        "interaction": "photo",
        "claim": "1953年后行政中心迁离南头，现代更新又赋予旧城新的文化角色。",
        "answers": "南头为何再次失去中心，又如何被现代深圳重读。",
        "raises": "不同制度怎样反复改变“中心”的含义？",
        "authenticity": "coexistence_not_event_proof",
        "claims": ("claim-1914", "claim-1953", "claim-1979", "claim-renewal"),
        "coordinates": (22.54065, 113.92335),
        "mission": {
            "id": "nantou-mission-5",
            "prompt": (
                "拍下一处旧材料或街巷尺度与当代用途同框的画面。它只说明共存，不证明某个古代事件。"
            ),
            "subject": "旧空间层次与明确当代用途的并置",
            "authenticity": "coexistence_not_event_proof",
        },
    },
)

CAUSAL_MODEL = [
    "行政建置早于现存城垣",
    "县治迁走，不等于地点失去所有功能",
    "军事所城后来承载新安县治",
    "国家政策可以让行政中心和居民生活同时中断",
    "现代中心迁走后，旧城被重新赋予历史与文化角色",
]

COMPLETE_STORY = (
    "南头的故事不是一座古城如何完整保存了一千七百年，而是同一个地点如何被不同制度反复使用。"
    "三百三十一年的南头，是郡县行政的起点；一三九四年的南头，是明代沿海守御体系中的所城；"
    "一五七三年以后，它又成为新安县治。迁界曾让县的建置和居民生活一度中断，"
    "复置之后它继续作为县城，直到一九五三年县治迁往深圳镇。现代深圳的中心离开了南头，"
    "却又在城市更新中回来解释南头。你拍到的城门、新旧街巷和当代用途，"
    "并不能单独证明全部历史；它们是入口。真正被拼起来的，"
    "是行政、军事、人口与城市发展如何一次次改变中心的含义。"
)


def seed_fragment_tour(session: Session, route_id: str) -> bool:
    now = datetime.now(UTC)
    changed = False
    for item in SOURCES:
        if session.get(HistoricalSourceModel, item["id"]) is None:
            session.add(
                HistoricalSourceModel(
                    accessed_at=now, review_state="in_review", source_type="government", **item
                )
            )
            changed = True
    session.flush()
    for claim_id, text, kind, certainty, boundary, source_ids in CLAIMS:
        if session.get(HistoricalClaimModel, claim_id) is None:
            session.add(
                HistoricalClaimModel(
                    id=claim_id,
                    canonical_text=text,
                    claim_kind=kind,
                    certainty=certainty,
                    review_state="in_review",
                    boundary_note=boundary,
                )
            )
            session.flush()
            for source_id in source_ids:
                session.add(
                    ClaimSourceModel(
                        claim_id=claim_id,
                        source_id=source_id,
                        support_note="支持该条时间线或解释边界；发布前仍需编辑复核。",
                    )
                )
            changed = True
    arc = session.get(StoryArcModel, ARC_ID)
    if arc is None:
        arc = StoryArcModel(
            id=ARC_ID,
            route_id=route_id,
            title="迁移的中心：南头如何成为深圳，又如何失去深圳",
            central_question="为什么深圳的城市史从南头讲起，而今天的深圳中心却不在南头？",
            complete_story=COMPLETE_STORY,
            causal_model_json=CAUSAL_MODEL,
            pronunciation_notes_json=["东官郡：dōng guān jùn", "迁界：qiān jiè", "新安：xīn ān"],
            script_version=SCRIPT_VERSION,
            review_state="in_review",
            field_audit_state="required",
        )
        session.add(arc)
        session.flush()
        changed = True
    for item in FRAGMENTS:
        fragment = session.get(StoryFragmentModel, item["id"])
        audio_path = f"audio/{item['id']}-{SCRIPT_VERSION}.m4a"
        audio_file = MEDIA_ROOT / audio_path
        audio_size = audio_file.stat().st_size if audio_file.is_file() else 0
        if fragment is None:
            fragment = StoryFragmentModel(
                id=item["id"],
                arc_id=ARC_ID,
                stop_id=item["stop_id"],
                position=item["position"],
                title=item["title"],
                safe_preview=item["safe_preview"],
                narration_script=item["script"],
                transcript=item["script"],
                audio_path=audio_path,
                audio_mime_type="audio/mp4",
                audio_size_bytes=audio_size,
                script_version=SCRIPT_VERSION,
                interaction_type=item["interaction"],
                completion_threshold=0.9,
                key_claim=item["claim"],
                answers_question=item["answers"],
                raises_question=item["raises"],
                authenticity_label=item["authenticity"],
                review_state="in_review",
            )
            session.add(fragment)
            session.flush()
            lat, lon = item["coordinates"]
            session.add(
                TriggerRegionModel(
                    id=f"trigger-{item['id']}",
                    fragment_id=item["id"],
                    latitude=lat,
                    longitude=lon,
                    entry_radius_m=60,
                    exit_radius_m=90,
                    max_accuracy_m=50,
                    qualifying_samples=2,
                    sample_window_seconds=15,
                    cooldown_seconds=120,
                    audit_state="in_review",
                )
            )
            for claim_id in item["claims"]:
                session.add(FragmentClaimModel(fragment_id=item["id"], claim_id=claim_id))
            if item.get("mission"):
                mission = item["mission"]
                session.add(
                    PhotoMissionModel(
                        id=mission["id"],
                        fragment_id=item["id"],
                        prompt=mission["prompt"],
                        field_subject=mission["subject"],
                        safety_copy="请停在安全、允许拍照且不妨碍他人的位置；可稍后完成。",
                        accessibility_alternative="若无法拍照，可阅读文字线索；研究版仍保留任务待完成状态。",
                        authenticity_label=mission["authenticity"],
                        required=True,
                        audit_state="in_review",
                    )
                )
            changed = True
        elif (
            fragment.narration_script != item["script"] or fragment.script_version != SCRIPT_VERSION
        ):
            fragment.narration_script = item["script"]
            fragment.transcript = item["script"]
            fragment.audio_path = audio_path
            fragment.script_version = SCRIPT_VERSION
            fragment.audio_size_bytes = audio_size
            changed = True
        elif fragment.audio_size_bytes != audio_size:
            fragment.audio_size_bytes = audio_size
            changed = True
    for position in range(2, 6):
        fragment_id = f"nantou-fragment-{position}"
        required_id = f"nantou-fragment-{position - 1}"
        existing = session.scalar(
            select(FragmentDependencyModel).where(
                FragmentDependencyModel.fragment_id == fragment_id,
                FragmentDependencyModel.required_fragment_id == required_id,
            )
        )
        if existing is None:
            session.add(
                FragmentDependencyModel(fragment_id=fragment_id, required_fragment_id=required_id)
            )
            changed = True
    route = session.get(RouteModel, route_id)
    if route is not None:
        route.title = "迁移的中心：南头如何成为深圳，又如何失去深圳"
        route.subtitle = "戴上耳机，沿五段真实史实拼回一座不断迁移的中心"
        route.description = (
            "在南头行走时，位置会唤醒五段彼此相扣的历史。"
            "听完故事、拍下现场线索，最后重构行政、军事、人口与现代城市如何反复改变这里。"
        )
        route.duration_minutes = 75
        route.distance_km = 1.6
        route.theme = "定位音频 · 碎片叙事"
        route.content_status = "published"
    session.flush()
    return changed


def validate_fragment_tour(session: Session) -> list[str]:
    errors: list[str] = []
    arc = session.get(StoryArcModel, ARC_ID)
    if arc is None or len(arc.fragments) != 5:
        return ["Nantou story arc must contain five fragments"]
    for fragment in arc.fragments:
        if fragment.narration_script != fragment.transcript:
            errors.append(f"{fragment.id}: transcript does not match canonical script")
        if not fragment.audio_path or not fragment.script_version:
            errors.append(f"{fragment.id}: narration metadata missing")
        if not fragment.key_claim or not fragment.answers_question or not fragment.raises_question:
            errors.append(f"{fragment.id}: causal narrative fields missing")
    if arc.review_state == "reviewed" and arc.field_audit_state != "reviewed":
        errors.append("production-ready arc requires reviewed field audit")
    return errors
