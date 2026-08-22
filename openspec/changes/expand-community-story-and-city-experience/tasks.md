## 1. Baseline and schema migration

- [x] 1.1 Capture clean main/admin repository status, current Alembic head, published APK version, and a machine-verifiable snapshot of every Shanghai content field, script/profile/track hash, and publication state.
- [x] 1.2 Add the next additive Alembic migration for nullable comment root/reply references, thread indexes, home story publications, and complete-story narration tracks; verify upgrade/downgrade on fresh and existing MySQL-shaped schemas without changing legacy comment rows.
- [x] 1.3 Add matching SQLAlchemy models and relationships in the API and independent admin repositories, including uniqueness, publication, provenance, and public-media constraints; cover mapper and migration smoke tests.

## 2. Two-level comment backend

- [x] 2.1 Extend comment creation to accept an optional exact reply target, normalize replies to one root, reject inaccessible/cross-post/deleted targets, and preserve author-scoped idempotency; add focused service tests for root, reply-to-root, and reply-to-reply cases.
- [x] 2.2 Change root comment pagination to return only roots with bounded reply previews, visible reply counts, reply-target projections, and tombstones where required; verify stable cursors under concurrent inserts, reports, holds, and deletes.
- [x] 2.3 Add stable paginated reply reads for one authorized root and batch post/thread visible counts without N+1 queries; test locked-node, cross-user journey, completed-journey, archived-route, and reporter-specific visibility boundaries.
- [x] 2.4 Make deletion and moderation thread-aware so root content becomes a minimal tombstone only when visible replies need it and reply actions do not hide unrelated conversation; test author-only deletion and report thresholds.
- [x] 2.5 Extend the existing comment endpoints and add the root-replies endpoint with defensive query/body validation, privacy-safe serialization, structured errors, and API tests proving no user IDs, provider data, storage keys, or locked-node metadata leak.

## 3. Two-level comment Flutter experience

- [x] 3.1 Extend immutable community comment/page models and repository requests for root IDs, exact reply targets, previews, reply counts, tombstones, reply pagination, and reply creation; add defensive JSON and request tests.
- [x] 3.2 Refactor community detail state to page roots and per-root replies independently, merge mutation results without duplicates, preserve draft/target on failure, and converge post/thread counts after refresh; add controller tests.
- [x] 3.3 Redesign the comment area into clear root cards with inset reply groups, recipient labels, compact reply/delete/report actions, per-thread loading/error states, and accessible semantics; add representative golden/widget tests.
- [x] 3.4 Add explicit “回复 <昵称>” composer mode, focus behavior, cancel-with-draft-preservation, reply-to-reply normalization, successful reset, keyboard-safe layout, and regression coverage for the fixed composer and close behavior.

## 4. Home story API and publication domain

- [x] 4.1 Implement a story-listening application module that selects only published city/route/publication rows with an approved narration track matching the canonical complete-story hash and script version.
- [x] 4.2 Implement weighted city-scoped random selection with an optional previous-story exclusion, deterministic test seams, and structured empty-pool behavior; cover archived, draft, stale, zero-weight, missing-media, unknown-city, and multi-candidate cases.
- [x] 4.3 Add `GET /api/v1/stories/random` serialization for story/city/route display context, title, introduction, cover, duration, transcript, public audio and safe profile display metadata; verify no review internals, provider voice IDs, credentials, or object keys are exposed.
- [x] 4.4 Register story listening in API bootstrap and public media handling without coupling it to journey reconstruction authorization; add route/API integration and public audio availability tests.

## 5. Independent admin story workflow

- [x] 5.1 Add admin endpoints for home-story draft editing, review submission, approval, publication, withdrawal and archive with transcript-hash invalidation and explicit audit provenance; add server tests for every transition and stale-track rejection.
- [x] 5.2 Extend the narration workflow to generate or upload complete-story tracks from `story_arcs.complete_story`, preview candidates, approve one matching track, and expose coverage without duplicating transcript text; add synthesizer/storage failure tests.
- [x] 5.3 Build an elegant admin editor for title, introduction, cover, city/route context, weight, profile, audio preview, transcript hash/coverage, validation blockers and publication controls; add frontend validation and production build checks.
- [x] 5.4 Update admin import/export/content graph handling so home-listening metadata and story-track provenance round-trip idempotently while unpublished stories remain private; add import compatibility tests for older packages.

