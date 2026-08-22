## 1. Voice content schema and compatibility

- [x] 1.1 Add reversible MySQL migrations and mirrored backend/admin models for narration voice profiles and approved fragment tracks, including lifecycle, default, transcript/version, media/provenance fields, uniqueness, and indexes; verify upgrade/downgrade on MySQL fixtures.
- [x] 1.2 Add an idempotent backfill that creates the published default profile and maps every existing fragment narration to a default track without copying media; verify repeat runs and singular `audio_path` compatibility.

## 2. Independent admin voice publication

- [x] 2.1 Implement admin profile list/create/edit/publish/archive/set-default APIs and route coverage validation; test draft exclusion, incomplete publication rejection, default invariants, and missing/stale fragment reports.
- [x] 2.2 Make preview generation target a stable profile and promote approvals to profile/settings-specific immutable public objects and track rows; test approving multiple profiles never collides with or overwrites the default or another profile.
- [x] 2.3 Add profile and route-coverage controls to the narration admin UI, including traveler-facing name/description/order, provider voice ID, profile-targeted generation, preview, approval, publication, and default actions; run frontend interaction and production-build tests.
- [x] 2.4 Replace per-fragment generation as the primary workflow with route/profile one-click generation that creates formal tracks for every narrated node, selects the default profile initially, reports per-node success/failure and refreshed coverage, retries missing/stale nodes idempotently, and retains per-fragment replacement as a secondary correction tool; add admin API/UI tests.

## 3. Public backend contracts

- [x] 3.1 Implement a repository/application query that computes published voice profiles with complete current-script coverage across a route, keeping provider credentials private; test complete, missing, stale, draft, archived, and ordering cases.
- [x] 3.2 Extend public route detail and owner-authorized journey ledger serializers with default profile, profile metadata, and per-fragment tracks while preserving singular default audio fields; test absolute cloud URLs, old-client compatibility, and archived journey playback.

## 4. Flutter user voice selection

- [x] 4.1 Extend Flutter domain/data mapping for backend-provided profiles and tracks and add an account-keyed local voice preference repository/provider with deterministic default fallback; test account switching, restart restore, unavailable-profile fallback, and no hardcoded voice profiles.
- [x] 4.2 Add an elegant accessible voice selector to route detail and active journey screens, show the effective profile when only one exists, and make mid-playback changes explicitly apply to replay/next playback; add widget tests for single, multiple, and withdrawn profiles.
- [x] 4.3 Route foreground/background playback, prepared downloads, resume, and cache keys through the effective fragment/profile/script track; test voice-specific URL selection, cache separation, transcript stability, retry, and default fallback.

## 5. Registration editing correctness

- [x] 5.1 Make account fields form-owned with no application username controller or during-input mutation, and read the final snapshot only when register/login is submitted; remove suggestion flags as the claimed correctness mechanism.
- [x] 5.2 Add a repository-spy widget regression that performs `liser → delete er → lis → type tt`, asserts visible and submitted `listt`, and covers registration/login mode rebuild plus selection/composing preservation.

## 6. Verification and formal delivery

- [x] 6.1 Run backend, migration, admin API/UI, Flutter analysis/unit/widget suites and additive contract checks without paid TTS credentials; validate the OpenSpec change strictly.
- [ ] 6.2 Generate or approve at least two complete non-default voice profiles for a disposable route and smoke-test client selection, account isolation, background playback, fallback, and the username edit sequence through an Android text connection.
- [x] 6.3 Commit and push DeepTravel and DeepTravel-admin to their `main` branches, build only the production-profile APK with test authentication disabled, verify version/signature/API endpoint, and deliver the APK plus idempotent deployment commands.
