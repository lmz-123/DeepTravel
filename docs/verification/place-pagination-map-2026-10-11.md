# 景点分页与地图手势验收（2026-10-11）

## 本次范围

- 全部景点改为 API 游标分页，每页 12 条，与见闻采用相同的按需追加、去重、失败重试和过期请求隔离策略。城市、搜索、区域、分类及距离排序均在服务端执行。
- 列表不再依赖完整路线清单；地图单独请求轻量标点，选中后再请求景点简介。主页与随行目录使用轻量摘要，开启随行时才读取完整声音导览。
- 自有 OSS 景点图片提供 240px 缩略图与 960px 预览，列表按需加载；不改写外部或带查询参数的资源，不改变首页大图。
- 所有城市共用地图手势识别：拖动优先于页面滚动，轻触标点仍有效，支持双指缩放；地图手势不重建整页，投影在连续手势帧间复用。
- 票务代码与 CMS 配置未修改。用户要求先评估，无法满足就先不改。

## 验证

- Flutter 全量 338 项测试通过；地图投影复用调整后，地图、分页、多城市及界面回归 30 项通过。
- 增加目录摘要在开启随行时加载完整导览的回归测试。
- Flutter analyze 无问题。现有列表/地图截图基线对比通过，包括窄屏；手动查看 390px 列表及地图基线。
- API 全量 141 项通过，29 条既有弃用警告；ruff 通过。
- 新 API 测试覆盖真实多页、排序、过滤、跨筛选游标拒绝、未发布数据排除、摘要无重型导览数据与 OSS 图片尺寸。
- 手势测试覆盖轻触、纵向/横向/斜向拖动、双指缩放、指针取消后页面正常滚动。未声称已完成实体手机触控性能测试。

## 部署

本次 **需要部署 API**，随后更新客户端。CMS 不需要更新；无数据库迁移、无新增环境变量。先部署 API，旧客户端仍可使用原接口；新客户端依赖新的 places 与 place-markers 接口。

在已核实的服务器 Compose 工作目录执行，路径与部署分支必须使用该服务器实际值。源代码推送分支是 `codex/v5-client-art-magazine`；不要据此擅自切换服务器分支。

```bash
cd "${DEEPTRAVEL_API_DIR:?Set the verified server API checkout}"
git fetch origin "${DEEPTRAVEL_API_BRANCH:?Set the verified deployed branch}"
test "$(git branch --show-current)" = "$DEEPTRAVEL_API_BRANCH" || exit 1
git pull --ff-only origin "$DEEPTRAVEL_API_BRANCH"
docker compose build api
docker compose up -d api
docker compose ps
curl -fsS "${DEEPTRAVEL_ORIGIN:?Resolve the current API origin}/api/v1/health"
curl -fsS "${DEEPTRAVEL_ORIGIN}/api/v1/cities/shenzhen/places?limit=12"
```

没有服务器 Shell 访问，本次未执行线上部署。按本次用户“推送就行”的范围交付源代码，未打新 APK。

## 票务评估（未实施）

原海洋王国设计 `travel-ticket-wallet.html` 的选票、日期、数量、订单页是 UI 原型：`pay` 打开“支付预览”，`paid` 仅更新本地示例状态。它不是已接入的真实下单实现，示例价格不能当作实价。

本次只读核对到：

- 世界之窗当前配置的 `https://www.ctgii.com/scenic/theme_park/62` 提供扫码购票指引，不能证明支持从 App 原生订单跳到付款。
- 长隆官网 `https://www.chimelong.com/zh/oceankingdom/` 有票价信息，并链接至 `https://xzx.chimelong.com/scenicDetail?scenicCode=ZH56`；该链接是景区选票页，不是保留 App 选择并支付的订单链接。

因此“任意官网链接自动解析，再在 App 内原生下单、仅付款跳转”目前无法通用、可靠实现。展示公开票种信息与创建有效订单是两种能力。后者须逐渠道验证正式下单能力、日期库存、实名要求、付款订单与状态返回；不能靠抓取票价或给网页随意拼参数替代。未创建真实订单、未付款，亦未将模拟成功加入正式客户端。
