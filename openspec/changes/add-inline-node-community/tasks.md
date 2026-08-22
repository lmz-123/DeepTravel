## 1. Persistence and runtime contract

- [x] 1.1 Add SQLAlchemy community post, media, like, comment and report models with the designed foreign keys, soft states, uniqueness constraints and feed/action indexes.
- [x] 1.2 Add the next Alembic migration after `20260823_0008` for all community tables and verify upgrade/downgrade preserves existing users, journeys, fragments and evidence.
- [x] 1.3 Add typed runtime configuration for enablement, categories, title/body/comment lengths, four-image cap, accepted image types, report reasons, hold threshold and community-media retention/normalization limits.
- [x] 1.4 Add authenticated community policy serialization and tests proving policy responses contain no storage credentials, object keys, account secrets or moderation internals.

## 2. Community media boundary

- [x] 2.1 Implement a `CommunityMediaStorage` boundary over the configured local/OSS adapter with a distinct community namespace, authenticated/signed reads and no anonymous asset exposure.
- [x] 2.2 Implement safe image decode, orientation normalization, EXIF/GPS removal, bounded resize/compression, checksum/dimension metadata and rejection of invalid or unsupported files.
- [x] 2.3 Implement evidence-copy validation against current user, journey and matching fragment, producing an independent community object without a lifecycle foreign key to private evidence.
- [x] 2.4 Add compensation and cleanup behavior for multipart staging failures and soft-deleted posts, with tests proving no partial post/orphan object remains and private evidence is never deleted.
- [x] 2.5 Add local and object-storage tests for authenticated media reads, signed URL refresh seams, metadata stripping, source expiry independence and cross-user denial.

## 3. Node community application service

- [x] 3.1 Implement reusable authorization that applies owner-not-found semantics and requires a revealed/collected journey fragment for feed, post and target-resource actions, including completed and archived-route footprints.
- [x] 3.2 Implement newest-first fragment summary projections with category filters, maximum page size, opaque scope-bound keyset cursors, optional title/body excerpt, cover media, author presentation, counts and viewer state without N+1 queries.
- [x] 3.3 Implement authorized full-post detail projections plus keyset-paginated privacy-safe liker projections, including held/deleted/reporter-hidden not-found behavior.
- [x] 3.4 Implement idempotent post creation for optional title/body, uploads and explicitly confirmed evidence copies, enforcing category/content/media limits and all-or-nothing visibility.
- [x] 3.5 Implement unique like/unlike behavior and authoritative viewer/count responses under retries and concurrent requests.
- [x] 3.6 Implement paginated one-level comments with idempotent creation, author deletion, count convergence and rejection of nested replies.
- [x] 3.7 Implement author-only post deletion, per-reporter hiding, unique post/comment reports and atomic threshold transition to held state without physical audit deletion.
- [x] 3.8 Add service/repository tests for two-account shared visibility, locked-node and cross-user denial, stable feed/liker/comment pagination under concurrent inserts/deletes, detail access, idempotency, soft deletion and report threshold behavior.

## 4. REST API and backend verification

- [x] 4.1 Add `GET|POST /journeys/<journey_id>/fragments/<fragment_id>/community-posts` with validated cursor/filter queries and atomic multipart parsing for title, body, category, idempotency key, photos and evidence IDs.
- [x] 4.2 Add authenticated full-post detail, liker pagination, post delete, like/unlike, comment list/create/delete, post/comment report and community-media read endpoints using the existing error envelope and UTC serialization.
- [x] 4.3 Register the community service/storage in application bootstrap without coupling it to fragment trigger, playback, evidence-retention or historical-content services.
- [x] 4.4 Add API integration tests for authentication, owner-not-found behavior, locked/revealed/completed/archived contexts, invalid cursors/media, policy disablement and no leakage of raw user IDs or storage references.
- [x] 4.5 Run backend formatting/lint, migration and full test suites; fix regressions before beginning mobile integration.

## 5. Flutter community data and state

