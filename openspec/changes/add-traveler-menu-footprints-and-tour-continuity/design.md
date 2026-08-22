## Context

参见 [proposal.md](./proposal.md) 的动机与范围。当前后端已经用 `journeys.status/completed_at`、`journey_fragments`、`evidence` 持久化用户进度和私有照片，但仓储只提供 `find_active/list_active_for_user`，`POST /journeys` 在没有 active 记录时总会创建新旅程；碎片完成规则又把所有 `interaction_type=photo` 的节点推进到 `mission_pending`。因此完成记录、可选照片和重访都可以基于现有表实现，无需再建立一套足迹真相源。

Flutter 目前由 `JourneyController` 启动路线，并由全局但只在旅程页初始化的 `ActiveTourController` 持有 `just_audio` 播放器。返回首页不会主动销毁播放器，但首页不了解这段状态，路线卡也不了解用户 active/completed 旅程；`JourneyPage` 又依赖内存中的 route/session，无法单靠 journey id 恢复。照片上传成功后只保留本地相机路径，服务端证据响应没有被足迹或重启后的客户端完整消费。

照片任务字段由主仓库 API 数据库和独立 `Travel-Admin` 数据库共同维护，内容包经管理员服务校验后导入主 API。新增拍摄指导字段必须同时覆盖两套模型、导入导出、校验和管理 UI，并按两个 Git 仓库分别提交。

## Goals / Non-Goals

**Goals:**

- 让 `journeys`、`journey_fragments`、`evidence` 继续成为足迹、重访、解锁状态和照片的唯一服务端真相源。
- 在 Flutter 维持一个账号绑定、跨景点单一所有者的播放会话，将旅程进度游标与“当前选中播放的节点”拆开，支持首页自由拖动的旋转播放圆球、安全重听和跨景点自动停止交接。
- 提供稳定、向后兼容、无 N+1 私有媒体下载的旅程集合与证据元数据 API。
- 对旧照片任务和既有完成记录提供无损迁移与运行时兼容，不要求清空数据库或重新走路线。
- 在主仓库和独立后台仓库分别提供自动化验证边界。

**Non-Goals:**

- 不新增微服务、消息队列、照片 CDN 公链或第二种进度数据库。
- 不保证系统杀进程后继续同一音频毫秒位置；本次保证应用进程内跨页面持续播放，以及重启后从服务端旅程/线索状态恢复。
- 不将用户偏好同步到云端，不把公开路线音频缓存误当成私有证据。
- 不在相机取景器内实现实时 AR/九宫格覆盖；拍摄指导在打开系统相机前展示。

## Decisions

### 1. 直接查询现有旅程表，足迹不是新实体

扩展 `JourneyRepository`：

- `find_latest_completed(route_id, user_id)`：按 `completed_at DESC, started_at DESC` 返回最近完成记录；
- `list_for_user(user_id, statuses)`：按 `COALESCE(completed_at, updated_at) DESC` 返回 active/completed；
- `find_active` 仍优先于 completed，以兼容历史上可能同时存在两种记录的账号。

`JourneyService.start_or_resume` 的顺序固定为：返回当前用户 active → 返回当前用户 latest completed → 读取公开 route → 创建 active。这样已有 journey 的 archived route 仍可由 owner 恢复，而没有 owner 记录的用户必须通过公开 route 校验，不能新建 archived route。owner-scoped collection/get 同样可读取归档路线。为列表查询增加 `(user_id, status, updated_at)` 和 `(user_id, route_id, status, completed_at)` 索引；不增加唯一约束，因为历史数据可能已有同路线多次完成记录。

备选方案是新建 `footprints` 表并在完成时复制数据。它会产生双写、一致性和历史回填问题，且当前完成时间、碎片和证据已经足够，故不采用。路线本身只允许归档而非物理删除；足迹序列化通过 `get_route_for_journey` 读取归档路线。未来若允许硬删除内容，再单独引入 route snapshot JSON。

### 2. 新增集合和证据元数据 API，保留现有端点

新增以下 owner-authenticated 契约：

- `GET /api/v1/journeys?status=active|completed`：省略 status 时返回两者。每项为 `{journey, route, journey_kind, collected_count, total_count, evidence_count}`；碎片路线的 progress 来自 `journey_fragments`，传统路线来自 answers，避免当前音频路线永远显示 0%。
- `GET /api/v1/journeys/{journey_id}/context`：返回 owner-scoped journey、完整 route/audio manifest 和进度摘要，用于 deep link、归档路线和内存状态丢失后的恢复。
- `GET /api/v1/journeys/{journey_id}/evidence`：返回未删除证据元数据，并通过 mission join 补充 `fragment_id`；不返回对象键或存储供应商信息。
- `GET /api/v1/policies/evidence`：返回客户端可显示的保留天数、格式/尺寸限制、私有访问和 EXIF 处理说明，避免在 Flutter 硬编码后端策略。