## 6. Flutter home story playback

- [x] 6.1 Add typed home-story models, repository APIs, providers and selected-city-aware random/exclusion state with empty-pool, loading, retry and cache invalidation tests.
- [x] 6.2 Introduce an application-level audio ownership coordinator with owner, destination, generation token, phase, position and duration; refactor route narration to acquire/release ownership and ignore stale player callbacks without changing fragment progress rules.
- [x] 6.3 Implement a home-story playback controller over the existing audio adapter with prepare, explicit play, pause, seek, replay, ended, retry and disposal behavior; prove that starting either story or route audio stops the other before playback begins.
- [x] 6.4 Turn “听一个短故事” into an accessible home action and add a dedicated story route/page with cover, title, introduction, city/route context, play/pause state, seekable progress, elapsed/total time, transcript alternative, replay and “换一个故事”; add widget/controller tests.
- [x] 6.5 Connect the draggable rotating orb to shared audio ownership so it rotates only while the active source is playing, stays still otherwise, preserves synchronous drag/edge snapping, and navigates to the correct story or journey context; add ownership-switch and navigation tests.

## 7. Journey hierarchy and city selection

- [x] 7.1 Remove the journey-body reconstruction card and “你正在追问” label while retaining the central story theme and functional order; add a journey-page regression test.
- [x] 7.2 Add locked, unlocked and completed reconstruction states to the story ledger, route ledger actions safely into reconstruction/recap, and verify return navigation restores the expected ledger/journey stack.
- [x] 7.3 Replace the city popup with a polished image-led modal selection sheet using only backend city data, clear selection/close semantics, responsive layout, reduced motion and image fallbacks; add widget tests for loading, selection and refresh failure.
- [x] 7.4 Add immediate normalized name/subtitle search when the city catalog reaches the designed threshold, clear empty results, and tests with small and twenty-plus-city datasets proving route and random-story state refresh correctly.

## 8. Shenzhen editorial and narration release

- [x] 8.1 Write the Shenzhen conversational editorial/listening checklist covering observation-first structure, warm playful tone, factual equivalence, uncertainty, pronunciation, outdoor intelligibility, safe optional photo guidance, and repetitive system-language detection.
- [x] 8.2 Rewrite the complete Nantou route content and photo guidance into a versioned publishable package while updating development seed reconciliation to the same canonical values; run graph, source, mission, transcript and idempotent-import validation.
- [x] 8.3 Create the next versioned Dameisha package with rewritten route copy, all node scripts, optional photo guidance and complete story, preserving its reviewed claims, sources, authenticity labels and coordinates; run the same content validations.
- [ ] 8.4 Configure a client-safe Shenzhen warm female narration profile in admin, generate candidate node and complete-story previews, record listening decisions, and keep provider voice settings only in server configuration/audit data.
- [ ] 8.5 Generate, listen-review, approve and publish complete matching narration coverage for both Shenzhen routes and selected home stories; verify every public audio URL, duration, transcript hash, profile display field and default selection.
- [x] 8.6 Compare the post-change Shanghai snapshot with the baseline and fail the release on any content, profile, track, hash or publication change; add a permanent regression check.

## 9. Verification, release and handoff

- [x] 9.1 Run API lint/tests including migration, community concurrency/moderation, story publication/random selection and Shanghai invariance suites; fix all failures and run `openspec validate expand-community-story-and-city-experience --strict`.
- [x] 9.2 Run independent admin server/frontend tests and production build, inspect both repository diffs for secrets/generated files/unrelated changes, and verify API/admin schema mappings remain aligned.
- [x] 9.3 Format and analyze Flutter, run all unit/widget tests including audio ownership and twenty-plus-city coverage, perform focused Android UI smoke checks, and resolve all regressions.
- [x] 9.4 Increment `mobile/pubspec.yaml` to a new unreused semantic version/build, build the production API release APK with production defines and runtime logging, copy it to `dist`, and verify manifest version, version code and APK signature.
- [x] 9.5 Fetch and confirm non-divergence, commit reviewed main and admin changes separately, push both `main` branches, and record commit hashes plus APK path/checksum.
- [x] 9.6 Provide only the exact required API/admin migration, restart, health, Shenzhen content publication and verification commands in server execution order, using `/root/DeepTravel-admin` with exact case and no unnecessary environment toggles or rollback commands.
