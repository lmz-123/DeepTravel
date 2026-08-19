from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.infrastructure.persistence.models import (
    ChallengeModel,
    CityModel,
    MediaAssetModel,
    RouteModel,
    StopModel,
)

CITY_ID = "2b2301c8-d36e-4aa5-a3a8-b1881cb3f001"
ROUTE_ID = "91608e67-dbad-4d26-889c-dd3089201001"

MEDIA_ASSETS = (
    {"key": "route_wukang", "storage_path": "images/route_wukang.png", "mime_type": "image/png"},
    {"key": "stop_lane", "storage_path": "images/stop_lane.png", "mime_type": "image/png"},
)


STOPS = [
    {
        "id": "8fa6c9b1-5e3a-40df-b5c8-100000000001",
        "position": 1,
        "title": "武康大楼",
        "kicker": "先看它如何转身",
        "address": "淮海中路与武康路交会处",
        "latitude": 31.19967,
        "longitude": 121.43876,
        "story_title": "一栋顺着街角生长的建筑",
        "story_body": "先别急着拍下整栋楼。站到街角对面，沿着它最窄的一端慢慢向两侧看：建筑并没有把转角当作障碍，而是把道路的夹角变成了自己的轮廓。城市建筑有时像一本摊开的书，街道决定了书脊的位置。",
        "insight": "真正值得观察的并不只是建筑风格，而是建筑如何回应街道。转角、退界与首层店面共同塑造了这里的公共生活。",
        "prompt": "从最窄的一端看过去，这栋建筑的轮廓最像什么？",
        "hint": "留意两条道路汇合形成的尖角。",
        "options": ["一艘停靠街角的船", "一座对称的宫殿", "一排独立的小屋"],
        "correct_option": 0,
        "explanation": "建筑顺应锐角地块展开，最窄端形成了常被人联想到船首的视觉效果。",
    },
    {
        "id": "8fa6c9b1-5e3a-40df-b5c8-100000000002",
        "position": 2,
        "title": "宋庆龄故居外",
        "kicker": "从围墙读懂尺度",
        "address": "淮海中路 1843 号附近",
        "latitude": 31.20174,
        "longitude": 121.43692,
        "story_title": "被树荫留住的安静",
        "story_body": "一处住所和城市的关系，往往先由围墙、树木与入口讲出来。观察这里从车流到庭院的层层过渡：喧闹没有突然消失，而是被距离、植物和边界一点点过滤。",
        "insight": "深度游不是进入每一栋建筑。仅从公共空间观察边界、树冠和入口，也能理解一处场所如何安排私密与开放。",
        "prompt": "这里用什么元素完成了从繁忙道路到安静庭院的过渡？",
        "hint": "答案不是单一物件，而是一组连续的空间。",
        "options": ["高台阶和霓虹招牌", "围墙、树木与入口距离", "完全敞开的广场"],
        "correct_option": 1,
        "explanation": "围墙提供边界，树木吸收视线和噪声，入口距离则形成心理缓冲。",
    },
    {
        "id": "8fa6c9b1-5e3a-40df-b5c8-100000000003",
        "position": 3,
        "title": "里弄门洞",
        "kicker": "寻找街道的第二层",
        "address": "武康路中段公共步行区域",
        "latitude": 31.20534,
        "longitude": 121.43731,
        "story_title": "门洞后面，还有一条城市",
        "story_body": "沿街立面只是城市的封面。门洞把公共街道连接到更细小的内部通道，生活、晾晒、邻里往来和出入秩序都在另一层空间里发生。请只在公共区域观察，不进入私人院落。",
        "insight": "街区的丰富度来自空间层级：主路、支路、门洞与院落并不是孤立的，它们组成了生活网络。观察时也要尊重居住者的边界。",
        "prompt": "门洞在这里最重要的空间作用是什么？",
        "hint": "想想它连接了哪两种尺度。",
        "options": ["只用于装饰立面", "连接公共街道与内部生活空间", "专门扩大机动车道路"],
        "correct_option": 1,
        "explanation": "门洞是公共街道与半私密内部空间之间的转换节点。",
    },
    {
        "id": "8fa6c9b1-5e3a-40df-b5c8-100000000004",
        "position": 4,
        "title": "巴金故居外",
        "kicker": "一扇窗的阅读方式",
        "address": "武康路 113 号附近",
        "latitude": 31.20831,
        "longitude": 121.43756,
        "story_title": "日常空间如何成为记忆",
        "story_body": "名人故居容易让人只寻找姓名和年代，但一处创作空间也由采光、窗景、街道声音和日常动线组成。试着想象，长期居住者每天看到的并不是景点，而是一段不断变化的街景。",
        "insight": "人文历史并不只在纪念牌上。把人物放回具体的房间、光线和街道，记忆才从知识点变成生活。",
        "prompt": "理解一处故居时，除了人物生平，还值得观察什么？",
        "hint": "寻找日常生活与创作发生的环境线索。",
        "options": ["只看纪念牌的字体", "采光、窗景与街道关系", "只统计游客数量"],
        "correct_option": 1,
        "explanation": "空间尺度、光线和周边环境能帮助我们理解人物真实的日常。",
    },
    {
        "id": "8fa6c9b1-5e3a-40df-b5c8-100000000005",
        "position": 5,
        "title": "武康庭附近",
        "kicker": "旧街区的新用途",
        "address": "武康路 376 号附近",
        "latitude": 31.21156,
        "longitude": 121.43818,
        "story_title": "保存，不等于冻结",
        "story_body": "走到路线最后，观察老建筑与今天的店铺、展览和公共停留如何共处。街区保护并不意味着把时间停住；更难的问题是，让新的使用方式既维持活力，也不过度挤压原有生活。",
        "insight": "一座城市的深度，常常存在于新旧用途的协商之中。好的更新既要让空间继续被使用，也要保留可被理解的历史层次。",
        "prompt": "判断一次街区更新是否友好，最值得关注什么？",
        "hint": "不要只看建筑是否变漂亮。",
        "options": ["新旧用途能否共存并尊重原有生活", "店铺招牌是否足够大", "拍照点是否足够集中"],
        "correct_option": 0,
        "explanation": "持续使用、历史可读性和居民生活之间的平衡，比单纯美化更重要。",
    },
]


