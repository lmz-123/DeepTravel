## Context

See `proposal.md` for motivation. The current Flask API owns users, journeys, fragment unlock state and private evidence. Flutter already has an account-scoped journey repository, a selected/replayable fragment, a global narration owner, an inline photo viewer, a completed footprint detail, route-wide narration profile preferences and a user-scoped location-mode setting. There is no community persistence, community-media lifecycle, moderation surface, or global social navigation. Voice selection and simulated-location switches are currently duplicated as full controls on route/journey surfaces, consuming space and creating more than one place to edit the same preference.

The main constraint is that community content is shared across travelers while access is still contextual: a traveler must prove ownership of a journey where that fragment is revealed. A second constraint is that private evidence is authenticated, user-scoped and retention-bound; it cannot become community media merely by returning its current URL. Community failure must remain subordinate to the official walking and audio loop.

## Goals / Non-Goals

**Goals:**

- Add a testable `node_community` module inside the Flask modular monolith with explicit application, persistence, storage and presentation seams.
- Keep every feed request anchored to an owned journey plus fragment so the API enforces the same unlock boundary as the UI.
- Reuse one Flutter community component in the selected-node journey view and selected-node footprint detail while isolating requests by account/journey/fragment/filter.
- Make community-media creation transactional from the user's point of view and independent from private evidence lifecycle.
- Ship behind runtime policy so backend and client can be deployed and rolled back independently.
- Keep journey controls compact by making the narration card the only in-journey voice entry and 设置 the only editable location-mode entry.

**Non-Goals:**

- No separate service, event bus, search index, ranking engine, WebSocket, push notification or offline write queue in this change.
- No changes to official content publication, fragment trigger rules, narration ownership or journey completion semantics.
- No `Travel-Admin` repository changes; held/report records are retained for operational inspection and a later moderation-console change.

## Decisions

### 1. Use journey-context endpoints for a globally fragment-scoped feed

The list/create entry point will be:

`GET|POST /api/v1/journeys/<journey_id>/fragments/<fragment_id>/community-posts`

The application service first applies the existing owner-not-found rule to `journey_id`, then requires the corresponding journey fragment to be revealed or collected. Posts themselves are keyed by `fragment_id`, so two eligible travelers see the same feed even though they authorize through different journey IDs. Archived routes remain readable only through an already-owned journey context.

Post actions use stable resource URLs (`/community-posts/<post_id>`, `/likes`, `/comments`, `/reports`). For every action, the service resolves the target fragment and requires that the acting user owns at least one revealed journey-fragment row for it. This prevents a copied post ID from bypassing unlock rules.

Alternative considered: a bare `/fragments/<id>/posts` endpoint guarded only in Flutter. Rejected because it leaks spoilers and post counts to direct API callers. Embedding `journey_id` in every interaction URL was also rejected because ownership can be derived server-side after the first feed and would make resource operations unnecessarily unstable.

### 2. Add normalized relational tables with soft state instead of storing a JSON feed

The additive migration creates:

- `community_posts`: UUID, fragment FK, author FK, category, optional bounded title, body, status (`visible`, `held`, `deleted`), author-scoped idempotency key, report count and timestamps; indexes cover fragment/status/created/id and author/idempotency.
- `community_media`: UUID, post FK, ordered position, storage provider/object key/canonical reference, MIME type, dimensions, size/checksum and source kind (`upload`, `evidence_copy`); no lifecycle FK to evidence.
- `community_post_likes`: unique `(post_id, user_id)` membership and timestamp.
- `community_comments`: UUID, post FK, author FK, body, status, author-scoped idempotency key, report count and timestamps. No parent column is exposed, enforcing one level.
- `community_reports`: UUID, reporter FK, target type/id, reason and timestamp with unique `(reporter_id, target_type, target_id)`.

Deletes set status and timestamps. Ordinary queries filter visible content and reporter-specific hidden targets. Database rows retain auditability; community media is scheduled for deletion only after post soft deletion and is never cascaded back to private evidence.

Alternative considered: generic polymorphic activity tables. Rejected for the MVP because they weaken foreign-key and query clarity before the product has other community target types.

### 3. Separate lightweight feed summaries from contextual post detail

The feed response contains `items` and `next_cursor`. Each item is deliberately a card summary: public author presentation (`display_name` and default-avatar token, never account kind, login identifier or raw private profile data), category, optional title, bounded body excerpt, cover or compact-grid media metadata, timestamps, aggregate like/comment counts, `viewer_has_liked`, and `viewer_is_author`. It does not embed complete liker or comment collections.

`GET /api/v1/community-posts/<post_id>` returns the full authorized post projection. `GET /api/v1/community-posts/<post_id>/likes` returns a keyset-paginated privacy-safe liker collection, and the existing comments resource returns keyset-paginated complete one-level comments. Target access always re-resolves the fragment and requires an owned revealed/collected journey fragment, so copying a detail URL does not bypass the feed gate. If the post becomes held, deleted or reporter-hidden, all three resources use the existing not-found behavior.

