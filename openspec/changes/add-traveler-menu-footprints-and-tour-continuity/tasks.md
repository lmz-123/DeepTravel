## 1. Backend persistence and journey lifecycle

- [x] 1.1 Add an Alembic migration for nullable photo guidance fields and user/status/route journey indexes, then extend migration upgrade/downgrade tests without deleting or rewriting existing journey/evidence data.
- [x] 1.2 Extend main API persistence models and journey repository ports with latest-completed and ordered user-library queries, and add repository tests for active-first ordering, duplicate historical completions, and archived routes.
- [x] 1.3 Update `JourneyService.start_or_resume` to return active, then latest completed, then create new; add service/API tests proving completed revisit is idempotent and a different user cannot reuse the record.
- [x] 1.4 Add fragment/answer/evidence aggregation queries that compute correct audio-route and legacy-route progress without N+1 SQL, and verify progress/counts for active, completed, photo-free, and archived journeys.

## 2. Backend private library and evidence APIs

- [x] 2.1 Implement `GET /journeys` status filtering and owner-scoped collection serialization with route summary and counts; add API tests for ordering, invalid filters, account isolation, and `/journeys/active` compatibility.
- [x] 2.2 Implement `GET /journeys/{id}/context` with complete route/audio manifest for the owner, including archived owned routes; test deep recovery, non-owner not-found behavior, and public archived-route restrictions.
- [x] 2.3 Implement `GET /journeys/{id}/evidence` metadata listing with fragment/mission association and no storage keys, plus authenticated byte retrieval tests across restart-style requests, deletion, expiry, and account boundaries.
- [x] 2.4 Implement `GET /policies/evidence` from runtime configuration and test that retention, limits, EXIF/private statements are accurate and contain no secret configuration.
- [x] 2.5 Change fragment playback reconciliation so threshold completion always collects photo-capable clues and upgrades legacy `mission_pending`; cover idempotency, dependencies, reconstruction unlock, and old-row compatibility in domain/API tests.
- [x] 2.6 Allow evidence upload onto an already collected clue and make evidence deletion preserve collection/reconstruction before and after completion; update privacy, upload retry, retention, and delete regression tests.

## 3. Main repository photo guidance content

- [x] 3.1 Extend photo mission persistence, public/revealed serializers, seed/import handling, and Flutter-facing JSON with `vantage_point`, `shooting_direction`, and `composition_tip` plus legacy fallbacks; add backend serialization tests.
- [x] 3.2 Update Shenzhen/Nantou, Dameisha, and Shanghai seed/content packages with route-specific safe station, direction, and composition copy and non-blocking photo semantics; run content graph/package tests for every package.
- [x] 3.3 Update public API/content workflow documentation with optional-photo and shooting-guidance contracts, including a production republish checklist that performs no automatic production mutation.

## 4. Independent Travel-Admin repository

- [x] 4.1 In `/Users/li/Downloads/Project/Travel-Admin`, add the independent schema migration/model fields and round-trip import/export support for the three shooting guidance values; add server tests and preserve its clean unrelated worktree.
- [x] 4.2 Update Admin graph validation to require shooting guidance for newly validated photo missions while accepting legacy stored rows through the deployment seam; add field-specific validation and required-count regression tests.
- [x] 4.3 Add admin editor fields for safe position, shooting direction, and composition guidance with review-friendly labels and persistence; run the Admin typecheck/lint/test/build commands documented by that repository.

## 5. Mobile data, recovery, and preferences

- [x] 5.1 Add journey library/context, evidence metadata, policy, and authenticated image-byte domain/repository APIs; test JSON parsing, bearer headers, relative evidence paths, 401 expiry, 404/410, and partial list failure.
- [x] 5.2 Add user-scoped journey-library/context/evidence providers and invalidate them after completion, evidence changes, refresh, logout, and test-user switching; verify one account's cached private data never renders for another.
- [x] 5.3 Introduce a user-id-namespaced preference repository for playback speed, location mode, download policy, and normalized playback-orb position, including one-time migration of the old global location key; test two users with conflicting preferences plus position restore/clamping across relaunch and layout changes.
- [x] 5.4 Declare direct connectivity/version dependencies, enforce `wifiOnly | anyNetwork | manual` only for route pre-download, and test streaming fallback plus human-readable network-policy feedback.
- [x] 5.5 Add prepared-audio cache enumeration and safe clear operations that remove files and index rows but preserve snapshots, outbox, auth, journeys, and evidence; cover full, empty, and partial-file-failure cases.

## 6. Mobile application shell, drawer, footprints, and settings