现有 `GET /journeys/active` 保留并用新查询实现，以兼容旧客户端；现有 `GET /journeys/{id}/ledger|recap|evidence/{id}` 和上传/删除端点保持 URL 与鉴权语义。集合 serializer 批量加载 route、fragment state 和 evidence count，禁止循环逐 journey 发 SQL。

证据二进制继续通过 bearer token 获取，不生成可分享长效 URL。Flutter 使用 Dio `ResponseType.bytes` 加载到内存图片，并以 `(userId, journeyId, evidenceId)` 为缓存键；退出或切换账号立即清理内存缓存。这样比给 `Image.network` 一个裸 URL 更明确地控制令牌、过期和错误状态。

### 3. 照片从状态机 gate 变成可附加证据

播放达到阈值后，碎片统一进入 `collected`；是否存在 `photo_mission` 不再改变 collection 状态。`mission_pending` 仅作为旧数据兼容输入：读取/下一次 playback reconcile 时，如果播放已完成则提升为 `collected`，无需批量破坏式迁移。

上传证据要求 owner、对应 mission、有效图片和 `playback_completed_at`，但允许 state 已为 `collected`；上传只设置 `evidence_id`，不再次增加 collected count。删除证据在旅程完成前后均允许，软删 evidence 并清除 state 的 `evidence_id`，但保留 `state=collected`、`collected_at` 和 reconstruction。已有 completed journey 的历史正确性因此不受照片保留期影响。

备选方案是只在模拟模式绕过 required 照片。它会导致真实定位模式仍被非安全、非必要拍摄阻断，也会让足迹完成规则因入口不同而分裂，因此不采用。模拟“下一条”仍是独立的测试快捷交互：客户端先 stop player，再用稳定 idempotency key 上报 progress=1，刷新 ledger 后触发下一 eligible fragment；真实定位触发规则不变。

### 4. 拍摄指导为服务端内容字段，旧内容有迁移垫片

在主 API 与 `Travel-Admin` 的 `photo_missions` 增加可空 Text 字段：

- `vantage_point`：安全站位/经典机位；
- `shooting_direction`：面向方向或拍摄朝向；
- `composition_tip`：主体位置、留白或层次建议。

内容包、管理编辑器、导入导出和 validation graph 同步字段。新发布/重新发布的 photo mission 必须填写三项；字段审核仍走现有 draft/review/approve/publish 生命周期。迁移先以 nullable 列部署，旧线上记录运行时分别回退到 `field_subject`、`prompt` 和 `prompt`，避免 API/旧客户端中断；本仓库现有深圳、大梅沙、上海内容包与 seed 随变更补齐真实文案，重新发布后不再依赖 fallback。

没有增加示例答案照片或视觉正确性模型。客户端用“站位 / 朝向 / 构图 / 安全”四段文本卡片引导后调用现有系统相机。

### 5. 应用级 shell 负责 drawer、可拖动播放圆球和单一音频所有者

在 go_router 的私有页面上建立 `ShellRoute`/共享 scaffold，托管：

- 可由首页 `BrandMark` 语义按钮打开的左侧 drawer；
- 仅在 discovery 首页安全区域叠加、默认位于右侧的 `RotatingTourOrb`；
- 账号切换/过期时统一调用 stop playback、stop location、clear private snapshots、invalidate user providers。

`ActiveTourController` 仍是唯一播放器 owner，不在 shell 新建第二个 audio player。圆球只 watch 播放状态和进度，把 tap 转发为旅程导航，把 pan 转发为位置更新；播放/暂停、进度拖动和停止仍留在完整旅程页，避免在小尺寸圆球内堆叠控制。交互采用“浮动播放气泡 + 旋转唱片”的成熟隐喻：圆形中心显示服务端路线封面（缺失时用中性品牌图形），外圈绘制进度和克制的 ink/gold 唱片纹理；播放时连续旋转，暂停时停在当前角度，`MediaQuery.disableAnimations`/无障碍减少动态效果时完全静止并保留状态指示。

圆球视觉直径为 56–64 logical pixels，透明语义命中区至少 72 logical pixels，通过首页 `Stack/Positioned` 放置。首次默认在右侧；`GestureDetector` 的 pan 手势允许用户在扣除 safe area、固定 header、底部导航和系统手势区后的矩形内自由移动，达到拖动阈值后取消 tap，松手不强制吸边。位置保存为可移动区域内的归一化 `(x, y)`，使用 `user.{id}.playbackOrbPosition` 本地键隔离；重进首页、重启、旋转或窗口变化时恢复并 clamp 到新边界。Semantics 提供上/下/左/右分步移动动作作为自由拖动的无障碍替代。在紧凑/大屏布局、滚动冲突和 drag-versus-tap widget tests 中验证。