Posts order by `(created_at DESC, id DESC)`. The opaque signed/base64 cursor encodes last timestamp, ID, fragment and category; the server rejects a cursor reused with another scope. Page size defaults to 10 and is capped at 20. This keyset strategy is stable under concurrent inserts and cheaper than offset pagination.

Alternative considered: embedding liker identities and comment previews in every feed item. Rejected because the confirmed card design shows only counts and opens details on demand; embedding discussion data would increase every field request and complicate count consistency. Returning only IDs was also rejected because it creates an N+1 waterfall just to paint summary cards.

### 4. Separate community media from evidence and authorize its reads

A `CommunityMediaStorage` application boundary will reuse the configured object-store/local adapter for byte persistence but use a distinct `community/<fragment>/<post>/` namespace and policy. Uploads and evidence copies are decoded, type-checked, orientation-normalized, compressed to a bounded long edge, stripped of EXIF/GPS metadata, checksummed and stored as independent objects. The database retains dimensions so Flutter can lay out previews without probing images.

Objects are “community-visible”, not anonymous public assets. Local mode streams them through an authenticated community-media endpoint; OSS mode may return short-lived signed URLs after the same feed authorization. Flutter uses `BoxFit.cover` in near-square grids and the full normalized image in the existing zoom viewer, so visual consistency does not require destructive square cropping.

Evidence-copy requests include an owned `evidence_id`. The service verifies the evidence journey, mission/fragment match and current availability before reading bytes. A staging list tracks successfully stored objects; any database or later-media failure deletes staged objects before returning an error. The idempotency record prevents retry duplication.

Alternative considered: reuse the private evidence URL. Rejected because evidence URLs require a journey owner, may expire, and would either leak private access or break published posts.

### 5. Keep moderation minimal but enforceable without an admin UI

Runtime policy defines allowed categories, title/body/comment limits, maximum four images, accepted image MIME/types, report reasons and `COMMUNITY_AUTO_HOLD_REPORT_THRESHOLD`. Reports are unique per reporter and target. A report hides the target from that reporter immediately; reaching the threshold atomically moves it to `held`, excluding it for ordinary readers. Authors can soft-delete their own content. No client action can mark content official or verified.

This is deliberately a safety baseline, not a complete trust-and-safety console. Held content and reports remain queryable at the database/operational layer for the first controlled release. A later OpenSpec change can add authenticated moderation endpoints to `Travel-Admin` without changing post identity or feed contracts.

Alternative considered: publish with no report/hold mechanism. Rejected because even a node-sized community needs an immediate abuse-control path. Automatically deleting at a threshold was rejected because it is irreversible and vulnerable to coordinated false reports.

### 6. Add a dedicated mobile community slice, not community state inside the audio controller

Flutter adds immutable community models and repository methods alongside `ExperienceRepository`, plus Riverpod families keyed by `userId`, `journeyId`, `fragmentId` and `category`. Each feed controller owns first-page, append, refreshing and card-mutation states. Separate detail controllers are keyed by user and post ID and own full content, liker pages, comment pages and detail mutations. Switching node changes the feed key and closes any detail belonging to the previous node; request generation checks prevent a late response for fragment A from painting beneath fragment B. Account logout/switch invalidates all community providers and authenticated media caches.

`NodeCommunitySection` is a reusable bottom section containing the compact composer entry, category chips, summary cards and explicit load-more action. Media posts use a prominent near-square cover or compact grid with title/excerpt; text-only posts use a restrained paper-like typography card. The footer always carries like/comment counts. Tapping a card opens a near-full-height modal detail sheet containing the complete post, paginated liker presentations, paginated comments and actions. This is contextual presentation, not a registered community route, so dismissal restores the same feed offset and selected node. Tapping the composer opens a separate focused modal sheet. Image selection can use camera/gallery paths already available to the app; an evidence picker is supplied only in footprint context. Optimistic likes and deletions reconcile both card and detail projections; post/comment creation remains visibly pending and refreshes the affected projection after success.

Community state does not enter `ActiveTourController`. Scrolling, filtering, composing, commenting and media viewing therefore cannot stop or replace narration. The existing single audio owner remains authoritative.

Alternative considered: put feed loading in the journey controller. Rejected because it couples shared social content to location/audio lifecycle and makes footprint reuse and failure isolation difficult.

### 7. Place the section after all journey-critical UI and reuse it in footprint detail

On `JourneyPage`, the section is keyed from `selectedFragmentId` and rendered only when the selected ledger entry is revealed/collected. It appears after narration/transcript, missions/evidence, reconstruction or simulated-next controls, revisit controls and journey error presentation. Thus community is literally the final section and cannot interrupt the next-clue flow.

On `FootprintDetailPage`, collected clue cards become/select a current footprint fragment. Its recap and matching evidence gallery render first; the same section then renders at the bottom using the completed journey context. It never calls active-tour registration or location APIs.

No route, drawer destination, discovery badge, route-card badge or floating community affordance is added. Widget tests assert the drawer remains limited to 足迹/设置/退出登录 (plus existing test-only controls) and that 见地现场 is absent from discovery until a node page is opened.

### 8. Move voice selection into the narration transport without creating another player

