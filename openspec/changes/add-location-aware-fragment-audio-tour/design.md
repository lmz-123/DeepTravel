## Context

See `proposal.md` for motivation. The existing Flask modular monolith models a route as ordered stops with one story, optional audio URL, one multiple-choice challenge, and an answer-gated journey. The Flutter client currently keeps its guest token and most journey state in memory, has no production audio engine, and removed location permissions for the temporary tap-to-arrive build. Public editorial media is served by the backend; private traveler media does not yet exist.

This change crosses catalog, journey, media, platform permission, background execution, local persistence, and content-production boundaries. It must remain testable without physically walking a route or calling a paid speech or vision service.

The historical route is not considered publication-ready merely because the planning draft cites sources. Field-visible claims, reconstructed structures, coordinates, narration pronunciation, and the complete causal interpretation still require editorial and on-site review before production status.

## Goals / Non-Goals

**Goals:**

- Keep domain/application/infrastructure/presentation boundaries in both backend and Flutter while introducing active-tour, fragment, and evidence state machines.
- Make lock-screen walking the default interaction and phone use an intentional interruption only for a photo mission or optional ledger review.
- Make trigger, playback, evidence, collection, and reconstruction events idempotent and recoverable offline.
- Separate reviewed historical claims from dramatic framing, and make source/authenticity metadata queryable rather than burying it in prose.
- Preserve legacy routes and journeys while the new Shenzhen route is validated.
- Provide adapters for location, audio, local event storage, and private evidence storage so later platform or storage changes do not rewrite domain rules.

**Non-Goals:**

- Exact pedestrian navigation, indoor positioning, beacon hardware, QR infrastructure, or semantic image recognition.
- Persisting a continuous traveler location history.
- A browser-based editorial CMS; reviewed seed/import data is sufficient for this iteration.
- Rewriting the Shanghai route into the new format in the same change.

## Decisions

### 1. Add modules inside the modular monolith

Backend modules remain in one Flask deployment:

- `catalog`: published routes, fragments, trigger regions, audio assets, mission previews.
- `historical_content`: sources, claims, claim-source links, authenticity and review decisions.
- `journeys`: active-tour lifecycle, trigger eligibility, fragment state, dependencies, collection, reconstruction.
- `evidence`: private upload metadata, storage port, authorization, deletion, retention.
- `media`: existing public editorial assets plus an explicit boundary that never exposes private evidence through public paths.

Flutter modules use the same direction of dependency:

- domain models and repository ports contain no plugin imports;
- application controllers own the active-tour, trigger, audio-queue, upload, and reconciliation state machines;
- infrastructure adapters wrap location, background execution, audio, camera, SQLite, and REST;
- presentation renders setup, compact active-tour status, player, camera mission, ledger, and reconstruction screens.

This keeps one deployable API while creating seams that could later extract evidence storage or content administration. A separate location microservice was rejected because trigger evaluation primarily belongs on-device for timely locked-screen playback and does not justify another runtime.

### 2. Use an explicit active-tour state machine

The client persists the following state independently of widget lifetime:

```text
idle
  -> preparing -> ready
  -> monitoring <-> paused
  -> reconstructing -> completed
  -> recoverable_error -> monitoring/paused
  -> stopped
```

Only `monitoring` permits automatic triggers. Starting requires an explanation of location, background operation, notification, battery, and camera usage before platform prompts appear. Stopping location monitoring does not delete journey progress.

The active tour is represented by an Android foreground-service notification where required and by platform location/audio background modes on iOS. The app never claims guaranteed background execution: it detects suspension or stale samples and reports a paused/limited state on resume.

Alternative rejected: always-on location monitoring. It is unnecessary, harder to explain, and incompatible with location minimization.

### 3. Evaluate stable geofence entry locally, verify single events on the server

Each fragment trigger region stores center latitude/longitude, entry radius, optional exit radius, maximum acceptable accuracy, minimum qualifying sample count, and cooldown. Initial defaults are configurable rather than hard-coded:

- two qualifying samples within 15 seconds;
- reported accuracy no worse than 50 meters;
- authored entry radius, initially expected to be 35–80 meters after field testing;
- exit radius at least 30 meters larger than entry radius;
- one trigger per journey fragment, so cooldown mainly protects pre-acknowledgement queue churn.

The client state for each region is `outside -> candidate -> inside -> acknowledged`. It calculates distance and stability locally. On entry it sends one trigger event containing the current sample, accuracy, time, method, and idempotency key. The server recalculates proximity, stores the outcome and trigger method, then discards raw coordinates after request handling; it does not build a breadcrumb trail.

If the network is unavailable, the event stays in the local outbox and playback may proceed from prepared assets. Reconciliation never auto-replays already-heard audio.

Alternative rejected: server polling every location sample. It increases latency, battery/network use, and privacy exposure without improving MVP trigger reliability.

### 4. Separate trigger, playback, mission, and collection

One journey fragment has independent timestamps/state for:

- `triggered`: field region was accepted or demo-triggered;
- `playback_started` and `playback_completed`;
- `mission_pending` and `evidence_id` when applicable;
- `collected`: the fragment's authored completion rule was met;
- `reconstructed`: the fragment was correctly placed/linked in the final model.

Passive fragments collect after a configurable playback threshold (default 90%) or explicit transcript completion. Photo fragments remain mission-pending until evidence is accepted. Hearing later eligible audio is allowed while an earlier photo mission is pending unless an authored dependency says otherwise.

This avoids treating location arrival, listening, and understanding as the same event. A single `current_stop` integer was rejected because it cannot represent queued audio, postponed missions, flexible walking order, or offline reconciliation.

### 5. Use a single deterministic audio coordinator

The application owns one route narration queue. Location events enqueue fragment IDs; the audio adapter receives one resolved narration asset at a time. The coordinator persists queue identity and playback completion but not high-frequency position updates.

Required behavior:

- route narration never overlaps itself;
- calls and higher-priority system audio pause or duck using platform convention;
- headset disconnect pauses before speaker fallback;
- lock-screen controls expose play/pause/seek/replay;
- a transcript is always available;
- stale field prompts ask whether to play now or save for later;
- prepared audio is preferred over streaming.

The implementation should place `just_audio`/`audio_service`-style packages behind `NarrationPlayer` and `AudioSessionCoordinator` ports, and verify maintained compatible versions during apply. Direct plugin calls from Riverpod widgets are prohibited.

Runtime text-to-speech was rejected. Narration is a versioned backend-hosted audio asset produced from the reviewed script, with the transcript as the canonical text. A temporary preview voice may be pre-generated for MVP review but must share the same script version and remain labeled until audio review.

### 6. Persist a local tour snapshot and idempotent outbox

SQLite-backed local storage holds:

- guest token metadata;
- prepared route manifest and asset versions;
- active-tour state;
- journey fragment snapshot;
- narration queue identities;
- pending trigger/playback/collection/reconstruction events;
- pending evidence file references and upload state.

Every mutating event carries a UUID idempotency key. The backend stores or derives a uniqueness constraint per guest journey and event type. On reconnect, the client submits outbox events in causal order and then replaces its acknowledged snapshot with server state.

Alternative rejected: keeping Riverpod state only in memory. It cannot support locked-screen process death, offline uploads, or reliable resume.

### 7. Keep traveler evidence private and storage-agnostic

`EvidenceStorage` exposes put, open, and delete operations. The first deployment uses a Docker volume mounted outside the existing public media root. Object keys are random and never derived from user filenames. The API streams evidence only after journey ownership checks.

Before durable storage, the backend validates a decoded JPEG/PNG/WebP, enforces configured byte and dimension limits, normalizes orientation, strips EXIF where possible, and writes atomically. Database commit occurs only after storage succeeds. Default planning values are 10 MB per image, 4,096 pixels maximum edge after normalization, and 30-day guest evidence retention; all are deployment configuration.