- [x] 5.1 Add immutable policy, post summary, post detail, media, author, liker, comment, page, category and mutation result models with defensive JSON parsing and localized category labels.
- [x] 5.2 Extend `ExperienceRepository`, API and demo implementations for policy, feed summary, full detail, liker pages, media, post, like, comment, delete and report operations, including multipart upload/evidence-copy requests and authenticated media refresh.
- [x] 5.3 Add Riverpod feed controllers keyed by user, journey, selected fragment and filter plus detail/liker/comment controllers keyed by user and post, with first-page/append/refresh/mutation states, stable de-duplication and late-response rejection after node changes.
- [x] 5.4 Invalidate community state and authenticated media bytes on logout/test-account switch while preserving the existing global narration session for ordinary in-account navigation.
- [x] 5.5 Add repository/controller tests for feed/detail/liker/comment pagination, optimistic cross-projection rollback, idempotent retry presentation, policy disablement, account isolation, stale fragment/detail responses and community failure isolation from tour state.

## 6. Inline 见地现场 presentation

- [x] 6.1 Build a reusable `NodeCommunitySection` with compact policy-aware composer entry, category chips, loading/empty/error/retry states, de-duplicated load-more behavior and Chinese copy consistent with the existing visual system.
- [x] 6.2 Build accessible image-led summary cards with near-square cover/grid, optional title/excerpt and like/comment footer, plus text-only paper-style cards with the same stable information hierarchy and restrained/reduced motion.
- [x] 6.3 Build a near-full-height contextual post detail sheet with complete zoomable media/text, privacy-safe paginated liker presentations, paginated one-level comments, like/comment author actions, report confirmation, authoritative rollback and underlying feed-offset restoration.
- [x] 6.4 Build the modal composer with optional short title, body/category validation, camera/gallery selection, up to four ordered previews, recoverable publish state and explicit “分享到见地现场” confirmation for private evidence sources.
- [x] 6.5 Integrate the section as the literal final block of `JourneyPage` for `selectedFragmentId` only, after all narration, photo, progression/reconstruction, revisit and journey-error controls, without adding state to `ActiveTourController`.
- [x] 6.6 Update footprint detail to select collected nodes, show only the selected node's recap and matching private keepsakes first, and reuse the same community section at the bottom without starting monitoring or mutating completion.
- [x] 6.7 Add widget/integration tests proving image/text card layouts, detail open/close and count reconciliation, node switches cannot show stale posts/details, community interactions do not stop playing narration, locked nodes have no feed, archived completed footprints work, and private-share cancellation creates nothing.
- [x] 6.8 Add regression tests proving discovery, route cards, city selector, global navigation and the 见地 drawer contain no 动态/见地现场 entry or badge.

## 7. Compact narration and location controls

- [x] 7.1 Remove standalone narration voice cards from route detail and journey layout, refactor the server-driven picker behind an accessible current-voice icon inside the narration playback card, and hide misleading selection when only one profile exists.
- [x] 7.2 Implement generation-safe same-fragment profile replacement that preserves proportional progress and playing/paused intent, commits preference only after a playable replacement, rejects stale callbacks and restores the previous track on recoverable failure without acknowledging completion.
- [x] 7.3 Remove simulated-location switches from route detail and journey status, retain read-only mode truth plus the simulated next-clue control, and make the active tour apply the single user-scoped 设置 preference while ignoring mode changes during completed revisit.
- [x] 7.4 Add controller/widget tests for voice picker placement, immediate playing/paused handoff, duration drift, rollback, single-player ownership, no standalone selector, settings-to-active-tour real/simulated synchronization, monitoring cancellation and no duplicate switches.

## 8. Documentation, validation and release

- [x] 8.1 Document the community summary/detail/liker API, policy/environment values, authenticated media lifecycle, privacy distinction from evidence, report/hold limitation, compact voice/location UI and production rollback procedure.
- [x] 8.2 Run `openspec validate add-inline-node-community --strict`, backend `ruff`/`pytest`, mobile `dart format`/`flutter analyze`/`flutter test`, and review `git diff --check` with all required checks passing.
- [x] 8.3 Increment `mobile/pubspec.yaml` to a new semantic patch/build version, build the production API-mode release APK with the required runtime logging secret, copy it to `dist/jiandi-<version>-release.apk`, and verify manifest version and signature.
- [x] 8.4 Review repository status for unrelated files/secrets, commit only the implementation and OpenSpec artifacts, fetch/confirm non-divergence, push `main`, and record the commit hash, APK path and exact `/root/DeepTravel` migration/deployment commands.