The standalone `NarrationVoiceSelector` surfaces are removed from both route detail and `JourneyPage`. Its profile picker is refactored into a lightweight action opened by a compact icon in `_NarrationCard`, next to existing playback transport controls. The icon tooltip/semantics includes the current server-provided profile name; it is selectable only when multiple published profiles are available. A single profile produces no misleading picker action. Fallback/error copy appears as a short line inside the narration card rather than another card.

When a different profile is chosen, `ActiveTourController` captures the selected fragment, old duration, position fraction and playing/paused intent. It prepares the new server-provided track, advances the existing player generation so old callbacks are inert, stops the old track, loads the matching fragment track, seeks to the clamped proportional position in the new duration and resumes only if the old intent was playing. The preference is committed after the replacement is playable. Profile switching never calls playback acknowledgement and never changes the live fragment cursor. If preparation/load fails before replacement, the old track continues; if failure occurs after stop, the controller attempts to restore the old prepared track and exposes a recoverable inline error.

Alternative considered: apply the voice only on the next replay, matching current behavior. Rejected because placing the action in the live transport communicates an immediate listening change. A second preview player was rejected because it violates the single-owner audio invariant.

### 9. Make settings the only mutable location-mode surface

The switches are removed from `_AudioTourBrief` and `_StatusPanel`; those surfaces retain concise read-only mode copy. The simulated-only 下一条线索 control remains because it advances test content rather than choosing a mode. `_LocationModeTile` in 设置 remains the single user-scoped preference editor.

The active tour observes `locationModeControllerProvider`. A change is serialized through the existing monitoring transition logic: cancel obsolete real-location subscriptions first, update the active state and persistence, then either expose simulated progression or request/resume real permission and monitoring. Revisit/completed playback ignores location-mode transitions. To prevent a write/listen loop, the controller separates “persist user choice” from “apply an observed choice”; the settings controller writes once and the active tour only applies.

Alternative considered: remove only the journey switch while leaving the route-detail switch. Rejected because the user's reason is to eliminate duplicate settings, and leaving route detail mutable would still create two sources of truth.

### 10. Runtime policy and failure envelopes provide the deployment seam

`GET /api/v1/policies/community` returns enabled state, categories/labels, limits, report reasons and retention/privacy copy. `COMMUNITY_ENABLED` can disable list/create/interaction behavior after deployment without affecting journey APIs. The client hides the entire section when disabled; a feed-specific network error shows inline retry and never replaces the page-level journey state.

New endpoints use the existing JSON error envelope, owner-not-found semantics, authentication middleware and UTC timestamps. Multipart creation accepts optional `title`, `body`, `category`, `idempotency_key`, zero-to-four `photos`, and zero-to-four `evidence_ids`; the combined media count is capped. Database state is committed only after all media validates and stores successfully.

## Risks / Trade-offs

- [Report-threshold holds can be gamed] → Require distinct authenticated reporters, preserve rows, never physically delete, keep the threshold configurable, and defer irreversible action to future moderation tooling.
- [Community images increase storage and egress] → Normalize dimensions/quality, cap four images, checksum objects, retain size metadata, and clean only community copies after soft-deletion policy.
- [Signed image URLs can expire while a card is open] → Keep media identity separate from URL and allow the repository/viewer to refresh authorization once before showing a retry state.
- [Feed volume can eventually outgrow direct MySQL queries] → Use keyset pagination and indexed projections now; keep application interfaces independent so caching/search can be added later without changing mobile contracts.
- [An active route can be archived between page loads] → Authorization follows the owned journey context rather than public route status, matching existing footprint recovery behavior.
- [Publishing multiple media is not one storage transaction] → Stage object keys, compensate on failure, commit post/media metadata once, and run an orphan reconciliation test/tool for crash windows.
- [Community work can destabilize the tour UI] → Render it last, isolate providers/controllers, test audio continuity and stale-key rejection, and allow runtime disablement.
- [Changing voice mid-track can drift because profile durations differ] → Preserve proportional rather than absolute time, clamp after the new duration resolves, show the new time truthfully, and never infer completion from the seek.
- [A settings mode change can race with route navigation] → Serialize transitions, gate them by active journey/playback generation, cancel obsolete monitoring first, and ignore mode changes in completed revisit mode.

## Migration Plan

1. Add the new tables and indexes through one additive Alembic migration; run migration tests against upgrade from the current `20260823_0008` head and verify downgrade removes only community tables.
2. Deploy the API with `COMMUNITY_ENABLED=false`, verify health, policy response, ownership checks, storage configuration and two-account integration tests.
3. Enable the policy in the production environment and verify one controlled node with text, upload, evidence copy, summary card, detail, liker pagination, comment pagination, report and author delete. Disabling the flag is the immediate behavioral rollback; existing rows remain intact.
4. Release the incremented Flutter APK and verify the narration-card voice handoff plus settings-only location mode on a controlled route. Older clients ignore the new endpoints; the new client hides the section against an older/disabled API and keeps the official journey usable.
5. Rollback order is client first if needed, then disable community. Do not downgrade the database while a server version may still write community data; physical table removal requires an explicit backup because it destroys posts and community-media metadata.
