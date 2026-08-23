## Context

See [proposal.md](./proposal.md). The current client treats a journey collection item as a footprint and opens `JourneyContext`, ledger entries, evidence, replay controls and node community together. Temporary evidence belongs to a photo mission and has a retention policy; it is not a safe long-term store for the new personal keepsake. Story content already carries city/route/fragment identity, arbitrary experience tags, reviewed narrative fields and private owner-scoped journeys, while requirement three now preserves active partial journeys.

The change crosses the Flask modular monolith, Flutter client, MySQL schema, object storage and independent admin/import repository. The observable contracts are defined in `specs/traveler-footprints`, `specs/guided-journey` and `specs/route-discovery`.

## Goals / Non-Goals

**Goals:**

- Make a footprint a stable semantic record keyed to one triggered story point, not a view over mutable playback state.
- Keep official content, user observation and user interpretation structurally distinct and independently editable.
- Support durable owner-private photos, server-driven summary choices, filtering, partial-journey continuation and local share-card export.
- Preserve existing journeys and photos through idempotent migration while keeping deployment and rollback safe.
- Keep API/application/infrastructure/presentation boundaries testable in the current modular monolith.

**Non-Goals:**

- Do not change trigger radii, nearby ordering, audio ownership, causal reconstruction, city auto-selection or route recommendation.
- Do not create a public footprint feed, publish directly to community, upload generated share cards, retain GPS trails or build a long-form diary editor.
- Do not let the footprint feature import the active narration controller or depend on narration DTOs.

## Decisions

### 1. Use a dedicated footprint aggregate and API

Add a footprint application service and persistence aggregate rather than extending `JourneyLibraryItem` or returning `JourneyContext` from footprint routes. The public/private API surface is additive:

- `GET /api/v1/footprints` with cursor plus optional `city_slug`, arbitrary `theme`, time range/order and organization/journey-state filters;
- `GET /api/v1/footprints/resume-candidate` for the home card;
- `GET /api/v1/footprints/<id>` and `PATCH /api/v1/footprints/<id>` for one owner record;
- `POST`, `GET` and `DELETE /api/v1/footprints/<id>/photo` for the single durable private photo;
- `GET /api/v1/footprints/<id>/related-content` for published city-story summaries.

List/detail DTOs include semantic snapshot fields, organization state, privacy state and a minimal journey-resume reference. They explicitly exclude audio, transcript playback progress, narration profile/provider/version and raw object-storage references. Owner mismatch uses the existing privacy-safe not-found behavior. Idempotency keys protect create/backfill, patch retry and photo replacement.

Alternative considered: keep using `/journeys`, ledger and evidence APIs. Rejected because it cannot enforce the no-playback contract, makes filters expensive and couples a historical record to mutable route/audio content.

### 2. Snapshot semantic content at first reveal

Introduce `footprint_entries` with a UUID, owner, journey and stable source identity plus snapshot columns for city ID/slug/name, scene ID/name, story ID/title, reviewed editorial summary, available short-summary choices, themes, source content revision, trigger/creation/update time, chosen summary text/ID, observation, personal sentence and `draft|organized` state. A unique source key covers `(user_id, journey_id, source_kind, source_id)`.

The chosen summary is validated against the snapshot choices and both its stable choice ID and text are saved so later content editing does not corrupt the historical display. User text has Unicode-aware short limits defined by the API and advertised in its policy response. Blank values are valid and explicit clearing is supported.

Story fragments gain admin-authored `footprint_editorial_summary` and structured `footprint_summary_options`; arbitrary footprint themes reuse normalized experience tags unless explicitly configured. Legacy published content falls back on the server to existing reviewed `key_claim`, safe preview or stop insight, in that order. The client never creates copy or enumerates tags.

Alternative considered: always join current story tables on read. Rejected because archived/edited content and voice-driven script changes would rewrite history or make it unavailable.

### 3. Reconcile drafts from authoritative progress without blocking travel

The normal trigger transaction calls an idempotent footprint upsert after owner, membership and trigger eligibility succeed. The stable journey-fragment ledger remains authoritative. If an offline or rolling-deployment seam produces a revealed point without a footprint, footprint list/detail/home queries and a deployment backfill job reconcile the missing draft from the ledger without sending another trigger or changing timestamps.

Footprint PATCH/photo failures do not mutate the ledger. Flutter may surface a compact post-trigger invitation, but dismissing it or choosing “稍后再整理” only changes footprint organization state and never pauses location/audio or inserts a journey gate.

Alternative considered: require footprint creation before returning trigger success. Rejected because a secondary personal-record failure must not strand a traveler at a location.

### 4. Store long-lived footprint photos separately from temporary evidence

Add `footprint_photos` with a unique footprint relation, owner-derived authorization, object key, MIME type, size, dimensions/checksum, created/updated/deleted time and photo idempotency metadata. Store objects under a distinct private prefix. They are deleted only by explicit owner/account lifecycle or storage policy changes, not the field-evidence retention worker.

Replacing a photo stages the new object, commits metadata atomically, then best-effort deletes the previous object. A failed database transaction deletes the staged object. Responses expose only an authenticated footprint-photo endpoint. Existing evidence may be copied once into the new private namespace during backfill; the original evidence remains under its existing lifecycle until normal cleanup.

Alternative considered: reference `EvidenceModel` directly. Rejected because its mission requirement, expiry and deletion semantics conflict with a durable optional memory.

### 5. Separate Flutter footprint state from narration and community

