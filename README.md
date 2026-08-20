# 见地 JIAN·DI

> 走进一座城，也读懂它。

见地是一个“故事 + 现场观察 + 轻解谜”驱动的深度城市探索 MVP。目前包含深圳南头古城与上海衡复街区两条五站路线、故事播放器、观察任务、旅程进度和完成回顾。

当前仓库包含完整 Flask API、Flutter 客户端、MySQL Docker 环境、OpenSpec 变更、测试与后端托管的媒体资产。

## 快速体验

客户端默认连接后端 API；路线内容和图片由后端数据库及媒体存储提供：

```bash
cd mobile
flutter pub get
flutter run --dart-define=APP_MODE=api \
  --dart-define=API_BASE_URL=http://127.0.0.1:5001/api/v1
```

发现页默认展示深圳，用户可在顶部城市选择器切换上海。当前 MVP 暂时不请求系统定位；用户点击“我已到达，开始观察”后，客户端会请求后端显式启用的临时到达通道。

## 使用 Flask + MySQL

```bash
cp .env.example .env
docker compose up -d --build
```

服务就绪后：

- API：`http://localhost:5001/api/v1`
- 健康检查：`http://localhost:5001/api/v1/health`
- 媒体资源：`http://localhost:5001/api/v1/assets/images/route_wukang.png`
- MySQL：`localhost:3307`

部署到服务器时，将 `.env` 中的 `PUBLIC_BASE_URL` 设置为客户端可访问的 API 公网根地址，例如 `https://api.example.com`，然后执行：

```bash
git clone git@github.com:lmz-123/DeepTravel.git
cd DeepTravel
cp .env.example .env
# 按部署域名修改 PUBLIC_BASE_URL 和数据库密码
docker compose up -d --build
curl -f https://api.example.com/api/v1/health
```

启动 Flutter API 模式：

```bash
cd mobile
flutter run \
  --dart-define=APP_MODE=api \
  --dart-define=API_BASE_URL=http://127.0.0.1:5001/api/v1
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
openspec validate build-deep-travel-mvp --strict
```

## 架构

```text
Travel/
├── backend/
│   ├── app/
│   │   ├── domain/          # 实体、状态规则、仓储端口
│   │   ├── application/     # 目录、游客会话、旅程用例
│   │   ├── infrastructure/  # SQLAlchemy、JWT、种子数据
│   │   ├── presentation/    # Flask 路由、认证、序列化、错误协议
│   │   └── bootstrap/       # 配置与依赖装配
│   ├── migrations/
│   └── tests/
├── mobile/
│   └── lib/
│       ├── core/            # 主题、路由、配置、共享组件
│       └── features/experience/
│           ├── domain/      # Flutter 领域模型与仓储接口
│           ├── data/        # Demo / REST 实现
│           └── presentation/# ViewModel、页面、局部组件
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

- 当前历史与地点文本是用于验证交互的演示稿，不应直接用于公开运营；
- 正式发布前需要补充逐条来源、编辑审校、图片与音频授权；
- 两张路线视觉图由 ImageGen 为本项目原创生成，存放在 `backend/media/images/`，并通过 `media_assets` 数据表登记；
- MVP 不采集姓名、手机号或精确位置历史；游客 JWT 仅包含随机会话 ID 与过期时间。

## 已知 MVP 边界

- 播放器目前是可交互的音频形态与文本兜底，尚未绑定正式授权音频；
- 开发 Demo Repository 仅用于本地测试；当前 MVP API 模式暂时启用点击到达，服务端经纬度距离校验仍保留，后续可通过关闭 `ALLOW_DEMO_ARRIVAL` 恢复；
- 未实现后台定位、离线地图瓦片、付费、账户、CMS、AR 和多人同步；
- 正式在中国大陆使用地图前，需要确定供应商及坐标系转换策略。
