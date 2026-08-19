# 见地 MVP 实现设计

版本：0.1  
状态：实现基线  
目标：用一个真实可走、也可在家演示的城市文化探索闭环验证产品价值。

## 1. 产品定义

见地是一款面向自由行与城市漫游用户的深度旅行应用。它不追求“讲得最多”，而是让用户在正确的地点，以短故事、现场观察和轻解谜理解城市。

一句话价值主张：**走进一座城，也读懂它。**

首个 MVP 体验为“上海衡复街区：梧桐树下的城市切片”，约 2.8 公里、70 分钟、5 个站点。路线数据用于产品演示，正式公开发布前需要地方史专家或编辑逐条核验并补充来源。

## 2. MVP 范围

### 2.1 核心用户

- 25–40 岁自由行或本地城市漫游用户；
- 对历史、建筑与日常生活好奇；
- 不愿参加固定团队，也不愿长时间盯着屏幕；
- 可接受一段 60–90 分钟、有起点终点的轻量体验。

### 2.2 核心闭环

发现路线 → 查看路线价值与难度 → 开始旅程 → 到达站点 → 听/读故事 → 观察现场 → 回答 → 获得解释 → 前往下一站 → 生成回顾。

### 2.3 本期交付

- 城市与主题路线发现；
- 路线详情、站点预览、路线折线地图；
- 游客会话，无需注册；
- 开始、恢复与完成旅程；
- 五站顺序探索；
- 音频播放器形态与文本兜底；
- 单选式观察挑战、提示、答案反馈；
- GPS 到达判定接口与“演示到达”模式；
- 完成页与知识卡片；
- API 异常、空状态、加载状态；
- MySQL 持久化、Docker 启动、确定性种子数据。

### 2.4 本期不做

- 登录注册、付费、社交、多设备同步；
- AR、后台持续定位、实时多人；
- 内容管理后台与创作者平台；
- 真正的离线地图瓦片与音频下载；
- 生产级历史内容审核与版权工作流。

## 3. 体验与界面设计

### 3.1 视觉语言

- 品牌：见地 JIAN·DI；标语“走进一座城，也读懂它”。
- 气质：城市编辑刊物 + 随身展览手册，避免游戏厅式高饱和界面。
- 主色：墨蓝 `#142B33`；陶土 `#C66A4A`；苔绿 `#66745B`；纸张 `#F6F1E8`；金砂 `#D6B875`。
- 卡片使用 20–28dp 圆角、柔和阴影和 1dp 半透明描边；信息层级依靠留白与字号，而非大量分割线。
- 图片采用暖色、自然材质和可供文字叠加的构图。MVP 两张封面由 ImageGen 生成并随仓库交付。

### 3.2 动效原则

- 页面进入：淡入 + 12dp 上移，240–360ms，强调“展开一本城市手册”；
- 卡片按压：缩放至 0.98，120ms；
- 站点推进：进度线弹性增长，使用标准 emphasized easing；
- 答题反馈：正确状态柔和扩散，错误只轻微水平位移，不制造惩罚感；
- Hero 图片跨详情页过渡；
- 尊重系统减少动态效果设置，并避免持续循环动画。

### 3.3 页面结构

1. **发现页**：欢迎语、当前城市、主题筛选、主路线卡、探索理念；
2. **路线详情**：大图、路线指标、故事引子、5 站时间轴、开始/继续按钮；
3. **旅程页**：沉浸式顶部图片、当前站、音频条、观察任务、答案反馈、下一站；
4. **路线地图页**：轻量示意地图、折线和站点状态；
5. **完成页**：完成动效、旅程统计、解锁的 5 条知识卡、再次浏览。

### 3.4 参考提炼

- VoiceMap：自动 GPS 播放、暂停后原地恢复、离线优先，核心目标是让用户看街道而不是看屏幕；
- Questo：把真实建筑细节变成谜题，地点与故事共同推进；
- Bloomberg Connects：音频、图片、文字并存，并保留可访问性；
- Apple 地图交互原则：地图应保持可平移缩放，浮层不长期遮挡关键空间；
- Flutter Material 3：使用 NavigationBar、统一色彩方案与平台自适应返回行为。

## 4. 系统架构

采用“可拆分的模块化单体”。MVP 不为未来假设付出分布式系统成本，但所有业务模块通过明确接口沟通。

```text
Flutter
  View → ViewModel → Repository interface → Repository impl → API/Demo service
                                              ↓
Flask REST API
  Presentation → Application use cases → Domain entities/ports
                                         ↓
                                  Infrastructure repositories → MySQL
```

### 4.1 后端边界

- `presentation`：HTTP、序列化、认证上下文、错误映射；
- `application`：用例编排与事务边界，不依赖 Flask；
- `domain`：实体、值对象、状态规则、仓储端口，不依赖数据库；
- `infrastructure`：SQLAlchemy 模型、仓储实现、JWT、时钟；
- `bootstrap`：配置、依赖装配、应用工厂。

