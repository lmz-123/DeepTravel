# 见地 Flutter 客户端

Flutter Material 3 客户端，采用 Riverpod + go_router + Dio，按 `domain / data / presentation` 分层。

## 模式

默认零配置 Demo：

```bash
flutter run
```

连接 API：

```bash
flutter run \
  --dart-define=APP_MODE=api \
  --dart-define=API_BASE_URL=http://127.0.0.1:5001/api/v1
```

## 检查

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web
```

