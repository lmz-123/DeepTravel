# 自动城市底图

城市底图是区县边界 GeoJSON 数据，不是预先绘制的图片。App 继续使用原来的纸色、区块、边界线、字体、标点和选中效果。CMS 无需画轮廓或上传地图文件。

## 操作

1. 新建城市，输入城市名并选中匹配结果。城市行政区编码、中心坐标和默认标识自动填写；保留已有城市标识以兼容链接。
2. 保存城市。后台队列自动获取并校验对应区县边界，将不可变版本文件保存到现有公共 OSS Bucket 的 `maps/cities/<adcode>/<sha256>.geojson`。
3. 城市列表每 5 秒更新状态：准备中、已就绪、需要选择城市、获取失败。失败自动退避重试，也可以点击重试。
4. 新建景点时选择地图分类；地点配置有效坐标并通过原有审核发布流程后，App 刷新内容自动标点。
5. App 先使用本地缓存或内置底图，再获取云端版本；重新打开地图或刷新内容时检查更新。

**不需要手绘。** 没有坐标的地点不会凭名称猜测或借用城市中心。城市中心仅供城市识别，不是景点位置。地点表单不再预填固定默认坐标。城市地图仍按景点聚合标点，景点内部故事点沿用随行界面。

## 边界与恢复

- 数据源为 DataV，城市目录来自 `https://geo.datav.aliyun.com/areas_v3/bound/all.json`，于 2026-10-11 获取，包含 367 个地级城市和直辖市选项。资源来源保留在客户端署名中。
- 图形来源固定为 `https://geo.datav.aliyun.com/areas_v3/bound/<adcode>_full.json`。校验城市归属、坐标范围、闭合环、文件大小和点数，禁止任意用户 URL 下载。
- 后台每 15 秒扫描任务，也会发现旧系统或导入产生的缺少底图的城市。任务状态保存在共享数据库，5 分钟租约防止并发任务互相覆盖，崩溃后可恢复。重选城市会使旧任务结果失效。
- 数据源没有覆盖、下载失败或 OSS 暂不可用时，不生成虚构边界；保留旧图或仅显示有效地点。无法按名称唯一匹配时，需要在 CMS 选择准确城市。
- `/api/v1/cities/<slug>/map` 返回资源版本和当前公共资源地址。App 校验 SHA-256，缓存到应用支持目录；账号凭证不发给 OSS。缓存按 API 来源隔离。
- `map_category` 是景点的独立分类字段；旧内容仍能按主题回退，不要求重新录入。

## 部署（先 API，再 CMS）

复用服务器现有数据库和 OSS 配置，没有新增必填环境变量；地图文件使用现有公共 Bucket。当前会话未取得 OSS 中记录穿透最新地址的配置入口，因此没有连接线上服务或写入线上 OSS。以下在实际运行服务的主机执行，目录不是默认路径时先设置 `DEEPTRAVEL_API_DIR`、`DEEPTRAVEL_ADMIN_DIR`。

```bash
cd "${DEEPTRAVEL_API_DIR:-/root/DeepTravel}"
git fetch origin codex/v5-client-art-magazine
git checkout codex/v5-client-art-magazine
git pull --ff-only origin codex/v5-client-art-magazine
docker compose build api
docker compose run --rm api alembic upgrade head
docker compose up -d api
curl -fsS http://127.0.0.1:5001/api/v1/health

cd "${DEEPTRAVEL_ADMIN_DIR:-/root/DeepTravel-admin}"
git pull --ff-only origin main
docker compose up -d --build admin-api admin-web
```

迁移 `20261011_0019` 新建 `city_maps`，为 routes 增加可空 map_category。部署后打开 CMS 城市列表查看自动准备状态。App 必须更新到包含本次下载逻辑的版本，之后新增城市无需再发版。

## 验证

- 实际请求 DataV 成功取得并校验杭州 13 个区县；该验证未写入生产 OSS。
- 客户端验证新城市下载、跨实例离线缓存、版本更新、损坏文件拒绝、来源隔离；已有地图和首页截图基线通过，画法保持一致。
- API 验证地图状态接口、保留最后成功版本、显式景点分类与数据库迁移。
- CMS 验证新增城市入队、自动识别、重试、租约恢复、并发过期结果隔离、导入兼容、分类校验。
- CMS 浏览器验证：搜索杭州、选择后自动填中心和标识、提交 adcode、列表从准备中自动更新为就绪。截图使用本地模拟接口，不代表线上部署状态。
- 截图：[城市表单](verification/automatic-city-maps/city-form.png)、[底图状态](verification/automatic-city-maps/city-ready.png)。
- 本次未生成安装包：当前运行地址经 OSS 动态配置，但配置文件位置未提供，无法确认可用的正式 API/日志构建配置。没有把失效旧地址写入新安装包。