No public gallery or semantic correctness score is created. The photo proves that the traveler performed an observation task, not that a historical interpretation is objectively true.

### 8. Add versioned API contracts

Existing route and journey endpoints remain available for legacy clients. New fields are additive where possible; new interactions use fragment endpoints:

```text
GET    /api/v1/routes/{route_slug}
POST   /api/v1/journeys
GET    /api/v1/journeys/{journey_id}
POST   /api/v1/journeys/{journey_id}/active-tour
DELETE /api/v1/journeys/{journey_id}/active-tour
POST   /api/v1/journeys/{journey_id}/fragments/{fragment_id}/triggers
POST   /api/v1/journeys/{journey_id}/fragments/{fragment_id}/playback
POST   /api/v1/journeys/{journey_id}/fragments/{fragment_id}/evidence
GET    /api/v1/journeys/{journey_id}/evidence/{evidence_id}
DELETE /api/v1/journeys/{journey_id}/evidence/{evidence_id}
GET    /api/v1/journeys/{journey_id}/ledger
POST   /api/v1/journeys/{journey_id}/reconstruction
GET    /api/v1/journeys/{journey_id}/recap
```

Trigger request:

```json
{
  "method": "location",
  "latitude": 22.5381,
  "longitude": 113.9227,
  "accuracy_m": 18.0,
  "occurred_at": "2026-08-22T10:20:00Z",
  "idempotency_key": "uuid"
}
```

The response returns journey-fragment state and authorized reveal content. Locked narration and exact historical claims are not sent in the unauthenticated route preview. Evidence uses multipart form data with `idempotency_key` and `captured_at` fields. Error codes include `fragment_locked`, `trigger_too_far`, `location_accuracy_insufficient`, `demo_trigger_disabled`, `evidence_invalid`, `evidence_too_large`, `evidence_storage_unavailable`, and `reconstruction_incomplete`.

### 9. Use additive relational models and preserve legacy stops

New records:

- `historical_sources`: title, publisher, URL/archive reference, publication/access dates, source type, review state.
- `historical_claims`: canonical claim text, claim kind, certainty, review state, supersession link.
- `claim_sources`: claim/source relationship and supporting note.
- `story_arcs`: route, central question, complete story, causal model JSON, script version, review state.
- `story_fragments`: arc, optional legacy stop, position, title, safe preview, narration script/transcript, audio asset, interaction type, completion threshold, review state.
- `fragment_claims` and `fragment_dependencies`.
- `trigger_regions`: fragment coordinates and trigger policy.
- `photo_missions`: fragment prompt, field subject, safety copy, accessibility alternative, required flag.
- `journey_fragments`: timestamps and state for trigger, playback, mission, collection, plus trigger method.
- `evidence`: guest journey, mission, private object key, MIME, size, hash, captured/uploaded times, deletion time.
- `reconstructions`: journey, submitted model, result, attempt count, completion time.
- `idempotency_records`: scoped mutation identity and stable response reference where an existing uniqueness constraint is insufficient.

Existing `stops`, `challenges`, `answers`, and completed journeys remain readable. The new Shenzhen route version links fragments to stops for spatial compatibility but does not require challenge rows.

### 10. Treat content production as a release gate

The content workflow is:

1. build a source dossier and timeline;
2. split the timeline into atomic claims;
3. map every claim to sources and confidence;
4. conduct an on-site field audit for coordinates, safe listening positions, visible subjects, and original/reconstructed status;
5. write the central question, fragment dependency graph, scripts, mission prompts, and complete story;
6. review each claim and the whole causal arc;
7. record and review audio against the exact transcript and pronunciation guide;
8. seed/import as `in_review`, validate all assets, then explicitly publish.

Seed insertion is not publication approval. The API refuses production-ready state when required source, transcript, audio, field-authenticity, or review data is missing.

### 11. Nantou historical narrative blueprint

#### Source dossier

