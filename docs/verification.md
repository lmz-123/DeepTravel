# MVP 验证记录

日期：2026-08-19

## 已通过

- OpenSpec：`openspec validate build-deep-travel-mvp --strict`
- 后端：Ruff 无问题，Pytest 8 项通过
- API：游客鉴权、目录读取、远距离拒绝、幂等开始/答题、五站完整旅程与回顾
- MySQL：对本机缓存的 MySQL 9.0 运行 Alembic 初始迁移、种子命令、健康检查和路线读取成功
- Compose：`docker compose config -q` 通过
- Flutter：`flutter analyze` 无问题，4 项测试通过
- Flutter Web：Release 构建成功，Wasm dry run 成功
- 视觉 QA：390×844 视口检查首页、详情、旅程、故事、答题与反馈；无溢出、无控制台错误

## 环境限制

- Docker Desktop 访问 Docker Hub 时对 `python:3.13-slim` 的 metadata 请求返回 EOF，因此未在本机完成 `docker compose up --build`。Dockerfile、Compose 配置和后端运行路径均已分别验证；在可访问 Docker Hub 的环境执行 README 中命令即可。
- 本机没有 Android SDK，Xcode 安装不完整，因此无法在当前环境产出 APK/IPA。Android/iOS 工程壳已生成；Flutter Analyze、Widget Test 与 Web Release Build 均已通过。

