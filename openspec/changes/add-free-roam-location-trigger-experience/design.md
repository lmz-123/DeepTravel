## Context

参见 [proposal.md](./proposal.md)。现有真实定位链路已经在 Flutter `StableTriggerEngine` 中同时评估全部未揭示 fragment，并在多个候选中选择最近点；逐点 `trigger_region`、旅程 ledger、outbox、足迹、可选照片和因果重构均已存在。因此本次重点是锁定真实定位乱序触发契约、补足发布资格验证，并在保留原节点轨道和节点页的前提下补充自由选择与接近状态。

当前公开 fragment 已包含坐标、独立半径、后台体验标签和音频引用，但没有稳定的展示时长字段。独立后台已经编辑、校验并导入逐点 trigger region；除非实现核查发现字段缺失，否则不新增后台仓库变更或数据库迁移。

## Goals / Non-Goals

**Goals:**

- 以 stable point identity 为触发、播放、收集、恢复和重构之间的连接键，彻底取消“当前节点游标”对真实定位资格的影响。
- 在不增加地图和位置轨迹的前提下提供可测试的附近点派生状态。
- 复用现有发布、围栏、音频、旅程和足迹模型，并保持旧客户端/旧旅程响应兼容。

**Non-Goals:**

- 不把“附近点列表”扩展为导航器、路线推荐器或后台排序系统。
- 不移除围栏的精度、稳定样本、迟滞、冷却或幂等保护。
- 不改变 legacy stop/answer 路线的兼容状态机。
- 不为展示主题新建固定枚举，也不在 Flutter 内置标签表。

## Decisions

### 1. 真实位置继续一次评估全部点，触发 API 不解释故事依赖

客户端保留一个 route-scoped trigger engine，输入当前真实 sample、公开 manifest 和 ledger 的已揭示 ID。每次 sample 对所有未揭示点独立计算围栏状态；若多个点完整满足策略，按未取整距离、后台 position、stable ID 确定一个候选，每次 evaluation 最多提交一次。后续 sample 仍可触发其余候选。

服务端 trigger application service 对真实定位方法只验证 owner journey、幂等键、fragment 属于旅程、当前内容仍可用于新现场触发和 trigger region，不查询 `fragment_dependencies`。`dependency_ids` 继续随 manifest/ledger 返回，供故事解释使用，但不属于真实定位 trigger eligibility。

备选方案是在数据库删除 dependency rows。它会破坏因果说明、旧内容包和重构编辑，不采用。

### 2. “已发布点”在新触发与历史读取之间分开处理

新触发必须来自 active journey 对应的公开 route manifest，fragment 为可发布审核状态，且 trigger region 通过现场审核。内容撤回后不接受该点新的现场 trigger；已经触发/收集的 owner state、文字稿、音频引用和足迹仍按现有历史兼容策略读取，避免内容运营动作抹掉用户记录。

API URL 不变。拒绝新增触发时返回现有结构化状态冲突/不可用错误，不泄露未发布内容；旧客户端无需认识新端点。

### 3. 附近点是 Flutter 的瞬时派生投影，不是服务端位置查询

新增纯领域投影 `NearbyStoryPoint`（命名可在实现中调整），输入 manifest fragment、ledger entry 和最新 real sample，输出：stable ID、title/safe preview、display theme、expected duration、heard/revealed state、region presence、可选 distance。排序规则为：有 real sample 时距离升序、position、ID；无 sample 时 position、ID，且 distance 必须为 null。

该派生投影只为原节点轨道的状态和所选节点详情提供数据，不形成独立的“附近故事点”列表，也不按距离重排节点轨道。进入 entry radius 且采样合格时，所选节点可显示“可触发/正在确认”；已揭示显示“已触发/已听过”，其他点显示“尚未接近”。用户无需打开地图；距离仅作当前选中节点的临时状态说明，不成为路线推荐或完成条件。

ActiveTourState 只保存派生后的距离/region presence 或一次 UI 更新所需的短生命周期 sample；不写 shared preferences、SQLite、API payload（除实际 trigger）或 runtime log。停止旅程、切换账号/路线和 controller dispose 时清除。

备选方案是每个 sample 上传后由服务端返回 nearby。它会增加延迟、网络与位置暴露，且现有 manifest 已有计算所需字段，不采用。

### 4. 主题和预计时长从现有后台内容派生

