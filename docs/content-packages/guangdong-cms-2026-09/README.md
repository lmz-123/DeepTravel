# 广东新增景点 · CMS 发布快照

2026-09-30 通过 CMS 管理 API 创建珠海、广州，以及 7 个景区、21 个具体地点。所有封面上传、内容写入和旁白生成都经过 CMS；没有修改数据库、种子数据或在客户端写入城市特例。

用户确认全部发布后，7 个景区已通过 CMS 的 `submit-review → verify → publish` 流程，状态均为 `published`。发布校验均无错误；保留真实的编辑审核与现场坐标复核警告，发布类型为 `field_test`，没有伪造实地审核记录。该目录是发布后的 CMS 内容快照，资源引用对应当前共享 OSS 媒体库。

| 城市 | 已发布景区 | 具体地点 |
| --- | --- | --- |
| 广州 | [沙面](guangzhou-shamian.json) | 沙面堂 → 白天鹅宾馆江畔 → 露德圣母堂 |
| 广州 | [永庆坊](guangzhou-yongqingfang.json) | 金声电影院旧址 → 八和会馆 → 粤剧艺术博物馆 |
| 深圳 | [大梅沙](shenzhen-dameisha.json) | 风信长廊入口 → 幸福·生存雕塑 → 东侧观景点 |
| 深圳 | [万象天地](shenzhen-mixc-world.json) | 万象天地南侧主入口 → 万象天地剧场北侧 → 抱抱象 |
| 深圳 | [梧桐山](shenzhen-wutong-mountain.json) | 北大门牌坊 → 泰山涧步桥 → 凤凰台 |
| 珠海 | [情侣路海滨](zhuhai-lovers-road.json) | 珠海渔女 → 海滨公园步桥 → 爱情邮局 |
| 珠海 | [野狸岛·日月贝](zhuhai-yeli-island.json) | 海燕桥 → 得月舫 → 珠海大剧院 |

## 定位与旁白

- 每个地点有独立 WGS84 坐标与可追溯来源；没有把景区中心复制给子点。坐标来自公开地图/百科，包括部分建筑代表点，尚未做现场设备采样。描述性名称（如入口、步桥、观景点）不冒充正式景点名称。
- 进入半径 60 米、离开半径 90 米、精度阈值 35 米、2 次合格采样、15 秒采样窗口。每条路线任意两点间距均大于 150 米；实际公共步行位置和通行状态仍需现场复核。
- 21 段旁白均通过 CMS 生成，使用原「温柔同行者」：`Chinese (Mandarin)_Warm_HeartedGirl`、`calm`、语速 `0.94`、音调 `0`，模型 `speech-2.8-hd`。全部音频匿名 Range 请求成功，全文长度与 SHA256 均匹配登记值。
- 七个景区公共详情接口均返回 200，深圳、珠海、广州城市列表已包含新增景区；21 段旁白及 7 张封面均通过公开 HTTP 访问检查。已有三项图片媒体未变更。
- 客户端联网进入「随刊」或「路线」，在顶部下拉刷新以更新城市和景区列表；仅切换标签或从详情返回不会刷新。无需重新打包。
- 已安装版本的随刊曾在存在推荐景区时隐藏其他景区，导致深圳仅显示南头。通过 CMS 将大梅沙、梧桐山、万象天地加入首页推荐后，现有客户端的首页列表为 4 个；客户端同时修正为展示全部已发布景区，推荐只决定排序，防止后续新景区再次被隐藏。
- 梧桐山按山地徒步配置，时长和里程为编辑估计；不是导航路径或实时开放信息。

## 封面署名

真实景点照片取自 Wikimedia Commons。CMS 做 JPEG 标准化，来源照片未作其他编辑；保留各自的 CC BY-SA 许可。署名与许可也写入各路线 CMS 的来源/主张记录，发布内容保留署名。

| 景区 | 作者 | 原图来源 | 许可 |
| --- | --- | --- | --- |
| 沙面 | Ricky Chow | [ShaMianBuildings.JPG](https://commons.wikimedia.org/wiki/File:ShaMianBuildings.JPG) | [CC BY-SA 3.0](http://creativecommons.org/licenses/by-sa/3.0/) |
| 永庆坊 | PQ77wd | [WingHingFong.jpg](https://commons.wikimedia.org/wiki/File:WingHingFong.jpg) | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) |
| 大梅沙 | User Jack Chui on zh.wikipedia | [深圳大梅沙.jpg](https://commons.wikimedia.org/wiki/File:%E6%B7%B1%E5%9C%B3%E5%A4%A7%E6%A2%85%E6%B2%99.jpg) | [CC BY-SA 2.0](https://creativecommons.org/licenses/by-sa/2.0) |
| 万象天地 | Charlie fong | [Huarun Wanxiang World in Nanshan2021.jpg](https://commons.wikimedia.org/wiki/File:Huarun_Wanxiang_World_in_Nanshan2021.jpg) | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) |
| 梧桐山 | Ivor | [Ngtungsaan.JPG](https://commons.wikimedia.org/wiki/File:Ngtungsaan.JPG) | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0) |
| 情侣路海滨 | 钉钉 | [Zhuhai Fisher Girl statue.jpg](https://commons.wikimedia.org/wiki/File:Zhuhai_Fisher_Girl_statue.jpg) | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) |
| 野狸岛·日月贝 | 钉钉 | [Zhuhai Grand Theatre 34.jpg](https://commons.wikimedia.org/wiki/File:Zhuhai_Grand_Theatre_34.jpg) | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) |

## 原南头音频修复

原南头路线五个音频地址返回 OSS `404 NoSuchKey`。已用相同音色生成并更新五段音轨，保留原路线文字、地点、触发区域和标识；失效旧音色经全局使用审计后可逆归档。详见 [音频核验记录](../../verification/audio-cms-2026-09-30.md)。

本次没有重新打包客户端，没有新增后端或 CMS 源码变更，因此无需服务部署。