The initial source set is intentionally weighted toward government and museum material:

- Shenzhen Nanshan District Government, “建置沿革”: https://www.szns.gov.cn/mlns/nsgk/content/post_12563286.html
- Nanshan District Culture, Radio, Television, Tourism and Sports Bureau, “南头古城垣”: https://www.szns.gov.cn/mlns/whns/wwbhdw/content/post_12573705.html
- Shenzhen Government Online, “南头古城博物馆”: https://www.sz.gov.cn/szzt2010/szwtt/wtcg/whcg/content/post_11132704.html
- Shenzhen Culture, Radio, Television, Tourism and Sports Bureau, “南头古城 深圳首个国家级旅游休闲街区”: https://wtl.sz.gov.cn/lyfw/lyxw/content/post_10984289.html

These support the initial timeline below. They do not yet settle every field-authenticity question. In particular, the present county-office exhibition must be audited and sourced before narration describes any visible component as original, reconstructed, relocated, or interpretive.

#### Central question and causal model

Working title: **《迁移的中心：南头如何成为深圳，又如何失去深圳》**

Central question: **为什么深圳的城市史从南头讲起，而今天的深圳中心却不在南头？**

Authored causal chain:

```text
331 administrative establishment around Nantou
  -> 757 county seat moves and the center changes
  -> 1394 Ming garrison city gives the visible walls a later military form
  -> 1573 Xin'an County returns administrative centrality to Nantou
  -> Kangxi coastal evacuation temporarily removes people and county government
  -> restoration resumes the county, but centrality remains historically contingent
  -> 1914 rename to Bao'an and 1953 county-seat move to Shenzhen Town
  -> 1979/1980 modern Shenzhen redefines the regional center
  -> contemporary micro-renewal makes Nantou a place where the new city reads its older layers
```

The final interpretation is not “Nantou never changed.” It is: **Nantou matters because multiple systems repeatedly made, removed, restored, and reinterpreted it as a center.**

#### Five-fragment draft

All scripts below are research drafts, not reviewed publication copy.

**Fragment 1 — 两个年份，一道城门**

- Trigger: safe approach to South Gate.
- Photo mission: frame the “宁南” stone inscription together with enough of the gate to show its physical placement.
- Knowledge payload: 331 marks the establishment of Dongguan Commandery and Bao'an County administration around Nantou; 1394 marks construction of the surviving Ming-period garrison-city wall described by the official record. The visible gate must not be called a 331 original.
- Draft narration:

  > 很多介绍把南头称为“有一千七百年历史的古城”。但请看清眼前这道门：三百三十一年，指的是东官郡治和宝安县治设在南头一带；一三九四年，才是官方资料记载的现存南头城垣始建年代。行政建置的年龄，不等于眼前砖石的年龄。抬头寻找“宁南”两个字，把石匾和门洞一起拍下来。你收集的第一条线索是：一座城，可以同时拥有不止一个起点。接下来要问的是——如果南头已经成为中心，为什么中心后来又离开了？

**Fragment 2 — 中心离开之后，城为什么还在**

- Trigger: county-office exhibition approach or another field-audited quiet listening point.
- Interaction: audio-first; photo remains optional until field authenticity is verified.
- Knowledge payload: in 757 the Bao'an county seat moved from Nantou to today's Dongguan area; in 1394 the Dongguan defensive thousand-household garrison city was built at Nantou. Administrative loss and military/coastal function are distinct layers.
- Draft narration:

  > 唐至德二年，宝安县治从南头迁往今天的东莞一带。南头失去了县治，却没有从地图上消失。数百年后的一三九四年，明朝在这里修筑东莞守御千户所城。你刚才看到的城门，首先属于这一层海防与守御的历史。中心离开之后，地点仍可能因为海岸、航路和军事位置而重要。第二条线索是：同一座城的功能可以更换，而旧身份不会自动消失。现在的问题变成了——一个军事所城，后来为什么又成了县城？

**Fragment 3 — “新安”不是景点名，而是一套治理**