公开 fragment 投影增加向后兼容的 `display_theme` 与 `expected_duration_seconds`：主题优先取 fragment 的第一个后台 `experience_tags`，为空时取 route/arc 的后台主题；时长优先取当前发布 narration track 的可信时长，旧轨道没有时长时按正文长度作明确的预计值。Flutter 对字段缺失提供旧 API rolling-deployment fallback，并原样展示未知安全标签。

不新增主题枚举、客户端映射或数据库列。若实现时确认当前 narration track 无法提供真实时长，预计值只作为近似并以“约 X 分钟”展示，不伪装成播放器精确 duration。

### 5. 保留原节点入口，并将节点选择与现场触发分离

旅程页继续使用原有节点轨道作为主要节点入口，不以可滚动 nearby list 或另一套故事点列表替换。点击任意节点后，在轨道下方插入一个所选节点详情区，复用 nearby 派生状态与后台 fragment 文案，依次展示预览/已揭示文案、主题、预计时长、已听状态和接近/定位状态；现有音频卡片保持在该详情区下方。选择未触发节点时只高亮该节点并展示安全预览与“到达范围后自动触发”的提示；它不能通过点击伪造 arrival、解锁、播放或收集。选择已触发节点时继续打开原节点内容并允许回听。

节点数量由 `manifest.fragments` 唯一决定，不使用“五个节点”常量。轨道先按可用宽度和节点数量收缩视觉圆点与间距，同时保留至少 44dp 的语义点击区域；当单行仍无法安全容纳时使用横向滚动而不是溢出、裁剪、丢弃或换成故事点列表。

`selectedFragmentId` 表示当前选中的节点，不参与 location engine 的 candidate 集合。未触发节点也可以写入这个纯 UI 选择值，但不得写入 ledger、本地进度或触发 API。选择任意节点都不能改变其他节点的独立触发资格，也不能把选择顺序写成旅程进度或故事因果顺序。

选择历史节点时先安全交接单一播放器，再读取现有已揭示内容。回听 completion callback 使用 playback generation 和 replay mode 隔离，不写新的 trigger/collection；返回当前现场节点不影响其他 region presence。

正式真实定位页面不提供“下一站”作为主动作。

### 6. 部分旅程复用 journey library 作为足迹

后端现有 journey collection 已返回 active/completed；Flutter 足迹页面调整为同时展示“进行中”和“已完成”，不新建 footprint 表。进行中卡显示已听/总点数、最近更新时间和可选照片数，点击恢复 journey context。未完成旅程无需提交 reconstruction 或人工归档即可留下记录。

本地 outbox 继续负责离线 trigger/playback/evidence 事件；恢复顺序固定为 owner context → local snapshot → outbox flush → server ledger reconciliation，服务端状态胜出且不回退已收集节点。

### 7. 因果顺序只属于 reconstruction contract

`causal_model_json` 和 stable reconstruction IDs 保持唯一正确关系来源。解锁条件仍为收集全部 required fragments，不比较 `triggered_at/collected_at/position` 顺序。重构 API 只对 submitted IDs 与 causal model 评分；走路顺序可用于用户回顾展示，但不得写回或重排 causal model。

## Risks / Trade-offs

- [多个重叠围栏可能让临时接近状态频繁变化] → 使用现有稳定样本/迟滞；节点轨道始终保持后台顺序，距离只更新所选节点详情。
- [内容撤回会让进行中用户无法触发剩余点] → 已有进度继续可读，UI 明确标注该点暂不可用并提供刷新/退出；不绕过发布审核。
- [旧 API 没有主题或预计时长] → Flutter 提供无虚假值的兼容 fallback，服务端先部署，客户端后部署。
- [自由触发后多个音频争抢播放] → 每次 sample 最多触发一个，沿用全局单播放器 ownership 和 generation，其他合格点留待后续 sample。

## Migration Plan

1. 先部署不破坏旧字段的后端资格调整和 fragment 展示元数据，运行 trigger、publication、journey、footprint、reconstruction 回归测试。
2. 再发布 Flutter nearby projection 和旅程 UI；旧客户端继续使用原 manifest/ledger 字段，新客户端对旧服务端字段缺失安全回退。
3. 不需要数据库迁移或独立后台部署；若实现核查改变该结论，必须先更新本设计和 OpenSpec tasks 再动对应仓库。
4. 验证真实定位乱序触发、重叠围栏、权限失败、离线恢复、部分足迹、回听、内容撤回和因果重构。生产构建保持测试鉴权关闭，并按项目规范验证 APK。
5. 回滚时先回滚 Flutter UI，再回滚后端资格调整；现有 journey/fragment 状态无 schema 变化，不需要数据回填或删除。
