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
  --dart-define=ENABLE_DEMO_TRIGGERS=true \
  --dart-define=RUNTIME_LOG_ENDPOINT=http://127.0.0.1:5100/api/runtime/client-logs \
  --dart-define=RUNTIME_LOG_TOKEN=DeepTravelClientLogs2026
```

客户端会把框架异常、接口失败、照片上传状态和少量生命周期事件写入有上限的本地队列，并发送到独立管理后台。日志不包含照片、令牌、请求正文或精确位置；网络恢复或应用回到前台时会继续发送。

## 检查

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web
```
