# 见地 Flutter 客户端

Flutter Material 3 客户端，采用 Riverpod + go_router + Dio，按 `domain / application / data / presentation` 分层。南头路线支持活动旅程定位、系统音频控制、相机任务、SQLite 快照/outbox 与故事重构。

## 模式

默认连接 API；旧内置 Demo Repository 仅供测试：

```bash
flutter run
```

连接 API：

```bash
flutter run \
  --dart-define=APP_MODE=api \
  --dart-define=API_BASE_URL=http://127.0.0.1:5001/api/v1 \
  --dart-define=DEFAULT_CITY_SLUG=shenzhen \
  --dart-define=RUNTIME_LOG_ENDPOINT=http://127.0.0.1:5100/api/runtime/client-logs \
  --dart-define=RUNTIME_LOG_TOKEN=DeepTravelClientLogs2026
```

城市名称、路线卡片、封面和路线内容均由后端公共目录返回。首页会横向展示所选城市的全部已发布路线。真实/模拟定位是持久化的运行时选择，在 debug 与 release 中均始终可切换。

客户端会把框架异常、接口失败、照片上传状态和少量生命周期事件写入有上限的本地队列，并发送到独立管理后台。日志不包含照片、令牌、请求正文或精确位置；网络恢复或应用回到前台时会继续发送。

## 检查

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web
```