- Trigger: field-audited county-office/administrative-space region.
- Photo mission: only after audit, photograph an official exhibit label or spatial element that truthfully communicates administration; the prompt must state whether the visible object is reconstructed or interpretive.
- Knowledge payload: in 1573 Xin'an County was separated from Dongguan County and its seat established at Nantou. The meaning is jurisdiction and administration, not merely an architectural label.
- Draft narration:

  > 一五七三年，东莞县析置新安县，县治设在南头。这里重新成为行政中心。“新安”不是后来包装出来的古城名称，它意味着县的建置、辖境和日常治理重新落在这里。县城里的门、街道和衙署不是孤立景点，而是一套让命令、诉求和资源流动起来的空间。第三条线索是：所谓中心，不只是一栋重要建筑，而是许多事务都必须经过这里。可一纸行政命令既能建立中心，也能让它突然停止。

**Fragment 4 — 地图上的三年，居民的一次断裂**

- Trigger: Baode Square or another safe pause point; no required photo because no visible object has yet been verified as direct evidence of the coastal evacuation.
- Interaction: passive narration plus an optional spoken reflection saved locally.
- Knowledge payload: Nanshan's official chronology records that during Kangxi years five through seven coastal residents were moved inland 50 li, later 80 li; Xin'an County was abolished and merged into Dongguan, then restored in Kangxi year eight.
- Draft narration:

  > 清康熙五年至七年，迁界令把沿海居民向内迁移，距离先是五十里，后来扩大到八十里。新安县一度被裁撤并入东莞，康熙八年才恢复。行政沿革里只是“裁撤”和“复置”几个字，对居民却意味着住房、土地、交易和邻里关系被迫中断。你所在的广场不是迁界遗址，不能拿眼前一堵旧墙冒充证据。第四条线索因此看不见：历史有时留下建筑，有时只留下制度造成的空白。恢复县治，也不代表南头从此永远是中心。

**Fragment 5 — 当深圳离开南头，又回来寻找南头**

- Trigger: North Street exit or a field-audited point where old street fabric and modern city can be framed safely.
- Photo mission: make one frame containing an older spatial/material layer and a clearly contemporary use; label it as evidence of coexistence, not proof of a specific ancient event.
- Knowledge payload: Xin'an was renamed Bao'an in 1914; the Bao'an county seat moved from Nantou to Shenzhen Town in 1953; Bao'an became Shenzhen City in 1979 and the Special Economic Zone was established in 1980; contemporary micro-renewal reinterprets Nantou within the modern metropolis.
- Draft narration:

  > 一九一四年，新安县更名为宝安县。到一九五三年，宝安县治从南头迁往深圳镇。南头没有失去历史，却再次失去了行政中心的位置。此后二十多年，宝安县改为深圳市，经济特区建立，新的城市规模远远越过旧城墙。今天，南头通过微更新保留街巷肌理，又加入展览、商业和新的生活方式。请拍下一处新旧用途同框的地方。最后一条线索是：深圳并不是简单从南头长成今天的样子；城市中心一次次迁移，而现代深圳又回到南头寻找自己的时间深度。

#### Reconstruction and complete-story draft

The reconstruction asks the traveler to connect five relationships rather than merely sort dates:

1. `行政建置早于现存城垣`;
2. `县治迁走，不等于地点失去所有功能`;
3. `军事所城后来承载新安县治`;
4. `国家政策可以让行政中心和居民生活同时中断`;
5. `现代中心迁走后，旧城被重新赋予历史与文化角色`.

Successful reconstruction unlocks this research-draft conclusion:

> 南头的故事不是一座古城如何完整保存了一千七百年，而是同一个地点如何被不同制度反复使用。三百三十一年的南头，是郡县行政的起点；一三九四年的南头，是明代沿海守御体系中的所城；一五七三年以后，它又成为新安县治。迁界曾让县的建置和居民生活一度中断，复置之后它继续作为县城，直到一九五三年县治迁往深圳镇。现代深圳的中心离开了南头，却又在城市更新中回来解释南头。你拍到的城门、新旧街巷和当代用途，并不能单独证明全部历史；它们是入口。真正被拼起来的，是行政、军事、人口与城市发展如何一次次改变“中心”的含义。

