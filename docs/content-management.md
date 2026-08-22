# 无代码新增城市与碎片导览路线

新增城市、景区或路线不再修改 Flask、Flutter 或 seed。内容人员只操作独立后台；后台把私有草稿写入与 Flask 共用的 MySQL，发布成功后客户端自动读取。

## 标准链路

1. 在后台“媒体库”上传无文字封面和每段旁白，复制返回的 `storage_path`。
2. 在“批量导入”导入完整内容包，或复制 `docs/content-packages/dameisha-remade-coast-v1.json` 后替换全部稳定 ID、城市、路线、故事、来源、主张、坐标与媒体路径。
3. 到“碎片导览”选择路线，编辑完整故事、逐条旁白、WGS-84 触发区、照片任务；来源/主张和因果顺序可在“高级 JSON”修改。
4. 保存草稿后点击“校验数据库版本”。错误必须清零；`in_review` 现场坐标和预览音频会作为警告保留。
5. 点击“校验并发布”。只有此时 `published_at` 才会写入，Flask 公共目录才会出现路线。
6. 用真实手机完成 `docs/field-checklists/` 下对应检查表。

## 内容包最低要求

- `package_id` 与 `package_version`：同一组合重复导入幂等；升级必须更换版本。
- `city`、`route`、`story_arc`：稳定 ID，不复用其他路线的标识。
- `story_arc.causal_model`：每项是唯一 `{id, text}`，数量与碎片相同，顺序就是最终正确因果链。
- `fragments`：位置从 1 连续递增，依赖只能指向前序碎片；旁白与 transcript 必须完全一致。
- `trigger_region`：运行坐标只存 WGS-84，`exit_radius_m` 大于进入半径，并保留原坐标系、来源和现场备注。
- `claims` 与 `sources`：每条碎片至少关联一个有来源支持的史实主张。
- `photo_mission`：写明可观察对象、安全提醒和无障碍/延期替代方案。
- `media`：资源 key、服务器相对路径和 MIME；包导入会验证文件确实存在并登记数据库。

## API 自动化

后台基址示例：`http://115.29.221.190:5100/api/admin`。

```bash
ADMIN_BASE=http://115.29.221.190:5100/api/admin
ADMIN_TOKEN='DeepTravelAdmin2026'
PACKAGE=docs/content-packages/dameisha-remade-coast-v1.json

curl -fsS -X POST \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data-binary "@$PACKAGE" \
  "$ADMIN_BASE/fragmented-routes/import"

ROUTE_ID=$(jq -r '.route.id' "$PACKAGE")
curl -fsS -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$ADMIN_BASE/routes/$ROUTE_ID/validate"
curl -fsS -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$ADMIN_BASE/routes/$ROUTE_ID/publish"
```

## 版本与锁定

已发布路线一旦产生用户行程，结构修改会返回 `409 published_route_locked`，防止用户走到一半时故事、线索 ID 或位置被替换。当前 MVP 的修订方式是复制内容包，使用新的 route/arc/fragment ID 和新 `package_version` 发布新路线版本；后台不会覆盖旧行程使用的内容。

后台和 Flask 必须挂载同一媒体宿主目录。服务器部署独立后台时，把 `MEDIA_HOST_PATH` 指向 `DeepTravel/backend/media` 的绝对路径；否则后台能登记资源，但 Flask 容器可能读不到文件。
