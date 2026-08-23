# 城市故事、出发前预览与内容包合同

本功能建立在既有 `story_arcs`、`story_fragments` 和已审核旁白轨道之上。`story_catalog_items` 只保存分发元数据，`story_catalog_variants` 只保存规范来源、轨道和版本引用；不得复制文字稿或音频。规范正文变化后，旧 revision 的变体不会进入公开投影。

## 公开 API

- `GET /api/v1/cities/{city_slug}/stories`：始终返回五个模块槽位：`today_city_story`、`street_corner_3min`、`city_small_thing`、`overlooked_detail`、`today_destination`。无内容时返回 `empty_reason`、`fallback_cities` 和 `actions.switch_city`。
- `GET /api/v1/city-stories/{catalog_id}`：返回共享听读投影；首页、出发前和现场入口使用相同 `catalog_id`、`canonical_revision` 与既有播放器字段。
- `GET /api/v1/routes/{route_slug}/pretrip`：返回主题故事、建议故事方向、同行标签、四类编辑提示和离线资源清单。`requires_arrival=false`、`advisory_order=true`，不返回答题内容。
- `GET|PUT|DELETE /api/v1/favorites...`：登录用户可幂等收藏或移除 `city`、`point`、`theme`；不可用目标仅返回可移除的最小状态。

路线详情中的 `pretrip` 和 `companion_tags` 是向后兼容的新增字段；旧客户端可以忽略。既有 `/stories/random`、单路线内容包和现场节点 API 保留。

## 离线资源

每项资源包含 `id`、`kind`、`url`、`version`、`checksum_sha256`、`size_bytes`。客户端只有在大小和 SHA-256 都通过后才将临时文件原子改名为可用文件；同一资源的新版本会清理旧版本。部分失败不算整包成功，可以单独重试或移除。

## 多城市 JSON 1.0

示例见 [`docs/content-packages/multi-city-story-v1.json`](content-packages/multi-city-story-v1.json)。根字段：

- `schema_version`：当前固定为 `1.0`；
- `package_id`、`package_version`：稳定且由内容团队管理；
- `package_checksum`：可选声明值；服务端移除此字段后，对规范化 JSON 计算 SHA-256 并校验；
- `entities`：支持 `cities`、`routes`、`stops`、`story_arcs`、`story_fragments`、`catalog_items`、`variants`、`placements`、`pretrip_guidance`、`media`。

限制：文件不超过 2 MB、实体总数不超过 5,000。媒体只能用 `media.key` 引用已上传的受管媒体并可附校验和；禁止 base64、data URI、二进制和任意远程下载地址。

管理端导入分为两步：上传预检返回 `new/updated/unchanged/conflicted/invalid` 和精确 JSON Pointer；确认令牌绑定管理员、包校验和、目标 revision，并在 15 分钟后失效。确认会再次校验目标 revision，在单一事务中写入，所有可发布状态强制降为草稿或审核中。任何失败都会回滚全部内容。相同 ID/版本/校验和重放为 unchanged；相同 ID/版本但校验和不同为冲突。