### 12. Failure behavior is designed, not incidental

- Location denial: allow route preview and prepared manual listening; do not present it as automatic tour completion.
- Background suspension: persist last acknowledged sample time and show limited/paused status on resume.
- GPS drift: require stable samples; never mark a production fragment collected solely from one inaccurate point.
- Audio failure: preserve trigger, provide transcript, and retry asset independently.
- Process death: restore from SQLite and server snapshot; never auto-play until audio/session state is safe.
- Evidence upload/storage failure: retain pending local evidence, return structured recoverable error, and do not collect prematurely.
- Source or asset validation failure: keep route in review/demo state and leave the existing legacy featured route available.
- Server/client version mismatch: unknown interaction types remain visible as unsupported rather than being interpreted as passive completion.

## Risks / Trade-offs

- **[Background location is platform-sensitive and may be killed despite correct implementation]** → Use an explicit tour lifecycle, Android foreground service, platform purpose strings, last-sample freshness detection, prepared manual playback, and device-level field tests.
- **[GPS regions in dense streets can trigger early, late, or in the wrong order]** → Field-calibrate each radius, require accuracy and consecutive samples, use hysteresis, and author spoiler-safe dependency hints.
- **[Automatic audio may create safety or social problems]** → Pause on headset disconnect, never force immediate photo use, keep prompts short, and make pause/stop available from system controls.
- **[Photo missions can feel like ordinary check-ins]** → Require every mission to connect a concrete visible subject to a claim and reject missions whose subject is merely decorative or unverifiable.
- **[Fragments can be individually true but collectively imply false causality]** → Store an explicit causal model and require whole-arc editorial review before publication.
- **[The historical draft still contains unverified field relationships]** → Keep it in review, conduct an on-site authenticity audit, and do not promote current exhibit structures as original without evidence.
- **[Private photo storage increases security and operational burden]** → Separate storage roots, authorize every read, strip EXIF, configure limits/retention, and keep an object-storage migration port.
- **[Offline event reconciliation is more complex than the current linear journey]** → Use append-only idempotent events plus a replaceable server snapshot, and test crashes at every state transition.
- **[Background features increase battery use]** → Monitor only during active tours, use balanced location settings between regions, stop promptly, and expose battery guidance.

## Migration Plan

1. Add database tables and storage configuration additively; do not remove legacy stop/challenge columns.
2. Add source, fragment, evidence, and reconstruction domain/application modules plus API endpoints behind `ENABLE_FRAGMENT_AUDIO_TOURS`.
3. Add private evidence volume and health checks; deploy with uploads disabled until authorization and storage tests pass.
4. Add Flutter persistence, adapters, permissions, and active-tour state behind a route capability flag so old routes continue using the legacy journey UI.
5. Import the Shenzhen research draft as `in_review`; add preview narration and field-audit checklist without changing the featured production route.
6. Conduct device field tests with screen locked, headphones connected, poor GPS, offline mode, calls, process death, and photo retries.
7. Complete historical and physical-authenticity review, replace preview audio if needed, then publish the new route version and switch Shenzhen discovery to it.
8. Keep the previous Shenzhen route version readable for existing journeys. Rollback disables the feature flag and restores the prior featured route; new tables and private evidence remain intact for later recovery.

## Open Questions

- Select the final Mandarin narrator and whether the review build uses a local synthesized preview voice or an initial human recording; this changes assets, not contracts or module boundaries.
- Confirm field-calibrated coordinates, radii, quiet listening positions, and photo subjects during the required on-site audit.
- Confirm the production evidence-retention period and whether users should be offered an immediate “keep only on this device” mode after the server-backed MVP is evaluated.
