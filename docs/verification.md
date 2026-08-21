# 碎片音频导览验证记录

日期：2026-08-22

## 自动验证

- OpenSpec：`openspec validate add-location-aware-fragment-audio-tour --strict`
- 后端：Ruff 无问题；Pytest 覆盖旧版五站流程、内容审查门槛、近/远/低精度/重复触发、播放状态、私有照片鉴权与完整重构
- MySQL：Alembic `20260822_0003` 增量建立新表；Docker API 启动时自动迁移并幂等对账种子数据
- Docker：API、数据库、公共音频与独立私有证据卷健康检查
- Flutter：Format、Analyze、单元与 Widget 测试；纯触发引擎覆盖精度、双采样、依赖和一次性确认
- Android：使用 API 模式构建评审 APK，后端指向 `http://115.29.221.190:5001/api/v1`

## 设备矩阵

以下项目必须在路线提升为 `reviewed` 前于 Android 与 iOS 真机完成。目前自动化只能验证状态机，不能宣称替代系统和现场行为。

| 场景 | 自动化/实现状态 | 真机状态 |
|---|---|---|
| 前台→后台→锁屏定位触发 | Android 前台通知、iOS background modes 已配置 | 待测 |
| 锁屏播放、暂停、跳转、倍速 | 系统 MediaItem 与单队列已实现 | 待测 |
| 来电/闹钟/导航提示 | AudioSession 中断暂停已实现 | 待测 |
| 有线/蓝牙耳机断开 | becoming-noisy 暂停已实现 | 待测 |
| 弱 GPS 与边界抖动 | 精度过滤、双采样、退出半径已自动测试 | 待测 |
| 离线触发与进程终止 | SQLite 快照、prepared asset、outbox 已实现 | 待测 |
| 拍照拒绝、失败重试与私有读取 | 状态保留、幂等上传、跨游客拒绝已自动测试 | 待测 |
| 五个南头点位与安静收听位置 | 标记 `in_review`/`field_audit_required` | 待现场核验 |

## 当前发布决定

代码与评审 APK 可用于内部体验。南头路线不能升级为正式已核验内容：尚缺 Android/iOS 真机矩阵、一次完整南头实地行走、现场实物真实性审计以及正式旁白复核。