- [x] 6.1 Add the private go_router shell/shared scaffold without duplicating the audio player, and write navigation tests showing provider/player continuity across discovery, route, footprint, and settings pages.
- [x] 6.2 Make the discovery `BrandMark` an accessible drawer trigger, build the default-avatar/username/足迹/设置/退出登录 drawer, remove the city-side account avatar, and test semantics plus logout/test-switch cleanup.
- [x] 6.3 Build the 足迹 list with completed route cards, sorting, counts, neutral empty state, pull-to-refresh, archived-item support, and per-item recoverable errors; add widget tests using multiple completed journeys.
- [x] 6.4 Build footprint detail for fragmented replay/gallery and legacy recap, including owner-context recovery when in-memory controller state is absent; test completed, archived, no-photo, and stale-media routes.
- [x] 6.5 Build 设置 for speed, location mode, download policy, cache clearing, dynamic photo policy, and app version; add widget/repository tests for persistence, account isolation, confirmation, success, and partial failure states.

## 7. Mobile continuous playback and node replay

- [x] 7.1 Refactor active-tour state into live/revisit mode with separate progress and selected fragment ids plus an account/route/journey/fragment playback owner and generation token; add controller tests that reject stale position/completion/trigger callbacks and preserve the server cursor.
- [x] 7.2 Add completed revisit initialization that loads ledger/audio without active-tour registration or location tracking, and test play/pause/seek/speed/background behavior with zero location samples.
- [x] 7.3 Build the discovery-page `RotatingTourOrb` as a 56–64px vinyl visual with a 72px semantic hit target, server-driven route artwork/fallback, outer progress ring, playing-only rotation, paused/static and reduced-motion states, tap-to-journey, free pan within safe bounds, persisted normalized position, and semantic directional move actions; test drag-versus-tap/scroll behavior, restore and clamp, compact/large safe-area layout, live owner updates, hidden-off-home behavior, stopped state, semantics, and assert that no horizontal mini-player bar is rendered.
- [x] 7.4 Map discovery route cards to active/latest-completed journey index so active routes and completed routes bypass the first-time headphone gate appropriately; add first-time, active, completed audio, completed legacy, and mixed-history widget tests.
- [x] 7.5 Convert fragment rail nodes into 48x48 semantic controls with selected/live/collected/locked states and implement collected-node replay that stops current audio without progress writes; test green-node switching, locked feedback, queue cleanup, and return to live.
- [x] 7.6 Rework simulated 下一条线索 to stop current audio, idempotently acknowledge completion, refresh, and trigger the next eligible clue without photo evidence; test early tap, photo-free advance, trigger failure retry, final-clue message, and unchanged real-location rules.
- [x] 7.7 Centralize explicit stop, logout, account switch, and auth-expiry cleanup for audio/location/private presentation while preserving server state; add lifecycle tests for each exit path.
- [x] 7.8 Implement atomic cross-attraction audio replacement for every playback entry point: invalidate the old owner generation, stop current audio, clear autoplay/completion work, stop old-route location monitoring, then load the new owner while preserving both journeys' server state; test playing and paused replacement, background/page-to-page entry, rapid A→B→C requests, stale callbacks, new-load failure, orb owner/cover/navigation updates, and zero overlapping audio.

## 8. Mobile optional photo guidance and viewing

- [x] 8.1 Extend Flutter photo mission/evidence models with guidance and metadata, and keep the photo invitation visible after a clue is collected without rendering it as a blocking warning; add parsing and journey widget tests.
- [x] 8.2 Build the pre-camera 站位/朝向/构图/安全 guide and postpone path, then update capture/upload UI so local thumbnails remain tappable during captured, uploading, queued, accepted, and retry states; test permission/cancel/offline flows.
- [x] 8.3 Implement account-scoped authenticated evidence byte loading, thumbnail button, and dedicated large-photo viewer with local-first/server-fallback behavior; test restart recovery, expiry/deletion placeholders, retry, close/zoom semantics, and cache clearing on user switch.
- [x] 8.4 Implement the reusable code-native nostalgic keepsake frame with stable subtle irregular edges, restrained tilt/shadow, intact aspect ratio, and reduced-motion behavior; add widget/golden coverage at representative phone sizes.
- [x] 8.5 Use the shared frame/viewer in active journey receipts and footprint galleries, grouped by clue with capture/upload time; test multiple photos, no photos, expired photos, and other-user denial.

## 9. Integrated verification and handoff

- [x] 9.1 Run `ruff check app tests` and full `pytest` in `backend`, fixing all regressions and recording focused API/migration coverage for journey history, non-gating photos, privacy, and revisit.
- [x] 9.2 Run Dart formatting checks, `flutter analyze`, full `flutter test`, and a production-flavor compile smoke check without secrets; verify drawer, draggable rotating playback orb, cross-attraction automatic stop, replay, settings, and photo viewer on compact and large layouts, including paused and reduced-motion states.
- [x] 9.3 Run the independent Travel-Admin validation/test/build suite and inspect both Git worktrees so generated caches and unrelated user changes remain uncommitted.
- [x] 9.4 Run `openspec validate add-traveler-menu-footprints-and-tour-continuity --strict`, update README/API/verification documents with final behavior and manual A/B account checks, and leave production deploy/publish commands as an explicit later operator action.
