# 游玩准备与我的出游（第一期）

## 行为与配置

已发布景点配置 `travel_preparation.enabled=true` 后，现有详情页会新增「游玩准备」入口。原详情头图、收藏、随行和沿途故事保留原布局。准备页沿用确认的紧凑布局、项目字体和纸色，照片来自景点现有封面，缺图使用原项目的文字占位。

购票／预约只打开运营者核实的官方 HTTPS 网页。优先 Android Custom Tabs / iOS Safari View Controller；无法打开时尝试系统浏览器。官方页面本身由对方控制。无微信 SDK 或供应商下单接口，不支持仅凭小程序名称或二维码直接跳转；可配置官方提供的 HTTPS Universal Link，并选择外部打开。

CMS「景点内容 → 游玩准备 · 购票与预约」支持：

- 显示开关、入园方式（未知／免费／预约／购票）。
- 渠道名称、购票／预约 URL、打开方式、官方来源 URL、人工核实日期。
- 开放时间、交通停车、入园须知：每项正文与独立详情链接。
- 最多 8 项额外准备事项，每项标题、正文、可选链接。

空白项不显示。未找到链接时不显示购买按钮，不显示猜测价格，不抓取第三方价格。启用官方入口须补齐来源和核实日期；来源记录是编辑人工确认，不代表程序已核验官方身份。可随时关闭展示。准备信息独立于故事发布，可更新已发布景点；未发布景点仍受原公共 API 发布规则保护。普通景点编辑、旧内容包导入不清空省略的准备配置。三种导入路径均支持配置。

App 打开官方购票前会尝试加入出游，但跳转本身不产生订单状态。返回后提供继续办理、添加已购票据；不会显示支付成功、已出票或伪造入园码。

## 我的出游与票据

个人页新增「我的出游」。用户可重复加入同一景点（不会重复建记录或清空日期/票据）、设置/清除出行日期、查看准备信息与随行、移除出游。

第一期出游及票据保存在本机应用目录，以 API 地址和账号标识隔离，未实现跨设备云同步。添加图片（JPG/PNG/WebP）或 PDF 会复制为应用内独立文件，最多 15 MB/份、20 份/景点，检查文件头。没有上传到公共 OSS、没有随便读取公共媒体。图片可缩放，PDF 交给系统阅读器；删除票据/出游需确认。原文件丢失/损坏有提示。票据明确显示「本人添加」，不把用户提供的文件视作平台已验证订单。

## 部署

无新增环境变量。必须先升级共享数据库，再启动新版本 CMS；否则缺少新 JSON 列会导致查询失败。执行前确认服务器实际目录；以下使用原部署目录：

```bash
cd /root/DeepTravel
git fetch origin codex/v5-client-art-magazine
git checkout codex/v5-client-art-magazine
git pull --ff-only origin codex/v5-client-art-magazine
docker compose build api
docker compose run --rm api alembic upgrade head
docker compose up -d api
curl -fsS http://127.0.0.1:5001/api/v1/health

cd /root/DeepTravel-admin
git pull --ff-only origin main
docker compose up -d --build admin-api admin-web
```

新增迁移 `20261011_0020`，给 `routes` 增加 nullable JSON `travel_preparation`。既有景点默认关闭，运营人员核实资料后配置启用，不会自动填入虚假的官方链接。CMS 保存后重新打开准备页或下拉刷新获取新配置；无网络时仍可使用已有本地票据。

本任务仅提交推送，未部署线上、未修改线上景点配置。

## 验证

- Flutter 全量 303 测试通过（新增域名限制、账号隔离、重复加入/日期保留、文件持久化和删除、文件限制、320/390 宽准备页、票据真实状态测试）。
- Flutter 静态检查通过；Android arm64 release 原生编译通过（版本 `0.9.0+31`，50.1 MB）。本次构建仅验证原生依赖，使用不可用的占位 API 地址，未作为可用安装包交付；正式包仍需确认当前动态 API 配置及生产日志凭证。
- 公共 API 120 测试通过，包含准备信息更新/关闭/未发布隐藏及完整迁移往返；ruff 通过。
- CMS Python 52 测试通过，包含带鉴权真实 FastAPI/SQLite 保存、普通编辑保留配置、非法链接拒绝、导入和日期序列化。
- CMS 构建与前端 6 测试、改动页面 ESLint 通过。
- 本地浏览器确认 CMS 配置全部字段并保存，刷新可回填（UI 使用隔离的模拟 API，不是线上写入）。
- 新页面截图：`mobile/test/goldens/travel-preparation-320.png`、`travel-preparation-390.png`、`travel-wallet-390.png`。截图加载项目字体和原生图标，检查票根、纸色、字号、随行入口和小屏溢出。

尚未验证真实景区购票支付、真机微信唤起、真机 PDF 阅读器；这些能力取决于配置目标页面/设备。此版不接供应商订单或支付接口。