Create footprint-specific domain DTOs, repository methods and Riverpod controllers for list filters, detail, editor, photo and related content. `FootprintsPage` becomes record-led cards; `FootprintDetailPage` renders the three semantic sections and an optional, visually secondary journey-resume action. Neither imports `ActiveTourController`, narration players, voice selectors nor `NodeCommunitySection`.

The existing `/journey/<id>` page remains the only place for formal journey narration/replay. The existing explicit community composer remains attached to journey node context; footprint detail no longer embeds it. This removal is intentional to satisfy the private memory surface, while a user may still navigate to the journey and use the separate explicit community flow.

Known entries remain on screen when refresh, photo or recommendation calls fail. Provider keys include the current user and filter values, and account exit invalidates every footprint/photo cache to prevent cross-account stale rendering.

### 6. Treat partial journey status as a link, not footprint content

Footprint DTOs may contain `journey_id`, `journey_status` and `can_resume_journey`; they do not contain collected/total counts or a current audio node. The list can filter incomplete journeys, but cards still lead with city, story, summary, themes and time. Resume loads the existing owner journey context and enters `/journey/<id>`; failure affects only that action.

Alternative considered: keep one route-level footprint with counts. Rejected because the requirement defines one record per triggered story and asks that conceptual/personal content replace route statistics.

### 7. Reuse published city-story relationships for related reading

The footprint service queries the existing published city-story catalog by exact city first and overlapping arbitrary themes second, excludes unpublished content and the source story when applicable, and returns a bounded server order. No new client recommendation algorithm, city geometry or hard-coded mapping is introduced.

### 8. Generate share cards locally behind two explicit choices

Flutter renders a fixed, accessible footprint-card composition to PNG in application cache and opens the platform share sheet through a maintained native sharing dependency. Text-only is the default. Enabling the private photo opens a confirmation that states the generated copy can leave 见地; only after confirmation are authenticated photo bytes drawn into that export. Temporary files use per-user/random names and are removed on cancellation, success where observable, account exit and cache maintenance.

Generating or sharing a card calls no public-content API and never invokes the community composer. The card includes only the fields visible in its preview; it omits account identifiers, storage paths, journey IDs, location coordinates and unselected private text.

Alternative considered: server-rendered cards. Rejected for MVP because it would upload export choices, create another private media lifecycle and make offline sharing impossible.

### 9. Extend the independent admin and importer through the shared content graph

The admin story-point editor and JSON package schema expose footprint editorial summary, stable summary-option IDs/text and arbitrary themes. Validation requires concise non-empty reviewed copy for new/edited content, unique option IDs, bounded lengths and no audio/provider references. Import preview, deduplication, draft/review/approval/publish and manual editing use the same fields. Existing published content remains valid through the backend fallback until republished with explicit footprint copy.

Main API and admin repositories receive separate commits and deployments. No city names, story labels or summary choices enter Flutter source.

## Risks / Trade-offs

- **[Snapshot content can preserve a later-corrected factual statement]** → retain source revision and support an explicit audited editorial-correction job that can update only the official snapshot fields; never overwrite user observation, sentence or photo implicitly.
- **[Trigger and footprint upsert can diverge during rolling deployment]** → use unique source keys plus lazy and batch reconciliation from the authoritative ledger; test both API orders.
- **[Copying legacy evidence doubles private storage temporarily]** → copy only one selected/current non-expired image per source, checksum deduplicate, measure migration volume and let the old retention worker clean its own namespace.
- **[Filter cardinality and list queries grow]** → index owner/time, owner/city/time, journey/source uniqueness and use cursor pagination; themes remain JSON initially only if MySQL query plans are acceptable, otherwise add a normalized owner-footprint-theme join in the same migration.
- **[A local share card can leave app privacy controls]** → default to no photo, preview exact contents, require photo-specific confirmation, rely on the platform share sheet and avoid claiming revocation after export.
- **[Removing replay/community from footprint detail changes established navigation]** → preserve journey resume/revisit as an explicit navigation out of the footprint surface and add regression tests that footprint widgets instantiate no player or community request.
- **[Four summary/stat columns and route-led legacy UI may linger]** → replace rather than append to the current footprint pages and use golden/semantics tests at small text-scaled viewports.

## Migration Plan

1. Add nullable story footprint-copy fields, `footprint_entries`, durable `footprint_photos`, ownership/uniqueness/index constraints and object-storage configuration. Migration creates no public URLs and does not delete evidence or journey rows.
2. Deploy the main API with additive footprint endpoints, old-content fallback and dual reconciliation. Old clients continue using journey/evidence endpoints unchanged.
3. Deploy the independent admin editor/import validation and publish reviewed footprint copy for new content. Existing routes remain readable through server fallback.
4. Run an idempotent, resumable batch backfill for revealed fragmented points and completed legacy stops; record counts and failures, retry safely, and verify cross-owner isolation and photo checksums.
5. Release Flutter after API readiness. Migrate navigation to footprint-specific endpoints, enable home resume, filters/editor/photo and local share cards, and invalidate caches on account changes.
6. Observe API error rates, backfill completeness, orphan-object counts and client runtime logs without recording private text, image bytes or filter values that identify a user's memories.

Rollback keeps new tables and private objects in place. The client can roll back independently because old journey APIs remain. The API can disable new footprint routes and reconciliation without deleting data; schema removal and object deletion require a later explicit retention-safe migration, never an emergency rollback.

## Open Questions

- Exact short-field limits and final share-card typography may be tuned during UI implementation within the bounded short-form and privacy contracts; this does not change the aggregate, APIs or acceptance behavior.
