## Context

See `proposal.md` for motivation. The main Flask application already has normalized models for story arcs, fragments, dependencies, trigger regions, photo missions, historical claims/sources, media and journey reconstruction. The independent `DeepTravel-admin` service currently connects to the same MySQL database but exposes only the older city/route/stop/challenge/media model. Its UI cannot author a fragmented route, validate a graph or publish one atomically.

Flutter already renders route and fragment data from the public API, except its reconstruction bottom sheet contains five Nantou relationship strings in source code. Incorrect reconstruction currently invokes the page `ScaffoldMessenger` while a modal bottom sheet is above it, so the snackbar is painted below the modal barrier and is effectively hidden.

Dameisha also introduces open-coast location constraints and map-datum risk. Public Chinese map POIs may be GCJ-02, while the mobile location adapter emits WGS-84. All candidate coordinates remain `in_review` until field samples are recorded.

## Goals / Non-Goals

**Goals:**

- Make the complete fragmented-tour model operable through the independent admin, using Dameisha as the first generic published package.
- Keep one authoritative normalized content model in the main MySQL database; the admin writes it and the Flask public API reads it.
- Guarantee that incomplete drafts are never visible and publication either succeeds for the full graph or changes nothing.
- Remove route-specific reconstruction content from Flutter and keep mismatch feedback visible above modal UI.
- Preserve all existing Nantou, Shanghai and in-progress journey behavior.
- Make a real Android field pass sufficient to correct Dameisha trigger centers through admin configuration rather than a code change.

**Non-Goals:**

- Introduce a second content database, distributed CMS, multi-user roles or collaborative editing.
- Support structural in-place edits to published routes already referenced by journeys. The MVP locks them; immutable publication revisions can be added behind the same contract later.
- Generate final editorial voice performances or declare field-dependent statements publication-reviewed.
- Add turn-by-turn navigation, weather/tide services or new mobile permissions.

## Decisions

### 1. The independent admin is the write boundary; Flask remains the public read boundary

The content flow is:

`Admin Web → authenticated Admin API → shared MySQL draft graph → validate/publish transaction → Flask public API → Flutter`

The FastAPI admin service will extend its borrowed SQLAlchemy mapping to the fragmented-content tables already owned by the main backend. It may create only explicitly owned management metadata through a main-backend migration; it must not call broad `create_all()` against borrowed product tables. The Flask API remains read-only for editorial management and does not expose the admin bearer token.

This reuses the deployed architecture and avoids copying content between services. Moving authoring to a separate CMS later remains possible because publish is one explicit application boundary rather than scattered CRUD side effects.

### 2. Draft editing uses normalized rows; publication is an explicit state transition

Routes with `content_status` `draft` or `review` and `published_at = null` remain invisible to public repositories. Operators may edit their whole normalized graph. The admin API adds route-scoped endpoints:

- `GET /api/admin/routes/{route_id}/content` returns the complete editable graph.
- `PUT /api/admin/routes/{route_id}/content` replaces that draft graph transactionally using stable package identifiers.
- `POST /api/admin/routes/{route_id}/validate` returns `{valid, errors[], warnings[]}` with paths such as `fragments[2].trigger_region.entry_radius_m`.
- `POST /api/admin/routes/{route_id}/publish` reruns validation under the same transaction and sets route publication fields only when no errors remain.

The package import endpoint accepts the same graph schema and a `package_id` plus `package_version`; repeated imports of the same pair are idempotent. This becomes the automation path for researched route bundles such as Dameisha, while the UI edits the same data.

Once any journey references a published route, structural mutation or unpublish requests return `409 published_route_locked`. Media deletion also fails when a published graph references the asset. This is stricter than silently changing a user's story mid-journey and creates a clean seam for future immutable revision support.

Legacy seed reconciliation remains only for bootstrapping existing catalog records. It must ignore admin-owned package identifiers and never overwrite a route marked as management-published.

### 3. The admin edits one route as a coherent workspace

The existing route editor gains a “碎片导览” workspace with sections for:

1. Route metadata and media.
2. Story arc, central question, complete story, script version and review states.
3. Ordered fragments with narration/transcript, audio, questions raised/answered and interaction type.
4. WGS-84 triggers with entry/exit radii, sampling policy, source datum, coordinate provenance and field audit state.
5. Optional photo missions and safety/accessibility alternatives.
6. Historical sources, claims and fragment-to-claim support links.
7. A draggable causal-order builder using stable reconstruction item IDs.
8. Validation summary and publish action.

Individual sections can autosave or save explicitly as a draft, but only whole-route validation controls publication. JSON import/export uses the same schema so bulk researched content and UI-authored content cannot diverge.

### 4. Publish validation lives in a framework-neutral content service

Validation rules are implemented as pure Python against a route content graph and reused by the admin API, import command and tests. They cover:

- Required and unique identifiers, contiguous positions and a single story arc.
- A directed acyclic dependency graph whose prerequisites precede dependents.
- One trigger per fragment, valid WGS-84 ranges, positive thresholds, exit-radius hysteresis and non-overlap plus a 30 metre adjacent safety margin.
- Existing image/audio assets with expected MIME families and narration script versions matching fragments.
- Every substantive fragment claim linked through at least one support record to a source.
- Complete mission safety copy and exactly the configured required mission count.
- Unique reconstruction item IDs/text, the same item count as fragments, and a causal order containing each ID once.

Warnings, such as `in_review` coordinates or preview narration, do not block field-test publication but remain visible in admin and public review metadata. Errors block publication. The validator never trusts client-side form checks.

### 5. Reconstruction uses stable item IDs supplied by the ledger

The story arc stores reconstruction entries as objects `{id, text}` in causal order. Existing legacy string lists are normalized at read time to deterministic IDs so Nantou remains compatible without rewriting old journeys.

When reconstruction unlocks, the ledger includes `reconstruction_items` in a deterministic journey-specific shuffle. Flutter displays and submits item IDs; text is presentation only. The reconstruction endpoint compares IDs and returns mismatch entries containing only one-based positions and submitted IDs. It does not return expected text or the correct order.

This replaces the current Flutter-authored Nantou list and allows every future configured route to use the same screen. The demo repository used by tests must also source its options from fixture data rather than product constants.

### 6. Incorrect reconstruction uses the root overlay and local row state

After a wrong submission, the bottom-sheet state records the returned mismatch positions and rebuilds affected cards with an error outline/icon. A dedicated presentation helper inserts a top-aligned material notification into `Overlay.of(pageContext, rootOverlay: true)` (or an equivalent root navigator overlay), above the modal route, with `Semantics(liveRegion: true)` and text `还有 N 处关系没有接上`.

The notification is tap-dismissible, auto-dismisses after a short readable interval, replaces any previous mismatch notification, and removes its overlay entry when the page or sheet is disposed. It must not use the page `ScaffoldMessenger`, because that messenger is below `showModalBottomSheet` in the navigator overlay stack.

Correct submission closes the puzzle and opens the configured recap. Network/server failures use a separate root-level failure message and retain the current item order.

### 7. Dameisha content remains one causal route

Working title: **《被打开的海湾：大梅沙如何成为一座城市的公共海岸》**.

| Order | Fragment | Knowledge carried forward | Field observation |
|---|---|---|---|
| 1 | 梅沙不是梅花的沙 | The village and the names 大梅沙/小梅沙 predate the tourist park; the fine-sand explanation is explicitly interpretive | Old-village public lane or mature banyan context |
| 2 | 一条隧道把海湾拉进城市 | The 1987 Wutong Mountain tunnel and the 2023 metro changed practical access | Metro-to-park pedestrian connection |
| 3 | 免费海滩是一种公共政策 | The 1999 opening was a municipal public-service decision | Public entrance/service space and coast together |
| 4 | 当三十二万人走进一片沙滩 | Peak attendance versus planned capacity exposes safety, ecology and traffic trade-offs | Access-management infrastructure without close identifiable faces |
| 5 | 风暴没有让海岸回到原样 | Mangkhut damage and 2019 reconstruction turned restoration into a resilience project | Rebuilt landscape detail on a paved western park segment |

