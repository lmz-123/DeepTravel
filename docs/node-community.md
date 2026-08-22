# 节点内“见地现场”

## 产品边界

“见地现场”只出现在已解锁节点内容的最下方，以及足迹详情中当前选中节点的私人留念之后。发现页、城市选择、旅行者侧栏和全局导航不提供动态入口或红点。用户切换节点时，客户端使用账号、旅程和节点组成的状态键，旧请求不会覆盖新节点；社区加载失败也不会停止导览音频。

卡片支持图片优先和纯文字纸张样式，显示旅行者昵称、分类、标题或摘要、点赞与评论数。点击后打开接近全屏的详情，可缩放图片、查看点赞者和一级评论，并执行点赞、评论、作者删除或举报。事实补充始终显示“旅行者内容”，不能替代官方叙事。

## API

所有社区接口均要求 Bearer 账号，并要求当前账号至少有一条属于自己的旅程已揭示目标节点。非本人旅程、锁定节点、已删除/暂存内容和被当前用户举报的内容采用不可枚举的 404 语义。

- `GET /api/v1/policies/community`：客户端可见的分类、长度、图片和举报原因策略。
- `GET|POST /api/v1/journeys/<journey_id>/fragments/<fragment_id>/community-posts`：节点摘要流与 multipart 发布；查询支持 `category`、`cursor`、`limit`。
- `GET|DELETE /api/v1/community-posts/<post_id>`：完整详情和作者软删除。
- `GET /api/v1/community-posts/<post_id>/likes`、`PUT|DELETE .../like`：点赞者分页与幂等点赞。
- `GET|POST /api/v1/community-posts/<post_id>/comments`、`DELETE /api/v1/community-comments/<comment_id>`：一级评论分页、幂等发表和作者删除。
- `POST /api/v1/community-posts/<post_id>/reports`、`POST /api/v1/community-comments/<comment_id>/reports`：唯一举报；达到阈值后自动暂存等待人工复核。
- `GET /api/v1/community-media/<media_id>`：鉴权图片读取，不存在匿名 `/assets` 暴露。

分页游标经过签名并绑定节点、筛选或目标，不能跨查询复用。返回的作者只包含展示昵称和默认头像，不返回用户 ID。媒体响应不包含对象键、Bucket、签名凭证、校验和或审核阈值。

## 图片与隐私

上传内容会安全解码、纠正方向、移除 EXIF/GPS、限制最长边并重新编码，随后写入私有对象存储的 `community/` 命名空间。单条动态最多四张图。发布失败会清理已暂存对象，动态软删除会清理社区副本。

足迹照片默认仍为私人证据。只有用户在发布器中明确选择并再次确认“分享到见地现场”后，服务端才会读取当前账号、当前旅程、当前节点且未过期的证据，生成生命周期独立的社区副本。删除社区动态不会删除私人证据；私人证据之后过期或删除，也不会删除已成功发布的社区副本。

## 配置、部署与回滚

生产环境可配置 `COMMUNITY_ENABLED`、三个文本长度、`COMMUNITY_MAX_MEDIA`、`COMMUNITY_MEDIA_MAX_BYTES`、`COMMUNITY_MEDIA_MAX_EDGE`、`COMMUNITY_MEDIA_RETENTION_DAYS`、`COMMUNITY_MEDIA_ALLOWED_MIME_TYPES` 和 `COMMUNITY_AUTO_HOLD_REPORT_THRESHOLD`。社区媒体复用私有存储适配器；本地部署复用 `/app/private-evidence` 持久卷，OSS 部署复用私有 Bucket 凭证。

上线顺序：先部署 API 并执行 `alembic upgrade head`，确认健康检查，再发布客户端。紧急回滚优先设置 `COMMUNITY_ENABLED=false` 并重启 API，这会关闭读写入口但保留审核数据；不要直接删除表或私有媒体。如果必须回退代码，先关闭开关，保留数据库在新版本，待兼容版本恢复后再开放。

音色选择位于讲解播放卡片内，切换同一片段时保持比例进度和播放/暂停意图。模拟定位只在设置页编辑；路线详情和旅程状态仅显示当前模式，测试用“下一条线索”按钮仍按后端开关工作。
