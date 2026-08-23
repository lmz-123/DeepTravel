# 私密语义足迹

足迹保存用户已经获得的城市理解和私人记录，不再表示路线完成统计。每个已揭示故事点都会生成一条可稍后整理的私密草稿；用户不必走完整条漫游，也可以选择一条编辑总结、补充短观察或一句话，并上传至多一张私人照片。

## 数据边界

足迹快照只包含城市、场景、故事标题、经审核的概括性文字、稳定总结选项、主题、整理状态、旅程完成状态和创建时间。用户内容分为“我看到的”（短观察与可选照片）和“我留下的”（所选总结与一句话）。

足迹表和客户端模型不保存音频地址、播放进度、声音供应商或版本、坐标、触发范围、路线统计、对象存储密钥或公开照片地址。照片经所有者鉴权后按字节读取，单独存入 `private/footprints/` 私有命名空间；API 只返回受保护的相对读取端点。常规日志只记录安全的足迹、旅程或证据标识和状态码，不记录私人文字、图片内容、筛选值或对象键。

足迹详情仍可通过次要的“继续漫游”动作返回原旅程，但足迹本身不依赖 `JourneyContext`、播放器、声音偏好、节点社区或证据过期状态。分享卡只在本机生成，默认纯文字；只有用户明确确认时才读取私人照片，随后仅打开系统分享面板，不调用社区发布接口，临时文件在分享返回后清理。

## API 与筛选

- `GET /api/v1/footprints`：支持 `city`、任意 `theme`、`month=YYYY-MM`、`journey_state`、`organization_state`、`order`、`cursor` 与 `limit`，返回稳定游标和服务端派生的城市、主题、月份 facets。
- `GET|PATCH /api/v1/footprints/<id>`：读取或整理一条所有者足迹；短字段支持显式清空。
- `GET /api/v1/footprints/resume-candidate`：返回当前账号最近可继续整理的草稿。
- `GET /api/v1/footprints/<id>/related-content`：只返回已发布的同城内容，并优先主题重叠项。
- `POST|GET|DELETE /api/v1/footprints/<id>/photo`：上传要求 `idempotency_key`，替换、读取和删除均按所有者鉴权。
- `GET /api/v1/policies/footprints`：返回滚动客户端所需的图片和短字段限制，不暴露存储配置。

主题使用 `footprint_themes` 规范化关系完成账号、城市、主题、时间组合筛选，避免依赖数据库方言相关的 JSON 数组扫描；快照中的主题 JSON 仅用于响应与历史展示。

## 历史回填

先在生产同构环境执行只读预演：

```bash
docker compose run --rm api flask --app 'app:create_app' backfill-footprints --dry-run
```

确认新增数和安全失败标识后执行：

```bash
docker compose run --rm api flask --app 'app:create_app' backfill-footprints
```

命令按“账号 + 旅程 + 来源”幂等补齐所有已揭示故事片段和传统已回答站点，不改变旅程账本、完成状态或故事因果顺序。每条足迹最多复制一张仍未过期的历史证据到永久私有命名空间；原证据及其过期策略保持不变。单张复制失败会在报告中给出足迹、证据标识和安全错误码，重跑可继续处理。

## 部署与回滚

采用服务端先行：构建 API、执行 `alembic upgrade head`、启动并检查健康状态，再部署独立后台，最后发布新客户端。后台共享主库模型，不拥有这次迁移。

```bash
cd /root/DeepTravel
docker compose build api
docker compose run --rm api alembic upgrade head
docker compose up -d mysql api
docker compose ps

cd /root/DeepTravel-admin
docker compose up -d --build
docker compose ps
```

应用回滚时先回退客户端，再回退后台和 API 代码；保留 `0014` 新表、列和私有照片，不执行 downgrade、不删除 MySQL 或私有媒体卷。旧客户端继续使用既有旅程和证据接口；新客户端连接旧服务端时显示真实的足迹不可用/重试状态，不伪造本地记录。
