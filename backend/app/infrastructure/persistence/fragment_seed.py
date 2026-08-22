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
SCRIPT_VERSION = "nantou-2026.08-conversational.2"
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
            "我们现在到南门了。先别急着把“一千七百年古城”这句话背下来，抬头看看门洞上方，"
            "能找到“宁南”两个字吗？南头有两个很容易混在一起的生日：三百三十一年，说的是东官郡治和"
            "宝安县治设在南头一带；一三九四年，才是官方资料记载的南头城垣始建年代。也就是说，"
            "行政上的南头比眼前这道城门更早。要是你想留张照片，可以站到门外公共步行区稍稍偏左，"
            "把石匾放在画面上方三分之一，连同完整门洞一起收进去。这样回看照片时，两个年代就不会打架了。"
            "一座城原来可以有不止一个起点。那它既然做过中心，后来为什么又把中心的位置让了出去呢？"
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
                "想留念的话，把“宁南”石匾和完整门洞拍进同一张方形画面；这张照片正好记住南头的两个起点。"
            ),
            "subject": "南门“宁南”石匾及其所在门洞",
            "vantage_point": "站在南门外公共步行区正前方略偏左，避开门洞通行线。",
            "shooting_direction": "面向南门，将“宁南”石匾和完整门洞同时收入画面。",
            "composition_tip": "把石匾放在上方三分之一处，保留门洞两侧墙体作为历史层次。",
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
            "往里走一点，回头想想刚才那道城门。唐至德二年，宝安县治迁去了今天的东莞一带，"
            "南头不再是县治，却没有从历史里退场。几百年后的一三九四年，明代又在这里修筑东莞守御千户所城。"
            "你刚刚穿过的门，更多对应的是这段海防与守御历史。行政中心搬走了，海岸、航路和军事位置却还在，"
            "所以同一个地方换了工作，仍然重要。南头有点像一位转过行的老朋友：身份变了，过去没有被清空。"
            "接下来更有意思——这座军事所城，为什么后来又重新变成了县城？"
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
            "我们现在靠近县治展示区域了。先看说明牌，再看空间本身，别急着把展陈当成明代原构。"
            "一五七三年，东莞县析置新安县，县治设在南头，这里于是又回到了行政中心的位置。"
            "“新安”并不是后来给景区取的雅号，它代表一整套县的建置、辖境和日常治理。门、街道和衙署也不是"
            "各自站着的景点，而是让命令、诉求和资源在城里流动的系统。如果想拍照，找一处写清展示性质的说明，"
            "让说明牌占画面下方三分之一，环境一起入镜，就不会把今天的解释误认成古代原物。"
            "所谓中心，原来不是一栋最气派的房子，而是很多事情都要经过这里。可建立它的行政命令，也能让它突然停下。"
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
                "找一处写明性质的县治展示，把说明文字和周围空间一起拍下；它是今天帮助我们理解历史的展陈。"
            ),
            "subject": "公开区域内标明性质的县治解释性展示",
            "vantage_point": "站在展示区公共参观线外侧，不跨越围挡或影响讲解队伍。",
            "shooting_direction": "正对带有说明文字的展示，让文字与空间关系同时可辨。",
            "composition_tip": "说明牌占画面下三分之一，展示主体居中，并保留环境判断其陈列性质。",
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
            "这一段不用寻找某件“打卡物”，我们在稍微安静的地方听就好。清康熙五年至七年，迁界令让沿海居民"
            "向内迁移，距离先是五十里，后来扩大到八十里；新安县也一度被裁撤并入东莞，康熙八年才恢复。"
            "沿革表上只有“裁撤、复置”几个字，落到普通人的生活里，却是住房、土地、交易和邻里关系被迫断开。"
            "眼前的广场不是迁界遗址，旁边的旧墙也不能替那段历史作证。这里最值得记住的，恰好是一块看不见的空白："
            "历史有时留下建筑，有时只留下制度改变生活的痕迹。县治虽然恢复了，南头也不会永远坐在中心的位置上。"
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
            "走到这里，旧墙、店铺和今天的生活已经挤进同一幅画面了。一九一四年，新安县更名为宝安县；"
            "一九五三年，宝安县治又从南头迁往深圳镇。南头没有丢掉自己的历史，却再次让出了行政中心。"
            "再过二十多年，宝安县改为深圳市，经济特区建立，城市很快长到旧城墙之外。今天的南头通过微更新"
            "保留街巷尺度，也装进展览、商业和新的生活方式。如果你想拍最后一张留念，可以在北街口较宽的公共步行区"
            "停一下，用前后景把旧材料和新用途放在同一张方形照片里，别堵住店门和居民通道。"
            "深圳并不是从南头一路直线长成今天的样子；它把中心一次次搬走，又回来向南头寻找自己的时间深度。"
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
                "把旧墙或街巷尺度与今天的店铺、展览或公共生活放进同一张方形照片，留住新旧正在一起生活的样子。"
            ),
            "subject": "旧空间层次与明确当代用途的并置",
            "vantage_point": "选择北街口公共步行区较宽处停留，避开店铺出入口和居民通道。",
            "shooting_direction": "朝向一处旧墙、街巷尺度与当代店铺或公共使用并存的界面。",
            "composition_tip": "用前后景同时容纳旧材料和新用途，避免只拍招牌而失去街巷尺度。",
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
    "如果现在有人再问你，南头到底有多少年历史，你大概不会只给出一个数字了。"
    "三百三十一年，是郡县行政在南头一带落下的起点；一三九四年，明代沿海守御体系在这里修筑所城；"
    "一五七三年以后，南头又成为新安县治。后来迁界让县的建置和许多居民的生活一起中断，复置之后，"
    "它继续做了很久的县城，直到一九五三年县治迁往深圳镇。现代深圳的中心离开南头，城市迅速越过旧城墙，"
    "却又在更新中回到这里，重新理解自己的来处。你沿途看到的城门、街巷和新旧用途，不能单独证明所有往事，"
    "但它们像一扇扇入口，让行政、海防、人口与城市发展重新连在一起。南头最动人的地方，也许不是它一直站在中心，"
    "而是每次中心搬走、身份改变之后，它都留下了一点东西，等今天的我们慢慢看懂。"
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
            title="深圳把中心搬走以后，为什么又回来找南头？",
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
    arc_values = {
        "title": "深圳把中心搬走以后，为什么又回来找南头？",
        "central_question": "为什么深圳的城市史从南头讲起，而今天的深圳中心却不在南头？",
        "complete_story": COMPLETE_STORY,
        "causal_model_json": CAUSAL_MODEL,
        "pronunciation_notes_json": [
            "东官郡：dōng guān jùn",
            "迁界：qiān jiè",
            "新安：xīn ān",
        ],
        "script_version": SCRIPT_VERSION,
    }
    for field_name, value in arc_values.items():
        if getattr(arc, field_name) != value:
            setattr(arc, field_name, value)
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
                    entry_radius_m=14,
                    exit_radius_m=35,
                    max_accuracy_m=20,
                    qualifying_samples=2,
                    sample_window_seconds=15,
                    cooldown_seconds=120,
                    audit_state="in_review",
                    coordinate_system="WGS84",
                    source_coordinate_system="WGS84",
                    coordinate_source=(
                        "南头古城公开地图候选点，经 WGS-84 整理，发布前需现场设备复核"
                    ),
                    field_notes="仅在公共步行区域停留；确认定位精度、通行空间与安全站位。",
                )
            )
            for claim_id in item["claims"]:
                session.add(FragmentClaimModel(fragment_id=item["id"], claim_id=claim_id))
            changed = True
        else:
            fragment_values = {
                "position": item["position"],
                "title": item["title"],
                "safe_preview": item["safe_preview"],
                "narration_script": item["script"],
                "transcript": item["script"],
                "audio_path": audio_path,
                "audio_size_bytes": audio_size,
                "script_version": SCRIPT_VERSION,
                "interaction_type": item["interaction"],
                "key_claim": item["claim"],
                "answers_question": item["answers"],
                "raises_question": item["raises"],
                "authenticity_label": item["authenticity"],
            }
            for field_name, value in fragment_values.items():
                if getattr(fragment, field_name) != value:
                    setattr(fragment, field_name, value)
                    changed = True
        region = session.scalar(
            select(TriggerRegionModel).where(TriggerRegionModel.fragment_id == item["id"])
        )
        if region is not None:
            region_values = {
                "entry_radius_m": 14,
                "exit_radius_m": 35,
                "max_accuracy_m": 20,
                "coordinate_system": "WGS84",
                "source_coordinate_system": "WGS84",
                "coordinate_source": (
                    "南头古城公开地图候选点，经 WGS-84 整理，发布前需现场设备复核"
                ),
                "field_notes": "仅在公共步行区域停留；确认定位精度、通行空间与安全站位。",
            }
            for field_name, value in region_values.items():
                if getattr(region, field_name) != value:
                    setattr(region, field_name, value)
                    changed = True
        mission_data = item.get("mission")
        if mission_data:
            mission = session.get(PhotoMissionModel, mission_data["id"])
            values = {
                "prompt": mission_data["prompt"],
                "field_subject": mission_data["subject"],
                "vantage_point": mission_data["vantage_point"],
                "shooting_direction": mission_data["shooting_direction"],
                "composition_tip": mission_data["composition_tip"],
                "safety_copy": "请停在安全、允许拍照且不妨碍他人的位置；可稍后完成。",
                "accessibility_alternative": "若无法拍照，可跳过并继续路线，之后仍可回来留念。",
                "authenticity_label": mission_data["authenticity"],
                "required": False,
                "audit_state": "in_review",
            }
            if mission is None:
                session.add(
                    PhotoMissionModel(
                        id=mission_data["id"], fragment_id=item["id"], **values
                    )
                )
                changed = True
            else:
                for field_name, value in values.items():
                    if getattr(mission, field_name) != value:
                        setattr(mission, field_name, value)
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
        route.title = "深圳把中心搬走以后，为什么又回来找南头？"
        route.subtitle = "戴上耳机，沿着城门与老街听懂一座不断换身份的城"
        route.description = (
            "我们会从南门慢慢走进老城，沿途听五段彼此相扣的故事。"
            "照片都不是任务，遇到喜欢的机位再停下来；走完以后，你会明白深圳为什么离开南头，又为什么回来。"
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