离开首页时不渲染圆球但不停止当前音频；回到首页立即从同一 controller 恢复位置、角度状态、进度和语义。显式停止、退出登录或鉴权过期时移除圆球。Material 3 navigation drawer 的层级和触控行为继续作为侧边菜单基线。

播放器所有权显式表示为 `(userId, routeId, journeyId, fragmentId, generation)`。同一路线切换节点沿用 replay/live 规则；当任意页面请求不同 `routeId` 的音频时，controller 先递增 generation，使旧 position/completion/trigger callback 失效，再依次 stop player、清空 autoplay queue、停止旧 route 的 location subscription，最后装载新 owner 并按用户动作播放。旧 journey 在服务器仍保持原 active/completed 状态，之后可以从首页或足迹恢复。新媒体加载失败时旧音频保持 stopped，不自动回滚或形成双声道；UI 展示新景点的可重试错误。圆球只反映当前 owner，交接完成后封面和点击目标同时切换，不能短暂指向旧旅程却播放新声音。

`ActiveTourState` 增加显式 `mode = live | revisit`、`progressFragmentId`（服务端推进目标）和 `selectedFragmentId`（当前播放/展示）。当前 `current` 逐步替换为从 ledger 派生的 selected fragment。离开 JourneyPage 不 stop controller；只有显式停止、正确完成后选择停止、账号过期/退出时清理。completed journey 以 revisit 初始化，只加载 ledger/音频，不调用 active-tour API 或 location tracker。

### 6. 路线选择先看账号 journey index

新增 user-scoped `journeyLibraryProvider`，登录后拉取一次集合，refresh、完成、上传/删除证据后精确 invalidate。Discovery 将 route id 映射到 active/latest completed：

- active card 点击：把 collection 中的 route/session 注入 controller 并直达 `/journey/{id}`；
- only completed：音频路线直达 revisit，legacy 路线直达 recap；
- none：保持 route detail 与 first-time start；
- deep link/内存丢失：JourneyPage 通过 collection item 补回 route/session；若集合未命中，再 owner-fetch journey 并从嵌入 route context 恢复，而不是要求用户返回详情。

因此集合响应嵌入足够的 route payload（包括 audio manifest 对已拥有 archived journey 可读），并让客户端不依赖公共 `/routes/{slug}` 对 archived 内容的限制。

### 7. 历史重听只切播放选择，不写进度

轨道节点从装饰性 `AnimatedContainer` 改为具有至少 48x48 命中区、Semantics 状态和 selected indicator 的按钮。只有 `isRevealed && isCollected` 或当前 live fragment 可选；locked tap 只反馈原因。

`selectFragmentForReplay(id)` 的顺序为 player.stop → 清空自动触发 queue 中与用户选择冲突的播放项 → 设置 selected id/position → 按用户动作开始播放。完成回调先检查是否为 replay；replay 不调用 playback API，live 才进行 idempotent acknowledge。`progressFragmentId` 始终由 ledger 未完成状态派生，所以重听不会把定位/依赖游标带回旧节点。用户可点当前进度节点返回 live 叙事。

### 8. 照片 viewer 与怀旧画框复用同一展示组件

创建 presentation-level `EvidencePhotoButton`、`EvidencePhotoViewer` 和 `KeepsakeFrame`：

- 优先显示仍存在的本地 capture 文件，否则加载鉴权 server bytes；
- 点击始终通过显式图片按钮打开独立全屏/大 sheet viewer，不把手势偷偷绑在普通 image view 上；
- frame 使用 code-native `CustomClipper/CustomPainter` 生成轻微不规则纸边、内层暖白留边和克制阴影，稳定 seed 决定每张卡的微小旋转，避免列表重建抖动；
- 大图 viewer 不加毛边裁剪，保留原比例、缩放与清晰度；frame 只是 UI 外壳，不修改证据文件；
- `MediaQuery.disableAnimations` 时旋转/入场动画关闭。

这比引入网络纹理或逐路线位图框更小、更清晰，也避免过度装饰。足迹和 JourneyPage 共享相同 evidence metadata/provider/viewer，确保重启后的行为一致。

### 9. 设置本地按 user id 命名空间隔离

建立 `UserPreferenceRepository(userId)`，SharedPreferences key 统一为 `user.{id}.<setting>`。迁移现有全局 location mode：首次登录读取旧 key 一次写入用户 key，随后不再共享。设置包含：默认 speed、location mode、prepared-download policy (`wifiOnly | anyNetwork | manual`)、cache clear、动态 evidence policy、app version。

