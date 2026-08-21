# 见地 JIAN·DI

> 走进一座城，也读懂它。

见地是一个“定位音频 + 碎片叙事 + 现场线索”驱动的深度城市探索 MVP。深圳南头古城路线会在行走中自动播放五段相互关联的历史，穿插三次私密拍照任务，最后由旅行者重构完整因果故事；上海路线保留原五站观察模式。

当前仓库包含完整 Flask API、Flutter 客户端、MySQL Docker 环境、OpenSpec 变更、测试与后端托管的媒体资产。

## 快速体验

客户端默认连接后端 API；路线内容和图片由后端数据库及媒体存储提供：

```bash
cd mobile
flutter pub get
flutter run --dart-define=APP_MODE=api \
  --dart-define=API_BASE_URL=http://127.0.0.1:5001/api/v1 \
  --dart-define=ENABLE_DEMO_TRIGGERS=true
```

发现页默认展示深圳，用户可切换上海。开始南头路线后，客户端仅在明确的活动旅程中请求定位、后台通知与相机权限；定位需在 15 秒内出现两次合格采样才触发音频。研究构建可显示显式模拟触发按钮，生产构建应同时关闭客户端 `ENABLE_DEMO_TRIGGERS` 和后端 `ALLOW_DEMO_ARRIVAL`。

## 使用 Flask + MySQL

```bash
cp .env.example .env
docker compose up -d --build
```

服务就绪后：

- API：`http://localhost:5001/api/v1`
- 健康检查：`http://localhost:5001/api/v1/health`
- 媒体资源：`http://localhost:5001/api/v1/assets/images/route_wukang.png`
- 导览音频：`http://localhost:5001/api/v1/assets/audio/nantou-fragment-1-nantou-2026.08-review.1.m4a`
- MySQL：`localhost:3307`

游客照片保存在独立 Docker 卷 `jiandi_evidence`，不会经过公开 `/assets` 路径。默认限制 10 MB、最长边 4096 像素、保留 30 天；服务端会重新编码并移除 EXIF。

部署到服务器时，将 `.env` 中的 `PUBLIC_BASE_URL` 设置为客户端可访问的 API 公网根地址，例如 `https://api.example.com`，然后执行：

```bash
git clone git@github.com:lmz-123/DeepTravel.git
cd DeepTravel
cp .env.example .env
# 将 PUBLIC_BASE_URL 改为客户端可访问的 API 根地址
docker compose up -d --build
curl -f https://api.example.com/api/v1/health
```

启动 Flutter API 模式：

```bash
cd mobile
flutter run \
  --dart-define=APP_MODE=api \
  --dart-define=API_BASE_URL=http://127.0.0.1:5001/api/v1 \
  --dart-define=ENABLE_DEMO_TRIGGERS=true
```

Android 模拟器应将地址改为 `http://10.0.2.2:5001/api/v1`。真机请使用开发机在局域网中的 IP，并仅在可信开发网络中运行 HTTP 调试服务。

## 后端本地开发

推荐 Python 3.13：

```bash
cd backend
python3.13 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
export DATABASE_URL=sqlite:///jiandi.db
alembic upgrade head
flask --app 'app:create_app' seed
flask --app 'app:create_app' run --port 5001 --debug
```

验证：

```bash
cd backend
ruff check app tests
pytest

cd ../mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web

cd ..
openspec validate add-location-aware-fragment-audio-tour --strict
```

## 架构

```text
Travel/
├── backend/
│   ├── app/
│   │   ├── domain/          # 实体、状态规则、仓储端口
│   │   ├── application/     # 目录、旅程、碎片状态与证据用例
│   │   ├── infrastructure/  # SQLAlchemy、JWT、定位内容、私有证据适配器
│   │   ├── presentation/    # Flask 路由、认证、序列化、错误协议
│   │   └── bootstrap/       # 配置与依赖装配
│   ├── migrations/
│   └── tests/
├── mobile/
│   └── lib/
│       ├── core/            # 主题、路由、配置、共享组件
│       └── features/experience/
│           ├── domain/      # Flutter 领域模型与仓储接口
│           ├── application/ # 纯定位触发状态机
│           ├── data/        # REST、SQLite、定位、音频与相机适配器
│           └── presentation/# 活动导览控制器、线索簿与重构页面
├── docs/implementation-design.md
└── openspec/changes/build-deep-travel-mvp/
```

后端是模块化单体，业务层不依赖 Flask 或 SQLAlchemy。Flutter 使用 feature-first MVVM，View 不直接请求网络。Catalog 与 Journey 仅通过 ID/DTO 连接，未来可低成本迁移为独立服务。

## API 摘要

所有业务端点位于 `/api/v1`：

- `POST /sessions/guest`
- `GET /cities`
- `GET /cities/{slug}/routes`
- `GET /routes/{slug}`
- `GET /assets/{path}`
- `POST /journeys`
- `GET /journeys/{id}`
- `POST /journeys/{id}/arrivals`
- `POST /journeys/{id}/answers`
- `POST /journeys/{id}/advance`
- `POST|DELETE /journeys/{id}/active-tour`
- `POST /journeys/{id}/fragments/{fragment_id}/triggers`
- `POST /journeys/{id}/fragments/{fragment_id}/playback`
- `POST /journeys/{id}/fragments/{fragment_id}/evidence`
- `GET|DELETE /journeys/{id}/evidence/{evidence_id}`
- `GET /journeys/{id}/ledger`
- `POST /journeys/{id}/reconstruction`
- `GET /journeys/{id}/recap`

Journey 端点需要 `Authorization: Bearer <guest-token>`。错误统一为：

```json
{
  "error": {
    "code": "journey_state_conflict",
    "message": "完成当前观察问题后才能继续",
    "details": {}
  }
}
```

## 内容与版权边界

- 南头五段历史已拆成逐条 claim 并关联政府/博物馆来源，但仍是 `in_review` 研究稿；现场坐标、安静收听点、物件原构/复原/解释性关系和普通话录音仍需实地与编辑审核；
- 客户端与 API 始终显示研究预览标签，不会把种子数据标成已核验史实；
- 两张路线视觉图由 ImageGen 为本项目原创生成，存放在 `backend/media/images/`，并通过 `media_assets` 数据表登记；
- MVP 不采集姓名、手机号或连续位置轨迹；触发请求只保存碎片、时间、方式和验证结果，不保留原始经纬度；游客 JWT 仅包含随机会话 ID 与过期时间；
- 旅行者照片默认私密、按旅程鉴权、随机对象键存储，可在最终重构前删除。删除会使对应任务回到待完成状态。

## 已知 MVP 边界

- 当前五段音频为与版本化文字稿一致的本地合成预览声线，不是正式旁白；
- Android 已配置活动旅程前台通知，iOS 已声明 location/audio 后台模式，但系统仍可能因电量与生命周期策略暂停监测，客户端会显示受限状态；
- 真机锁屏、来电、导航提示、蓝牙耳机断开、弱 GPS、进程终止及一次南头实地行走仍是发布前硬门槛，因此路线保持 `in_review`；
- 未实现离线地图瓦片、付费、账户、CMS、AR、视觉正确性判断和多人同步；
- 正式在中国大陆使用地图前，需要确定供应商及坐标系转换策略。

## 回滚与数据安全

将 `ENABLE_FRAGMENT_AUDIO_TOURS=false` 后重新创建 API 容器，可隐藏新路线能力并让旧版上海/深圳旅程继续可读。不要执行 `docker compose down -v`；正常 `docker compose down`、重新构建或回退代码都不会删除 MySQL 与 `jiandi_evidence` 卷。
