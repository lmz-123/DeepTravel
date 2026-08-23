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
  --dart-define=RUNTIME_LOG_ENDPOINT=http://127.0.0.1:5100/api/runtime/client-logs \
  --dart-define=RUNTIME_LOG_TOKEN=DeepTravelClientLogs2026
```

城市、已发布景点/故事点、体验标签、所属路线和后台推荐顺序均由公共目录返回。发现页首次进入、下拉刷新和手动切城时分别获取一次当前位置；只有新鲜且系统报告精度不大于 25 米的样本才用于景点距离排序。首次城市名无法匹配后台可选城市或匹配城市无景点时回退深圳；刷新保留当前城市，手动选择始终优先。定位失败时保持可用并按后台顺序展示，不伪造距离，也不持久化位置、处理标记或城市模式。

旅程中的真实/模拟定位仍是独立的持久化运行时选择，在 debug 与 release 中均始终可切换；发现页的一次性定位不会读取或改写它。

客户端会把框架异常、接口失败、照片上传状态和少量生命周期事件写入有上限的本地队列，并发送到独立管理后台。日志不包含照片、令牌、请求正文或精确位置；网络恢复或应用回到前台时会继续发送。

## 检查

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web
```