Prepared audio 是公开内容，可跨账号复用，但 cache clear 需要同时删除 `prepared_assets` 索引和 application support 下的 prepared 文件；`clearPrivateData` 继续只负责用户 snapshots/outbox。为了可靠判定预下载策略，将 `connectivity_plus` 声明为直接依赖；为了显示构建版本，将现有传递依赖 `package_info_plus` 声明为直接依赖。网络类型只约束整路线预下载，按需在线播放仍可在用户触发时进行并显示流量提示。

## Failure behavior

- 集合 API 401：走统一 auth expiry；列表级网络失败保留最后一次内存数据并给 refresh，不能显示其他账号缓存。
- 证据 404/410：区分已删除或过期的中性占位；401 触发重新登录；网络失败显示 retry，不降级为公开 URL。
- 播放圆球导航的 journey 已归档/集合刷新：使用 owner collection 的 embedded context；若 owner endpoint 也失败，保留后台播放状态并提示恢复失败，播放控制仍可从系统媒体通知或恢复后的旅程页操作。
- 跨景点交接在旧音频停止后加载新音频失败：旧旅程进度不变且不自动复播，圆球不继续冒充旧 owner；展示新景点加载失败和重试入口。
- 模拟 next 的 playback ack 成功但 trigger 失败：ledger 已保存当前 collected，界面停在可重试下一节点，不恢复被 stop 的旧音频。
- cache delete 某文件失败：继续清理其他文件，汇总失败数，不删除 DB journey/evidence。

## Risks / Trade-offs

- [旧 `mission_pending` 行与新规则并存] → ledger 读取时做幂等 reconcile，并增加迁移/回归测试覆盖上传、删除、完成旅程。
- [旅程集合嵌入 audio manifest 响应较大] → 列表默认返回 route summary；进入 journey 时通过 owner context/detail 拉完整 manifest，客户端按 id 缓存本次会话，避免列表重复大音频元数据。
- [跨页 provider 被意外 dispose 导致音频停止] → player/controller provider 保持应用级非 auto-dispose，测试在 route navigation 后断言实例和 position stream 连续。
- [持续旋转耗电、掉帧或引发眩晕] → 仅在实际 playing 时驱动单个合成层动画，以 `RepaintBoundary` 隔离重绘；暂停、页面不可见和 reduced-motion 时停止 ticker，并通过性能/widget 测试验证。
- [自由拖动与首页滚动、点击返回冲突] → 使用明确 pan 阈值和手势竞技场，拖动开始即取消 tap；限制到可达安全区域并提供语义方向移动动作，位置用归一化坐标跨布局恢复。
- [另一景点开始播放时旧回调写入或双音频重叠] → 单一 player 加 owner generation；先使旧 callback 失效并 stop/clear queue/location，再装载新 owner，测试各页面入口和加载失败竞态。
- [重听结束回调误写 live 进度] → completion callback 携带 loaded fragment id 与 playback purpose token，过期 callback 直接忽略。
- [管理员与 API 字段部署顺序不一致] → 字段先 nullable、读端 fallback；先部署 API migration，再 Admin，再重新发布内容，最后发布要求新字段的客户端。
- [私有图片 bytes 占用内存] → viewer 只缓存缩略图尺寸解码结果和当前大图，离开 viewer/切换用户清理；不持久化 bearer URL。
- [不规则画框影响性能或显得杂乱] → path 按尺寸/seed 缓存，旋转限制在极小范围，大图不用装饰，并用 golden/widget tests 固定视觉层级。

## Migration Plan

1. 主仓库先增加 Alembic migration：photo guidance nullable 列与 journey 查询索引；执行现有数据库迁移测试和 upgrade/downgrade smoke test。
2. 部署向后兼容 API：新集合、policy、evidence-list 端点，start/revisit 查询，photo non-gating reconcile；旧客户端仍可使用现有端点。
3. 在独立 `Travel-Admin` 仓库增加对应 migration/model/editor/validation/import-export 字段并单独测试、提交和部署。
4. 更新本仓库 seed 与三个服务端内容包的机位/朝向/构图文案，通过 admin validation、review、approve、publish 流程重新发布；验证公共 manifest 和 owner ledger。
5. 发布 Flutter shell、footprints/settings、首页旋转播放圆球、replay 和 evidence viewer；在 A/B 测试账号验证隔离及 active/completed 历史。
6. 生产观察 collection、playback、evidence 4xx/5xx 和客户端恢复日志，确认后再移除旧内容字段 fallback（不在本次变更内）。

回滚时先回退 Flutter，旧客户端仍使用兼容 API；后端回退业务代码但保留新增 nullable 列和索引不会影响旧版本。不要删除 journey/evidence 数据或 MySQL/私有证据卷。Admin 可独立回退 UI；内容包新字段对旧 importer 需在回退前确认会被忽略，否则保留已部署 importer。