Historical facts use first-party Shenzhen archival, government and transit sources. Name etymology remains `interpretive`; generated narration remains `preview`; visible-site relationships remain `interpretive_location` until field review. A present-day photo can prove only what is visible now, not a historical date or count.

### 8. WGS-84 candidates form a separated westbound route

GCJ-02 source points are converted before storage and retain original datum/source notes. Initial candidates are:

| Stop | WGS-84 candidate | Entry / exit | Field decision |
|---|---:|---:|---|
| Old-village public space | 22.600250, 114.304000 | 65 m / 100 m | Confirm safe public point and banyan relationship |
| Metro/public entrance | 22.596989, 114.303031 | 55 m / 90 m | Confirm outside exit flow on pedestrian paving |
| Central public-beach plaza | 22.594390, 114.303980 | 55 m / 90 m | Confirm landward of tide line |
| Western access viewpoint | 22.592855, 114.300787 | 55 m / 90 m | Confirm no vehicle lane or closure |
| Western rebuilt coastal park | 22.590907, 114.299492 | 55 m / 90 m | Confirm dry access and visible rebuild detail |

Entry requires two samples within 15 seconds, each at most 20 seconds old and no worse than 35 metres accuracy. Existing dependency enforcement prevents skipping. Field corrections are saved to an unlocked draft before publication; a referenced published route remains immutable.

### 9. Media is backend-owned configured content

The generated cover has no embedded text, logos or identifiable private individuals. Five Mandarin preview narrations are generated from exact configured transcripts and normalized to the existing player format. Files are uploaded through the admin media endpoint before the route graph references them. Flutter ships no Dameisha cover, transcript, audio or reconstruction constant.

### 10. Verification spans contracts, repositories and real devices

Backend tests exercise pure validation, transactional rollback, package idempotency, public visibility, published-route locks, asset references and generic reconstruction. Admin tests exercise complete graph forms/import, field-addressable errors and publish state. Flutter tests place the puzzle inside a modal sheet, submit an incorrect generic route order and assert that the root overlay is visible while mismatch rows are marked.

The field checklist records at least eight readings per stop over 60–90 seconds, reported accuracy, median coordinate, practical drift, trigger timing, access safety, false-entry checks and app background/re-entry behavior.

## Risks / Trade-offs

- [Direct shared-database administration couples schemas] → Keep one backend-owned migration chain, map only explicit tables in the admin service, and contract-test its mappings against backend metadata.
- [Editing a published graph can corrupt active journeys] → Lock structural mutation after the first journey; add immutable revision pinning later behind the same publish boundary.
- [A large route editor can save inconsistent intermediate states] → Treat all edits as private drafts and make server-side whole-graph validation the only publication gate.
- [GCJ-02 and WGS-84 can differ by hundreds of metres] → Convert explicitly, retain provenance and compare against raw device WGS-84 field samples.
- [Beach conditions and closures change] → Center triggers on public paving, permit mission deferral and retain field audit warnings.
- [An overlay can leak or stack after navigation] → Own one overlay entry per puzzle, replace it on each attempt and remove it on dispose and success.
- [Generated speech can mispronounce names] → Label it preview, retain transcripts and keep final voice production outside this change.

## Migration Plan

1. Add backend-owned schema metadata and generic graph validation/reconstruction contracts with backward-compatible legacy reads.
2. Extend the independent admin API mappings and tests, then deploy it while new UI controls remain unused.
3. Extend the admin web route workspace and verify draft/import/validate/publish against an isolated MySQL copy.
4. Generate/upload Dameisha media, import its versioned package, inspect validation warnings and publish through admin.
5. Deploy the Flask API and verify catalog, route, journey, ledger, real arrival, reconstruction and evidence endpoints.
6. Build the Android APK for `http://115.29.221.190:5001`, verify real mode and execute the field checklist.

Rollback first removes Dameisha from public discovery only if no journey references it; otherwise it stays available to those journeys while catalog featuring is disabled. Backend and admin binaries remain backward-compatible with legacy string causal models, so code rollback does not require deleting content rows.

## Open Questions

- The exact safe listening point nearest the old-village banyan and the best visible post-reconstruction detail will be finalized from the first on-site samples without changing the authoring, publication or client contracts.
