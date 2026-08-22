#!/usr/bin/env python3
"""Build the reusable Shanghai fragmented-audio admin import package."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / "backend" / "media"
OUTPUT = ROOT / "docs" / "content-packages" / "shanghai-readable-city-v1.json"
VERSION = "shanghai-2026.08-reviewed.1"

SOURCES = [
    {"id":"source-sh-citywalk","title":"武康路-安福路街区","publisher":"上海市人民政府","url":"https://www.shanghai.gov.cn/citywalk/20260625/3492b1b945c146fc96c4585d7b04f00d.html","source_type":"government","accessed_at":"2026-08-22T00:00:00+00:00","review_state":"reviewed","summary":"确认街区位于衡复历史文化风貌区、约1.5公里，并记录建筑可阅读与街区提升。"},
    {"id":"source-sh-hengfu","title":"市政府新闻发布会问答实录（2020年7月31日）","publisher":"上海市人民政府","url":"https://www.shanghai.gov.cn/nw9820/20200906/0001-9820_1461946.html","source_type":"government_press_conference","accessed_at":"2026-08-22T00:00:00+00:00","review_state":"reviewed","summary":"说明衡复风貌区面积、历史建筑规模与以居住为特征的空间属性。"},
    {"id":"source-sh-repair","title":"百姓话思想：城市留风","publisher":"上海市人民政府","url":"https://www.shanghai.gov.cn/bxhsx/20221008/081345d16e7a4457b48c469ada77e222.html","source_type":"government_feature","accessed_at":"2026-08-22T00:00:00+00:00","review_state":"reviewed","summary":"记录武康大楼等老建筑修缮及传统修缮技艺传承。"},
    {"id":"source-sh-tourism-plan","title":"“十四五”时期深化世界著名旅游城市建设规划新闻发布会","publisher":"上海市人民政府","url":"https://www.shanghai.gov.cn/nw44138/20210924/94d2e3bc21d447468ef1afcbf47ee381.html","source_type":"government_policy","accessed_at":"2026-08-22T00:00:00+00:00","review_state":"reviewed","summary":"把建筑可阅读列入海派文化旅游集群建设。"},
    {"id":"source-sh-crowd","title":"徐汇警方全力做好“五一”长假安保工作","publisher":"上海市人民政府","url":"https://www.shanghai.gov.cn/nw15343/20250507/23e0e54f8d52431ebcd4cd165a4233f8.html","source_type":"government_public_safety","accessed_at":"2026-08-22T00:00:00+00:00","review_state":"reviewed","summary":"记录武康大楼因社交媒体成为热门目的地、路口客流与安全治理。"},
]

CLAIMS = [
    ("claim-sh-corridor","武康路—安福路街区位于衡复历史文化风貌区内，官方资料将其描述为约1.5公里的城市文脉承载区。","documented",["source-sh-citywalk"],"长度与区域定位来自官方街区介绍，不代表每栋沿街建筑都开放参观。"),
    ("claim-sh-residential","衡复风貌区首先是以居住为特征的历史城区，并非为旅游打卡而一次建成的景区。","documented",["source-sh-hengfu"],"‘首先’是对官方居住属性的编辑归纳，不抹去商业与公共文化功能。"),
    ("claim-sh-scale","2020年市政府新闻发布会资料称衡复风貌区约4.3平方公里，有1074幢优秀历史建筑。","reported",["source-sh-hengfu"],"数字对应发布会口径和时间，不外推为今天实时名录。"),
    ("claim-sh-repair","武康大楼等老建筑的延续依赖持续修缮和专业技艺传承，而非建筑自然保持不变。","documented_and_interpretive",["source-sh-repair"],"修缮事实有来源；‘不是自然不变’是基于修缮事实的解释。"),
    ("claim-sh-readable","建筑可阅读被纳入上海海派文化旅游集群建设，街区提升也把历史空间转化为可理解的公共叙事。","documented_and_interpretive",["source-sh-citywalk","source-sh-tourism-plan"],"政策方向有来源；具体标牌的解释效果需现场观察。"),
    ("claim-sh-platform","社交媒体传播使武康大楼成为高频打卡地，改变了原本居住街区被观看和使用的强度。","documented_and_interpretive",["source-sh-crowd","source-sh-hengfu"],"热门传播有官方报道；对使用强度的关系是编辑解释。"),
    ("claim-sh-governance","官方报道记录武康大楼六岔路口约70米范围历史瞬时客流峰值超过5000人，并采用防撞柱、动态布警与疏散预案。","reported",["source-sh-crowd"],"这是特定报道中的历史峰值，不代表常态客流。"),
]

FRAGMENTS = [
    {"id":"sh-readable-fragment-1","title":"它先是一栋住宅，不是一张背景图","lat":31.19925,"lon":121.43810,"place":"武康大楼北侧公共人行道","script":"先不要寻找最佳机位。请站在人行道内，看这栋楔形建筑怎样回应六岔路口。今天它常被压缩成一张上海照片，但这条路线要从一个相反的事实开始：衡复风貌区首先是以居住为特征的历史城区，不是为了游客一次建成的景区。门窗、阳台和转角都在提醒你，建筑内部长期承载的是日常生活。外观可以被所有人观看，居住却仍有边界。第一块线索是：城市地标在成为图像之前，先是一处被使用的住宅。接下来要问，老建筑为什么没有自动停在过去，而能继续留在今天？","claim_ids":["claim-sh-residential","claim-sh-scale"],"photo":{"prompt":"在人行道安全位置拍下建筑转角与住宅窗户的关系，不拍清住户和路人面部。","subject":"地标外观与住宅属性并存","safety":"绝不进入车道或占用路口；人多时跳过拍照。"}},
    {"id":"sh-readable-fragment-2","title":"留下来的不是旧，而是修缮","lat":31.20215,"lon":121.43735,"place":"武康路公共步行段","script":"沿武康路向北走，留意墙面、窗框、排水和树根边缘。历史建筑并不是被时间原封不动保存下来。上海市政府资料记录，修缮人员参与过武康大楼等老建筑的修缮，也专门学习和传承修缮技艺。保护因此不是把街区冻住，而是在材料老化、现实使用和历史细节之间不断选择。你眼前某一块新砖不能单独证明它用了哪种工艺，但街区整体仍可使用，本身就离不开持续维护。第二块线索是：所谓留下，是一连串当代决定的结果。可修好了建筑，还要怎样让陌生人读懂它？","claim_ids":["claim-sh-repair"],"photo":None},
    {"id":"sh-readable-fragment-3","title":"当建筑开始对路人说话","lat":31.20555,"lon":121.43805,"place":"武康路旅游咨询中心附近公共区域","script":"现在找一块建筑铭牌、导览牌或公共文化标识。上海把‘建筑可阅读’纳入海派文化旅游建设，武康路—安福路街区的官方介绍也把街区提升与建筑可阅读并列。标牌看起来很轻，却做了一件重要的事：它从漫长历史中挑选名字、年代和故事，交给今天的路人。阅读不是历史自己开口，而是机构、研究者和编辑组织证据后的叙述。好的导览会标明事实与解释的边界；坏的导览只留下传奇。第三块线索是：一条街成为文化目的地，还需要一套解释系统。解释带来理解，也会带来更多目光。","claim_ids":["claim-sh-corridor","claim-sh-readable"],"photo":{"prompt":"拍下一块公共建筑铭牌或导览信息，并让它所解释的建筑局部同时入镜。","subject":"解释系统与被解释建筑","safety":"只在宽阔人行道停留，不堵门、不拍二维码中的个人信息。"}},
    {"id":"sh-readable-fragment-4","title":"一公里半，被平台重新丈量","lat":31.20875,"lon":121.43885,"place":"武康路北段公共人行道","script":"官方资料把武康路—安福路街区描述为约一公里半的文脉承载区。可在手机平台里，距离常被重新丈量成几个机位、几家店和一串收藏。上海市政府报道也直接提到，武康大楼在社交媒体上频频出圈，成为游客体验上海的高频目的地。传播让更多人愿意走进历史街区，也可能让完整的生活空间被压成可复制的画面。这里不要简单责怪拍照：你也正在使用手机。真正的问题是，我们能否在获得一张照片的同时，仍看见住宅、维护和解释系统。第四块线索是：平台改变的不只是知名度，也改变街区被观看和使用的节奏。节奏加快以后，谁来处理公共安全与居民生活之间的摩擦？","claim_ids":["claim-sh-corridor","claim-sh-platform"],"photo":None},
    {"id":"sh-readable-fragment-5","title":"最红的机位，也是一个路口","lat":31.21185,"lon":121.44110,"place":"安福路与乌鲁木齐中路附近公共步行区域","script":"最后，把注意力放回路口、护栏、分流和行走的人。官方报道记录，武康大楼六岔路口约七十米范围内，历史瞬时客流峰值曾超过五千人，并提到防撞柱、动态布警和疏散预案。这个数字不是今天此刻的人数，也不该被用来制造热闹想象。它说明，当一个居住街区成为平台地标，城市必须为观看行为增加真实的治理成本。现在五块线索可以拼起来：住宅提供真实生活，修缮让材料延续，导览组织公共记忆，平台放大观看，治理重新协调边界。深度旅行不是拒绝拍照，而是在按下快门前，知道画面之外还有谁、还有什么制度共同维持这条街。","claim_ids":["claim-sh-platform","claim-sh-governance"],"photo":{"prompt":"拍下人行空间中的安全或分流设施，画面避免可识别人脸和机动车号牌。","subject":"热门街区背后的公共安全治理","safety":"不在交叉口停留，不跨护栏；拥挤时只听不拍。"}},
]


def media_entry(key: str, path: str, mime: str) -> dict:
    target = MEDIA / path
    return {"key":key,"storage_path":path,"mime_type":mime,"sha256":hashlib.sha256(target.read_bytes()).hexdigest() if target.exists() else ""}


def render_audio() -> None:
    for index, item in enumerate(FRAGMENTS, 1):
        destination = MEDIA / "audio" / f"shanghai-readable-{index}-{VERSION}.m4a"
        destination.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory() as directory:
            aiff = Path(directory) / "voice.aiff"
            subprocess.run(["say", "-v", "Tingting (中文（中国大陆）)", "-r", "178", "-o", str(aiff), item["script"]], check=True)
            subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", str(aiff), str(destination)], check=True)


def fragment(item: dict, position: int) -> dict:
    audio = f"audio/shanghai-readable-{position}-{VERSION}.m4a"
    dependency = [] if position == 1 else [FRAGMENTS[position - 2]["id"]]
    mission = item["photo"]
    return {
        "id":item["id"],"position":position,"title":item["title"],"safe_preview":"继续沿公共人行道前行，下一段故事将在安全位置出现。","narration_script":item["script"],"transcript":item["script"],"audio_path":audio,"audio_mime_type":"audio/mp4","audio_size_bytes": (MEDIA / audio).stat().st_size if (MEDIA / audio).exists() else 0,"script_version":VERSION,"interaction_type":"photo" if mission else "passive","completion_threshold":0.9,"key_claim":item["script"].split("第")[-1][:70],"answers_question":"上一块线索留下的问题","raises_question":"下一种力量如何改变街区？","authenticity_label":"documented_with_editorial_interpretation","review_state":"reviewed","claim_ids":item["claim_ids"],"dependency_ids":dependency,
        "stop":{"id":f"sh-readable-stop-{position}","title":item["place"],"kicker":item["title"],"address":item["place"],"latitude":item["lat"],"longitude":item["lon"],"arrival_radius_m":60,"story_title":item["title"],"story_body":item["script"],"audio_url":audio,"image":"images/route_wukang.png","insight":"现场观察只能支持当下可见关系，历史事实以关联来源为准。"},
        "trigger_region":{"id":f"sh-readable-trigger-{position}","latitude":item["lat"],"longitude":item["lon"],"entry_radius_m":60,"exit_radius_m":95,"max_accuracy_m":40,"qualifying_samples":2,"sample_window_seconds":15,"cooldown_seconds":120,"audit_state":"in_review","coordinate_system":"WGS84","source_coordinate_system":"WGS84_public_geodata","coordinate_source":"公共地理数据整理为WGS-84并按人行空间校核；首轮实地测试继续记录设备偏差","field_notes":"触发中心仅设置在公共人行空间；禁止进入车道和住宅。"},
        "photo_mission": None if not mission else {"id":f"sh-readable-mission-{position}","prompt":mission["prompt"],"field_subject":mission["subject"],"safety_copy":mission["safety"],"accessibility_alternative":"可跳过或稍后在安全位置补拍，不影响继续听完整故事。","authenticity_label":"present_day_observation_only","required":True,"audit_state":"in_review"}
    }


def build() -> dict:
    media = [media_entry("shanghai-city-cover","images/route_wukang.png","image/png")]
    media += [media_entry(f"sh-readable-audio-{i}",f"audio/shanghai-readable-{i}-{VERSION}.m4a","audio/mp4") for i in range(1,6)]
    claims = [{"id":identity,"canonical_text":text,"claim_kind":"historical_context","certainty":certainty,"review_state":"reviewed","boundary_note":note,"reviewed_by":"DeepTravel editorial","reviewed_at":"2026-08-22T00:00:00+00:00","source_ids":source_ids,"support_notes":{source:"官方资料直接支持或限定该主张。" for source in source_ids}} for identity,text,certainty,source_ids,note in CLAIMS]
    return {"package_id":"shanghai-readable-city","package_version":"2026.08-reviewed.1","media":media,"city":{"id":"2b2301c8-d36e-4aa5-a3a8-b1881cb3f001","slug":"shanghai","name":"上海","subtitle":"从街角开始，读懂城市的层次","hero_image":"images/route_wukang.png","latitude":31.20534,"longitude":121.43731},"route":{"id":"91608e67-dbad-4d26-889c-dd3089201004","slug":"shanghai-readable-city","title":"被观看的街区：武康路如何成为城市名片","subtitle":"从住宅、修缮、导览、平台到治理，拼出一条街的当代命运","description":"戴上耳机沿武康路向安福路慢行。五段位置旁白不把建筑当作空背景，而会追问居住、保护、公共叙事、社交传播与人流治理怎样共同塑造今天的衡复街区。","duration_minutes":70,"distance_km":1.5,"difficulty":"轻松","theme":"历史街区与平台城市","hero_image":"images/route_wukang.png","is_featured":True},"story_arc":{"id":"sh-readable-arc-v1","title":"一条居住街区如何变成被观看的城市名片","central_question":"当住宅街区成为全网共享的城市图像，历史、生活与公共空间如何重新协商？","complete_story":"衡复街区不是为游客搭建的布景，而是长期居住和使用形成的历史城区。持续修缮让建筑材料得以延续；建筑可阅读等公共文化政策又把专业知识组织成路人可理解的叙事。社交平台进一步放大少数机位和符号，使街区获得公共关注，也提高了居民边界、通行和安全治理的压力。今天的武康路因此不是旧上海被原样保存的标本，而是居住、保护、解释、传播与治理不断协商的结果。","causal_model":[{"id":"sh-cause-1","text":"长期居住赋予街区真实而非布景式的生活基础"},{"id":"sh-cause-2","text":"专业修缮把历史材料带入当代使用"},{"id":"sh-cause-3","text":"建筑可阅读把证据组织成公共叙事"},{"id":"sh-cause-4","text":"社交平台放大机位并改变街区使用节奏"},{"id":"sh-cause-5","text":"客流治理重新协调观看、安全与居住边界"}],"pronunciation_notes":["衡复：héng fù","邬鲁木齐中路：wū lǔ mù qí zhōng lù"],"script_version":VERSION,"review_state":"reviewed","field_audit_state":"required","reviewed_by":"DeepTravel editorial","reviewed_at":"2026-08-22T00:00:00+00:00","source_version":"shanghai-municipal-sources-2026.08.22","publication_decision":"field_test"},"required_photo_mission_count":3,"sources":SOURCES,"claims":claims,"fragments":[fragment(item,index) for index,item in enumerate(FRAGMENTS,1)]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--render-local-audio", action="store_true")
    args = parser.parse_args()
    if args.render_local_audio:
        render_audio()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(build(), ensure_ascii=False, indent=2) + "\n")
    print(OUTPUT)