领域模块：

- Catalog：城市、路线、站点、挑战，只读内容发现；
- Journey：游客旅程、当前站、答案、完成状态；
- Identity：匿名游客令牌；
- Platform：健康检查、数据库与错误协议。

未来拆分点：Catalog 与 Journey 的仓储端口不互相引用；对外只传 ID 和 DTO，可分别迁出进程。

### 4.2 Flutter 边界

- `core/`：主题、路由、网络、错误、通用组件；
- `features/<feature>/data`：DTO、服务、仓储实现；
- `features/<feature>/domain`：不可变模型、仓储接口；
- `features/<feature>/presentation`：View、ViewModel、局部组件；
- Riverpod 负责依赖注入和可观察状态；
- go_router 负责声明式路由与深链准备；
- Dio 负责 REST；Demo Service 与 API Service 实现同一接口。

## 5. 数据模型

### 5.1 内容

- `cities(id, slug, name, subtitle, hero_image, latitude, longitude)`
- `routes(id, city_id, slug, title, subtitle, description, duration_minutes, distance_km, difficulty, theme, hero_image, is_featured, published_at)`
- `stops(id, route_id, position, title, kicker, address, latitude, longitude, arrival_radius_m, story_title, story_body, audio_url, image, insight)`
- `challenges(id, stop_id, prompt, hint, options_json, correct_option, explanation)`

### 5.2 旅程

- `guest_sessions(id, token_id, created_at, expires_at)`
- `journeys(id, guest_session_id, route_id, status, current_stop_position, started_at, completed_at, updated_at)`
- `journey_answers(id, journey_id, stop_id, selected_option, is_correct, answered_at)`

约束：同一旅程同一站点只保留一个最终答案；站点按 `position` 唯一；完成最后一站后旅程原子地进入 `completed`。

## 6. API 合约

统一前缀 `/api/v1`，JSON 使用 snake_case。错误格式：

```json
{"error":{"code":"journey_not_found","message":"旅程不存在","details":{}}}
```

端点：

- `GET /health`：进程与数据库状态；
- `POST /sessions/guest`：创建游客令牌；
- `GET /cities`：城市列表；
- `GET /cities/{slug}/routes`：城市路线；
- `GET /routes/{slug}`：完整路线详情；
- `POST /journeys`：以 route_id 开始或恢复当前游客旅程；
- `GET /journeys/{id}`：旅程状态；
- `POST /journeys/{id}/arrivals`：确认当前位置或 demo 到达；
- `POST /journeys/{id}/answers`：提交当前站答案；
- `POST /journeys/{id}/advance`：答案后推进；
- `GET /journeys/{id}/recap`：完成回顾。

所有 Journey 端点需要 `Authorization: Bearer <guest-token>`。写接口支持幂等：重复开始返回未完成旅程；重复提交同一答案返回现有结果。

## 7. 运行与安全

- Docker Compose：`mysql` + `api`；MySQL 8.4，健康检查后 API 启动；
- Flask 开发模式不暴露在生产配置；
- JWT 只包含随机会话 ID 和过期时间，不包含个人信息；
- CORS 开发环境可配置，默认允许本地 Flutter 调试；
- 所有 ID、选项和坐标服务端校验；
- 限制请求 JSON 大小；
- 日志不记录令牌；
- 演示到达只由后端配置 `ALLOW_DEMO_ARRIVAL` 控制。

## 8. 测试策略

- Domain：旅程状态机、距离判断、答案幂等；
- Application：开始/恢复、错误站点、完成回顾；
- API：健康检查、目录读取、完整五站闭环、鉴权与错误协议；
- Flutter：模型解析、Demo Repository、核心页面 widget smoke test；
- 验收：Docker 启动后种子数据可读；Flutter Demo 模式无需密钥可完成路线。

## 9. 完成定义

- OpenSpec 变更通过严格校验；
- 后端测试通过，API 容器健康；
- Flutter `analyze` 与测试通过（若本机 SDK 可用）；
- README 能让新开发者用 Docker 启动后端，用一个命令选择 Demo/API 模式运行客户端；
- 代码不存在跨层反向依赖；
- 所有演示史实有显眼的“上线前需核验”说明。

## 10. 设计依据

- OpenSpec 流程与产物：https://openspec.dev/ 与 https://github.com/Fission-AI/OpenSpec
- Flutter 官方架构指南：https://docs.flutter.dev/app-architecture/guide
- Flutter 导航：https://docs.flutter.dev/ui/navigation
- VoiceMap：https://voicemap.me/
- Questo：https://questoapp.com/
- Bloomberg Connects：https://www.bloombergconnects.org/
- Apple 地图设计指南：https://developer.apple.com/design/human-interface-guidelines/maps
