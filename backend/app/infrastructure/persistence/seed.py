from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.infrastructure.persistence.fragment_seed import seed_fragment_tour
from app.infrastructure.persistence.models import (
    ChallengeModel,
    CityModel,
    MediaAssetModel,
    RouteModel,
    StopModel,
)

SHANGHAI_CITY_ID = "2b2301c8-d36e-4aa5-a3a8-b1881cb3f001"
SHANGHAI_ROUTE_ID = "91608e67-dbad-4d26-889c-dd3089201001"
SHENZHEN_CITY_ID = "2b2301c8-d36e-4aa5-a3a8-b1881cb3f002"
SHENZHEN_ROUTE_ID = "91608e67-dbad-4d26-889c-dd3089201002"

MEDIA_ASSETS = (
    {"key": "route_wukang", "storage_path": "images/route_wukang.png", "mime_type": "image/png"},
    {"key": "stop_lane", "storage_path": "images/stop_lane.png", "mime_type": "image/png"},
    {
        "key": "route_shenzhen",
        "storage_path": "images/route_shenzhen.png",
        "mime_type": "image/png",
    },
)


SHANGHAI_STOPS = [
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


SHENZHEN_STOPS = [
    {
        "id": "7a62d937-205d-40e9-bba0-200000000001",
        "position": 1,
        "title": "南头古城南门",
        "kicker": "从一道门读城市的开篇",
        "address": "南头古城南门公共区域",
        "latitude": 22.53810,
        "longitude": 113.92270,
        "story_title": "城门不是句号，而是一层新的开头",
        "story_body": "先停在门外，不急着穿过去。观察门洞如何压低视线、收紧脚步，再把人送进更细密的街巷。古城的边界今天不再承担旧时的防御功能，却仍然用尺度提醒人们：这里与门外的城市节奏不同。",
        "insight": "历史空间未必靠宏大的遗迹被感知。一次由宽到窄、由明到暗的身体变化，也能让边界成为可读的城市记忆。",
        "prompt": "穿过南门时，最明显的空间变化是什么？",
        "hint": "留意道路宽度、光线和行走速度。",
        "options": ["空间收窄并引导人放慢", "道路突然变成高速公路", "建筑完全消失"],
        "correct_option": 0,
        "explanation": "门洞通过尺度和明暗变化形成过渡，让人自然从城市道路进入街巷空间。",
    },
    {
        "id": "7a62d937-205d-40e9-bba0-200000000002",
        "position": 2,
        "title": "新安县衙展示区",
        "kicker": "看一座城如何管理自己",
        "address": "南头古城新安县衙展示区附近",
        "latitude": 22.53903,
        "longitude": 113.92314,
        "story_title": "城市的历史，也藏在日常秩序里",
        "story_body": "谈起古城，人们容易只寻找战争与名人，但县衙所代表的是税赋、诉讼、文书与地方治理。试着把这里想象成一套日常运转的系统：谁在记录，谁来申诉，消息又如何沿着街道传递。",
        "insight": "理解城市不能只看建筑年代，还要追问空间曾经承载什么制度。治理方式塑造了道路、市场，也影响普通人的日常。",
        "prompt": "理解县衙空间时，哪种观察最接近它的历史作用？",
        "hint": "它不只是一栋好看的老建筑。",
        "options": ["关注办事、文书与公共秩序", "只寻找最佳自拍角度", "只计算屋顶颜色"],
        "correct_option": 0,
        "explanation": "县衙首先是一套地方治理发生的场所，制度和日常活动比外观更接近其核心。",
    },
    {
        "id": "7a62d937-205d-40e9-bba0-200000000003",
        "position": 3,
        "title": "报德广场",
        "kicker": "广场里的公共生活",
        "address": "南头古城报德广场附近",
        "latitude": 22.53960,
        "longitude": 113.92293,
        "story_title": "留白让街巷拥有共同的客厅",
        "story_body": "从窄巷走到较开阔的地方，先观察人们如何使用边缘：坐下、等人、聊天、看孩子玩耍。公共空间的价值不只由面积决定，更取决于它是否允许不同的人以自己的节奏停留。",
        "insight": "好的广场不是被设计得最满的地方，而是能容纳偶遇和临时用途的留白。使用者不断重新定义它。",
        "prompt": "判断一个小广场是否有活力，最值得观察什么？",
        "hint": "看看人们是否愿意停下来。",
        "options": ["停留方式是否多样", "地砖是否只有一种颜色", "招牌是否足够巨大"],
        "correct_option": 0,
        "explanation": "坐、站、交谈和穿行等多样行为，说明空间能够支持真实的公共生活。",
    },
    {
        "id": "7a62d937-205d-40e9-bba0-200000000004",
        "position": 4,
        "title": "中山南街",
        "kicker": "旧街巷里的新用途",
        "address": "南头古城中山南街公共步行区域",
        "latitude": 22.54015,
        "longitude": 113.92318,
        "story_title": "更新不是把时间擦干净",
        "story_body": "沿街寻找没有被统一抹平的细节：旧墙的肌理、新店的入口、居民使用的窗台。街区更新真正困难的部分，是让新的经营和审美进入之后，原来的生活仍能被看见。",
        "insight": "保存并不意味着冻结。判断更新质量时，可以观察新旧材料是否有层次、商业空间是否尊重居民边界。",
        "prompt": "哪种细节更能说明更新保留了时间层次？",
        "hint": "寻找新材料与旧痕迹之间的关系。",
        "options": ["新旧痕迹可以同时被辨认", "所有墙面完全一样", "只剩统一的大型广告"],
        "correct_option": 0,
        "explanation": "让不同年代的痕迹保持可读，比把街区处理成单一风格更能呈现真实历史。",
    },
    {
        "id": "7a62d937-205d-40e9-bba0-200000000005",
        "position": 5,
        "title": "北街口",
        "kicker": "回望一座仍在生长的古城",
        "address": "南头古城北侧公共街巷附近",
        "latitude": 22.54065,
        "longitude": 113.92335,
        "story_title": "古与今不是两条分开的时间线",
        "story_body": "走到路线最后，回头比较刚才经过的门、广场、店铺与居住空间。南头古城的意义不只是保存一个过去，而是让不同年代继续在有限空间里协商。你看到的每一次并置，都是城市仍在生长的证据。",
        "insight": "深度旅行的收获不是记住更多标签，而是建立一种观察方法：看边界、看用途、看谁在使用，并追问变化如何发生。",
        "prompt": "完成这段路线后，理解古城更新最合适的方式是什么？",
        "hint": "不要把历史和当代生活割裂开。",
        "options": ["观察不同年代如何共存", "只寻找最旧的一块砖", "避开所有日常生活"],
        "correct_option": 0,
        "explanation": "古城的价值来自历史痕迹与当代使用的持续关系，而不是某个孤立的旧物。",
    },
]


def _ensure_city_route(
    session: Session,
    *,
    city_id: str,
    city_slug: str,
    city_name: str,
    city_subtitle: str,
    city_latitude: float,
    city_longitude: float,
    route_id: str,
    route_slug: str,
    route_title: str,
    route_subtitle: str,
    route_description: str,
    route_duration_minutes: int,
    route_distance_km: float,
    route_theme: str,
    hero_image: str,
    stops: list[dict],
) -> bool:
    changed = False
    city = session.scalar(select(CityModel).where(CityModel.slug == city_slug))
    if city is None:
        city = CityModel(
            id=city_id,
            slug=city_slug,
            name=city_name,
            subtitle=city_subtitle,
            hero_image=hero_image,
            latitude=city_latitude,
            longitude=city_longitude,
        )
        session.add(city)
        changed = True
    else:
        city.hero_image = hero_image

    route = session.scalar(select(RouteModel).where(RouteModel.slug == route_slug))
    if route is None:
        route = RouteModel(
            id=route_id,
            city_id=city_id,
            slug=route_slug,
            title=route_title,
            subtitle=route_subtitle,
            description=route_description,
            duration_minutes=route_duration_minutes,
            distance_km=route_distance_km,
            difficulty="轻松",
            theme=route_theme,
            hero_image=hero_image,
            is_featured=True,
            content_status="demo_unverified",
            published_at=datetime.now(UTC),
        )
        session.add(route)
        changed = True
    else:
        route.hero_image = hero_image

    for item in stops:
        image = (
            "images/stop_lane.png"
            if city_slug == "shanghai" and item["position"] in {3, 4}
            else hero_image
        )
        existing_stop = session.get(StopModel, item["id"])
        if existing_stop:
            existing_stop.image = image
            continue
        stop = StopModel(
            id=item["id"],
            route_id=route_id,
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
            image=image,
            insight=item["insight"],
        )
        stop.challenge = ChallengeModel(
            id=f"{city_slug}-challenge-{item['position']}",
            stop_id=item["id"],
            prompt=item["prompt"],
            hint=item["hint"],
            options_json=item["options"],
            correct_option=item["correct_option"],
            explanation=item["explanation"],
        )
        session.add(stop)
        changed = True
    return changed


def seed_database(session: Session) -> bool:
    changed = False
    now = datetime.now(UTC)
    for item in MEDIA_ASSETS:
        if session.get(MediaAssetModel, item["key"]) is None:
            session.add(MediaAssetModel(created_at=now, updated_at=now, **item))
            changed = True

    changed |= _ensure_city_route(
        session,
        city_id=SHANGHAI_CITY_ID,
        city_slug="shanghai",
        city_name="上海",
        city_subtitle="从街角开始，读懂城市的层次",
        city_latitude=31.20534,
        city_longitude=121.43731,
        route_id=SHANGHAI_ROUTE_ID,
        route_slug="wukang-urban-slices",
        route_title="梧桐树下的城市切片",
        route_subtitle="从一栋楼、一扇门到一条街的生活史",
        route_description="沿武康路缓慢行走，用五次现场观察理解建筑如何顺应街道、边界如何制造安静、里弄如何连接生活，以及旧街区怎样面对新的使用方式。",
        route_duration_minutes=70,
        route_distance_km=2.8,
        route_theme="建筑与城市生活",
        hero_image="images/route_wukang.png",
        stops=SHANGHAI_STOPS,
    )
    changed |= _ensure_city_route(
        session,
        city_id=SHENZHEN_CITY_ID,
        city_slug="shenzhen",
        city_name="深圳",
        city_subtitle="在快速生长的城市里，寻找时间的叠层",
        city_latitude=22.53940,
        city_longitude=113.92305,
        route_id=SHENZHEN_ROUTE_ID,
        route_slug="nantou-time-layers",
        route_title="南头古城的时间叠层",
        route_subtitle="从城门、街巷到公共生活，读懂一座仍在生长的古城",
        route_description="在南头古城慢慢走过五个空间节点，从门洞的尺度、县衙代表的秩序、广场的公共生活，到旧街新用途之间的协商，观察深圳并不只有速度的一面。",
        route_duration_minutes=60,
        route_distance_km=1.6,
        route_theme="古城更新与公共生活",
        hero_image="images/route_shenzhen.png",
        stops=SHENZHEN_STOPS,
    )
    changed |= seed_fragment_tour(session, SHENZHEN_ROUTE_ID)
    session.commit()
    return changed
