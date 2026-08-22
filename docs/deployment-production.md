# 生产部署与内容发布

## 后端先行部署

在服务器已有 `/root/DeepTravel/.env` 的前提下，可重复执行：

```bash
cd /root/DeepTravel
git fetch origin main
git checkout main
git pull --ff-only origin main
docker compose build api
docker compose run --rm api alembic upgrade head
docker compose up -d mysql api
docker compose ps
curl -fsS http://127.0.0.1:5001/api/v1/health
```

生产 `.env` 必须设为：

```dotenv
APP_ENV=production
TEST_AUTH_ENABLED=false
PUBLIC_BASE_URL=http://115.29.221.190:5001
```

如启用 OSS，将两个 Bucket 分开，数据库只保存对象键、校验和和 URL：

```dotenv
OBJECT_STORAGE_PROVIDER=oss
OSS_REGION=cn-shenzhen
OSS_ENDPOINT=https://oss-cn-shenzhen.aliyuncs.com
OSS_PUBLIC_BUCKET=deeptravel-public
OSS_PRIVATE_BUCKET=deeptravel-private
OSS_PUBLIC_BASE_URL=https://cdn.example.com
OSS_ACCESS_KEY_ID=由服务器环境提供
OSS_ACCESS_KEY_SECRET=由服务器环境提供
OSS_SIGNED_URL_TTL_SECONDS=300
```

先检查旧媒体，再正式迁移；命令可重复执行，SHA-256 对象键不会产生重复文件：

```bash
docker compose run --rm api flask --app 'app:create_app' migrate-media --dry-run
docker compose run --rm api flask --app 'app:create_app' migrate-media
```

## 独立后台部署

```bash
cd /root/DeepTravel-Admin
git fetch origin main
git checkout main
git pull --ff-only origin main
docker compose up -d --build
docker compose ps
curl -fsS -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  http://127.0.0.1:5100/api/admin/health
```

后台与旅行 API 必须配置相同的 OSS 参数。`NARRATION_PROVIDER=minimax` 时，另在后台 `.env` 配置 `MINIMAX_API_KEY`；凭证不进入 Git。

## 发布上海新路线并归档旧答题路线

先确认后台服务和 API 已启动，再从主仓库执行：

```bash
cd /root/DeepTravel
set -a
. /root/DeepTravel-Admin/.env
set +a
ADMIN_API_BASE=http://127.0.0.1:5100 \
python3 tools/publish_content_package.py \
  docs/content-packages/shanghai-readable-city-v1.json \
  --archive-route-id 91608e67-dbad-4d26-889c-dd3089201001
```

工具会先按 SHA-256 检查媒体库，把缺失图片和音频经后台上传到当前本地/OSS 存储，再按当前状态自动执行导入、校验、提交审核、审核通过、显式发布；新路线确认公开后才归档旧路线。重复执行不会重复上传或建路线。旧路线的新旅程会被拒绝，已经开始且属于当前用户的旧旅程仍可继续。

以后新增城市或景区沿用同一流程：在后台上传媒体、导入通用内容包、校验并发布，不需要修改 Flask 或 Flutter。
