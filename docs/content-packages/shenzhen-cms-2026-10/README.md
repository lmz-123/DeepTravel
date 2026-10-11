# 深圳景点补充 · 2026-10-11

本次在现有深圳 4 处景点之外，通过线上 CMS 新增并发布 **14 处景点、14 段原创讲解及对应语音**，深圳已发布景点合计 18 处。未修改客户端、服务端源码或已有景点。

## 选点与内容

以深圳市文化广电旅游体育局 [2026 年 A 级旅游景区名录](https://wtl.sz.gov.cn/ggfw/lyl/jqjdylb/index.html)及市政府旅游资料为线索，覆盖主题乐园、城市休闲地标、历史街区、植物科普与滨海公园。逐处来源、照片许可和候选坐标均保存在 JSON 的 sources/claims 中，并关联到讲解记录。

| 景点 | 讲解方向 | 入园说明 |
| --- | --- | --- |
| [大芬油画村](shenzhen-dafen.json) | 画布背后的产业与村落 | 公共区域免费，部分项目另收费 |
| [大鹏所城](shenzhen-dapeng-fortress.json) | 城门与街巷里的海防历史 | 公共区域免费，部分项目另收费 |
| [仙湖植物园](shenzhen-fairylake.json) | 一座植物园怎样保存生命 | 需门票 |
| [甘坑古镇](shenzhen-gankeng.json) | 客家村落与河流相邻 | 公共区域免费，部分项目另收费 |
| [深圳欢乐谷](shenzhen-happy-valley.json) | 在主题场景里体验游乐 | 需门票 |
| [莲花山公园](shenzhen-lianhuashan.json) | 七座山头与城市中轴 | 公共区域免费，部分项目另收费 |
| [东部华侨城](shenzhen-oct-east.json) | 山地中的主题度假区 | 需门票 |
| [欢乐海岸](shenzhen-oct-harbour.json) | 水岸与街巷连接的城市空间 | 公共区域免费，部分项目另收费 |
| [欢乐港湾](shenzhen-oh-bay.json) | 在前海湾岸边看城市 | 公共区域免费，部分项目另收费 |
| [深圳野生动物园](shenzhen-safari-park.json) | 从动物行为开始观察 | 需门票 |
| [海上世界](shenzhen-sea-world.json) | 明华轮与蛇口的城市记忆 | 公共区域免费，部分项目另收费 |
| [深圳湾公园](shenzhen-shenzhen-bay.json) | 为红树林让出的海岸 | 公共区域免费，部分项目另收费 |
| [锦绣中华·民俗村](shenzhen-splendid-china.json) | 从微缩山河到民俗体验 | 需门票 |
| [世界之窗](shenzhen-window-world.json) | 世界建筑的微缩旅行 | 需门票 |

讲解每篇约 250–300 字，以可核查的地点知识为核心；同时标明哪些是编辑提供的观察建议。历史事件写明确切年份；不把过期活动、促销价或旧馆资料当成实时信息。主题园区布局可能变化，不承诺老资料中的设备仍在运行。

## 发布与验证

- CMS 媒体上传 → 内容草稿 → 沿用“温柔同行者”生成语音 → 内容校验 → 提交审核 → verify → publish。14 处发布状态均为 published，旁白覆盖 ready。
- 沿用 MiniMax `speech-2.8-hd`、既有音色配置；脚本与 transcript 一致。媒体通过 CMS 写入共享 OSS。
- 每景点设置 **一个有来源的介绍点**，未凭中心坐标虚构多个游览站点。坐标来自 Wikipedia 地点坐标或 Commons 照片地理信息，可能是代表位置，不是精确入口；现场触发与步行可达性尚未实测。
- 保留 `field_audit_state=required`、`review_state=in_review` 与 `publication_decision=field_test`。CMS 发布流程通过不等于有人完成了现场审计。
- 进入/退出半径 150/220 米，精度参考值 120 米；均仍需现场校准。游览时间与里程为编辑估计，准备事项中已说明，不是实测导航路线。
- 票务只区分需门票与免费公共区域。未伪造价格或购买链接；单独收费的演出、场馆、体验不与免费街区混同。
- 详细发布、校验及 28 项 OSS 资源检查结果见 [verification.json](verification.json)。未在手机上实测播放/定位，也未确认 App 独立 API 的最新隧道地址。
- 本次为 CMS 内容操作，无需服务部署或重新打包 App。内容快照保存到当前工作分支，供追溯。

## 图片署名

以下照片为真实地点照片；下载缩略图后由 CMS 标准化为 JPEG，保留各自许可，未宣称为近期实拍。图片和许可的记录也关联在各讲解的公开来源链中。

- **大芬油画村**：[原图](https://commons.wikimedia.org/wiki/File:SZ_%E6%B7%B1%E5%9C%B3_%E5%A4%A7%E8%8A%AC%E6%B2%B9%E7%95%AB%E6%9D%91_Da_Fen_Oil_Painting_Village_entrance_sign_Aug-2010.JPG)。摄影：Szdapanwen；许可：CC BY-SA 3.0 https://creativecommons.org/licenses/by-sa/3.0；原图缩放与CMS JPEG标准化。拍摄日期见文件页，不代表实时景况。
- **大鹏所城**：[原图](https://commons.wikimedia.org/wiki/File:%E5%A4%A7%E9%B9%8F%E6%89%80%E5%9F%8E%E5%8D%97%E9%97%A8%E4%B8%9C%E8%B7%AF.jpg)。摄影：Iswzo；许可：CC BY-SA 4.0 https://creativecommons.org/licenses/by-sa/4.0；原图缩放与CMS JPEG标准化。拍摄日期见文件页，不代表实时景况。
- **仙湖植物园**：[原图](https://commons.wikimedia.org/wiki/File:FAIRYLAKE_BOTANICAL_GARDEN_(3).jpg)。摄影：Dinkun Chen；许可：CC BY-SA 4.0 https://creativecommons.org/licenses/by-sa/4.0；原图缩放与CMS JPEG标准化。拍摄日期见文件页，不代表实时景况。
- **甘坑古镇**：[原图](https://commons.wikimedia.org/wiki/File:Gankeng_Historic_Town.jpg)。摄影：Ubahnverleih；许可：CC0 http://creativecommons.org/publicdomain/zero/1.0/deed.en；原图缩放与CMS JPEG标准化。拍摄日期见文件页，不代表实时景况。
- **深圳欢乐谷**：[原图](https://commons.wikimedia.org/wiki/File:%E6%B7%B1%E5%9C%B3%E6%AC%A2%E4%B9%90%E8%B0%B7%E2%80%94%E6%AD%A3%E9%97%A8.jpg)。摄影：古海岸遗址；许可：CC BY-SA 3.0 https://creativecommons.org/licenses/by-sa/3.0；原图缩放与CMS JPEG标准化。拍摄日期见文件页，不代表实时景况。
- **莲花山公园**：[原图](https://commons.wikimedia.org/wiki/File:Lianhuashan_Garden.jpg)。摄影：jo.sau from London/Vilnius, UK/Lithuania；许可：CC BY 2.0 https://creativecommons.org/licenses/by/2.0；原图缩放与CMS JPEG标准化。拍摄日期见文件页，不代表实时景况。
- **东部华侨城**：[原图](https://commons.wikimedia.org/wiki/File:Interlaken_Hotel_OCT_East.jpg)。摄影：Kevin Poh；许可：CC BY 2.0 https://creativecommons.org/licenses/by/2.0；原图缩放与CMS JPEG标准化。拍摄日期见文件页，不代表实时景况。
- **欢乐海岸**：[原图](https://commons.wikimedia.org/wiki/File:%E6%B7%B1%E5%9C%B3_%E6%AC%A2%E4%B9%90%E6%B5%B7%E5%B2%B8_OCT_HARBOUR_-_panoramio.jpg)。摄影：wanghongliu；许可：CC BY-SA 3.0 https://creativecommons.org/licenses/by-sa/3.0；原图缩放与CMS JPEG标准化。拍摄日期见文件页，不代表实时景况。
- **欢乐港湾**：[原图](https://commons.wikimedia.org/wiki/File:Bay_Glory_2022.jpg)。摄影：Iswzo；许可：CC BY-SA 4.0 https://creativecommons.org/licenses/by-sa/4.0；原图缩放与CMS JPEG标准化。拍摄日期见文件页，不代表实时景况。
- **深圳野生动物园**：[原图](https://commons.wikimedia.org/wiki/File:SHENZHEN_SAFARI_PARK_(3).jpg)。摄影：Dinkun Chen；许可：CC BY-SA 4.0 https://creativecommons.org/licenses/by-sa/4.0；原图缩放与CMS JPEG标准化。拍摄日期见文件页，不代表实时景况。
- **海上世界**：[原图](https://commons.wikimedia.org/wiki/File:Seaworldszsign_A.jpg)。摄影：WhisperToMe；许可：CC0 http://creativecommons.org/publicdomain/zero/1.0/deed.en；原图缩放与CMS JPEG标准化。拍摄日期见文件页，不代表实时景况。
- **深圳湾公园**：[原图](https://commons.wikimedia.org/wiki/File:Shenzhen_Bay_Park_-_2019-12-09_-_2.jpg)。摄影：Mx. Granger；许可：CC0 http://creativecommons.org/publicdomain/zero/1.0/deed.en；原图缩放与CMS JPEG标准化。拍摄日期见文件页，不代表实时景况。
- **锦绣中华·民俗村**：[原图](https://commons.wikimedia.org/wiki/File:Splendid_China_002.jpg)。摄影：Dmpendse at English Wikipedia；许可：Public domain ；原图缩放与CMS JPEG标准化。拍摄日期见文件页，不代表实时景况。
- **世界之窗**：[原图](https://commons.wikimedia.org/wiki/File:WINDOWS_OF_THE_WORLD_SHENZHEN_(13).jpg)。摄影：Dinkun Chen；许可：CC BY-SA 4.0 https://creativecommons.org/licenses/by-sa/4.0；原图缩放与CMS JPEG标准化。拍摄日期见文件页，不代表实时景况。

## 后续候选，未混入本次已发布数量

还检索了小梅沙海洋世界、较场尾、西涌、杨梅坑·鹿嘴等。小梅沙必须使用 2024 年重建后的资料及正确现址图片；本轮未找到可直接复用且确认授权的新馆封面，不以旧馆或地铁站照片代替。海滨候选还需补足可靠的具体步行位置和图片来源，不能将搜索结果中的溪涌误作西涌，也不能把粗粒度地点坐标当作入口。

- [小梅沙海洋世界：2024 年重建后试营业资料](https://wtl.sz.gov.cn/bsfw/mzwhhd/mzly/content/post_11565921.html)
- [西涌：市政府旅游资料](https://www.sz.gov.cn/en_szgov/travel/natural/content/post_9984862.html)
- [杨梅坑：市政府旅游资料](https://www.sz.gov.cn/en_szgov/travel/natural/content/post_9984871.html)

内容快照引用当前 CMS 媒体库；跨环境重放须先同步原图与旁白媒体，不能在空媒体库直接导入后声称资源齐全。