def seed_database(session: Session) -> bool:
    changed = False
    now = datetime.now(UTC)
    for item in MEDIA_ASSETS:
        if session.get(MediaAssetModel, item["key"]) is None:
            session.add(MediaAssetModel(created_at=now, updated_at=now, **item))
            changed = True

    existing_city = session.scalar(select(CityModel).where(CityModel.slug == "shanghai"))
    if existing_city:
        existing_city.hero_image = "images/route_wukang.png"
        existing_route = session.scalar(
            select(RouteModel).where(RouteModel.slug == "wukang-urban-slices")
        )
        if existing_route:
            existing_route.hero_image = "images/route_wukang.png"
            for stop in existing_route.stops:
                stop.image = (
                    "images/stop_lane.png"
                    if stop.position in {3, 4}
                    else "images/route_wukang.png"
                )
        session.commit()
        return changed

    city = CityModel(
        id=CITY_ID,
        slug="shanghai",
        name="上海",
        subtitle="从街角开始，读懂城市的层次",
        hero_image="images/route_wukang.png",
        latitude=31.20534,
        longitude=121.43731,
    )
    route = RouteModel(
        id=ROUTE_ID,
        city_id=CITY_ID,
        slug="wukang-urban-slices",
        title="梧桐树下的城市切片",
        subtitle="从一栋楼、一扇门到一条街的生活史",
        description="沿武康路缓慢行走，用五次现场观察理解建筑如何顺应街道、边界如何制造安静、里弄如何连接生活，以及旧街区怎样面对新的使用方式。",
        duration_minutes=70,
        distance_km=2.8,
        difficulty="轻松",
        theme="建筑与城市生活",
        hero_image="images/route_wukang.png",
        is_featured=True,
        content_status="demo_unverified",
        published_at=datetime.now(UTC),
    )
    city.routes.append(route)
    for item in STOPS:
        stop = StopModel(
            id=item["id"],
            route_id=ROUTE_ID,
            position=item["position"],
            title=item["title"],
            kicker=item["kicker"],
            address=item["address"],
            latitude=item["latitude"],
            longitude=item["longitude"],
            arrival_radius_m=100,
            story_title=item["story_title"],
            story_body=item["story_body"],
            audio_url=None,
            image="images/stop_lane.png"
            if item["position"] in {3, 4}
            else "images/route_wukang.png",
            insight=item["insight"],
        )
        stop.challenge = ChallengeModel(
            id=f"challenge-{item['position']}",
            stop_id=item["id"],
            prompt=item["prompt"],
            hint=item["hint"],
            options_json=item["options"],
            correct_option=item["correct_option"],
            explanation=item["explanation"],
        )
        route.stops.append(stop)
    session.add(city)
    session.commit()
    return True
