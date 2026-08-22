## 1. Database and compatibility foundation

- [x] 1.1 Add reversible MySQL migrations for `users`, nullable legacy-to-user ownership links, journey `user_id`, media/evidence object-storage fields, narration provenance, and canonical route lifecycle indexes; verify upgrade and downgrade against MySQL 8.4 fixtures.
- [x] 1.2 Backfill every non-archived route with an existing `published_at` to `published`, leave timestamp-free rows offline, and add a migration assertion/report proving Nantou, Dameisha, and current Shanghai visibility is preserved before a new client is released.
- [x] 1.3 Update backend and admin models/serializers to read both new cloud references and legacy local paths during migration; add regression tests for mixed old/new rows.

## 2. User authentication and progress isolation

- [x] 2.1 Implement the user repository/service, username normalization, scrypt password hashing, register/login/me endpoints, expiring user bearer tokens, generic failures and bounded authentication attempts; test duplicate registration, valid/invalid login, token expiry and re-login to the same progress.
- [x] 2.2 Implement environment-gated test login for an explicit seeded alias allowlist, with distinct tester A/B users and no arbitrary account creation; test one-tap authorization and prove the endpoint is absent when disabled or under the production profile.
- [x] 2.3 Backfill one temporary legacy user per guest session, resolve old tokens through `guest_sessions.user_id` during the compatibility window, and allow setting credentials on the same user row; test ownership IDs and progress remain unchanged through conversion.
- [x] 2.4 Audit every ordinary journey, fragmented journey, playback, evidence, reconstruction, recap, and active-tour use case so `user_id` ownership is established before any private lookup or idempotency response; add a two-user API matrix proving cross-user reads and mutations return indistinguishable not-found responses.
- [x] 2.5 Add Flutter register/login/session state and test-build one-tap tester A/B switching, clearing only private presentation caches on account change; add repository/provider/widget tests proving logout/login restores the same account and tester B never sees tester A state.
- [x] 2.6 Add privacy-safe client/server authentication diagnostics without recording passwords or bearer tokens; verify log snapshots and real-time admin log views contain only user correlation IDs and sanitized failure reasons.

## 3. Publication lifecycle and public visibility

- [x] 3.1 Implement the `draft → in_review → verified → published → archived` transition rules, dedicated submit/verify/publish/archive application commands, atomic publication timestamps, and blocking graph validation; test every allowed and rejected transition.
- [x] 3.2 Split public catalog lookups from owner-authorized journey lookups so public city/list/detail/start queries require both `published` and `published_at`, while existing owned journeys can continue archived routes; test direct-slug denial, city exclusion, new-start denial, and legacy continuation.
- [x] 3.3 Correct the independent admin API mappings so ordinary saves never translate `verified` into `published` or manufacture `published_at`; add endpoint tests for truthful status, visibility, counts, and transition failures.
- [x] 3.4 Update admin route tables, editors, graph views, badges, filters, and actions to display “待审核 / 已审核·未发布 / 已发布 / 已归档” distinctly and show whether travelers can currently see the route; add frontend interaction tests for verify, publish, and archive flows.
- [x] 3.5 Make Flutter defensively render only published catalog records, retain the backend-driven horizontal destination/route selection and both real/simulated location modes, and show a neutral empty state for contract violations; add widget tests proving no destination constants or fallback route are substituted.

## 4. Cloud object storage and media migration

- [x] 4.1 Define backend and admin object-storage ports and implement local plus Alibaba OSS SDK V2 adapters with environment credentials, immutable collision-resistant keys, public URL resolution, private signed reads, existence checks, and deletion; run shared contract tests against local and fake OSS implementations.
- [x] 4.2 Route editorial image/audio upload, import, validation, listing, and safe deletion through the admin storage port; verify database rollback/object cleanup behavior and reject deletion of assets referenced by published content.
- [x] 4.3 Keep traveler photo upload server-proxied, enforce user ownership and fragment eligibility, decode/re-encode images with EXIF removal, store normalized bytes in private user/journey-scoped OSS keys, and expose only short-lived owner-authorized access; test malicious images, URL expiry, replacement/deletion, and cross-user denial.
- [x] 4.4 Update public media serialization so migrated covers, stop images, and narration return absolute OSS/CDN URLs while safe legacy relative paths retain temporary backend serving; add API tests ensuring filesystem paths and private canonical references never leak.
- [x] 4.5 Build an idempotent dry-run-capable command that checksum-migrates existing public media from local storage to OSS, transactionally updates all city/route/stop/fragment references, skips matching objects, and reports missing/orphaned assets; verify repeat runs produce stable keys and no duplicates.
- [x] 4.6 Add production configuration examples and deployment checks for separate public-content and private-evidence buckets/prefixes, custom public base URL, least-privilege credentials, signing TTL, and local fallback; verify secrets are sourced only from environment files excluded from Git.

## 5. Expressive narration workflow

- [x] 5.1 Define a provider-neutral narration synthesizer and deterministic fake/manual implementation, then add a MiniMax domestic T2A adapter for `speech-2.8-hd` with curated voice, emotion, pace, pitch, pronunciation, timeout, and sanitized error handling; test exact provider payload mapping and failure behavior without paid credentials.
- [x] 5.2 Add admin preview APIs and persistence for at least three same-script variants, including transcript hash, provider/model/voice/prosody metadata, temporary object keys, independent playback URLs, and expiry/cleanup; test that preview generation never changes published narration.
- [x] 5.3 Add admin audition UI for generating, labeling, playing, comparing, and selecting variants plus the existing manual-upload fallback; add component/e2e tests for unavailable credentials, partial failure, and three completed previews.
- [x] 5.4 Implement approval as transcript-hash-checked promotion to versioned public media and bind the fragment only after cloud/database success; test stale-script rejection, rollback, checksum/provenance persistence, and publication validation requiring current approved audio.
- [x] 5.5 Add a credential-gated production smoke script and listening checklist for calm/documentary/story-style Mandarin voices; when `MINIMAX_API_KEY` is supplied, compare three real previews and record the approved preset/settings without making cloud credentials part of the default test suite.

## 6. Shanghai fragmented audio content

- [x] 6.1 Research the new Shanghai route from named municipal, district, heritage, museum, archive, or library sources and create claim/source records that distinguish documented facts from editorial or field interpretations; run the content validator and resolve every blocking unsupported claim.
- [x] 6.2 Author a reusable admin-import package for a new Shanghai slug with exactly five ordered WGS-84 location-triggered fragments, complete transcripts, no answer interaction, at most three safe/postponable photo missions, reconstruction items, cloud cover, and approved narration references; verify it imports without route-specific Flask or Flutter code.
- [x] 6.3 Add backend progression fixtures proving the Shanghai configuration advances through trigger, playback, optional evidence, collection, and reconstruction without answer submission in both real and simulated positioning modes.
- [x] 6.4 Add Flutter integration tests proving the new Shanghai route renders the generic fragmented audio/photo flow with transcript and playback state, never renders quiz UI, and an existing archived Shanghai quiz journey still resumes its legacy answer flow.
- [x] 6.5 Validate, verify, and explicitly publish the new Shanghai route through admin APIs, smoke-test its public discovery/detail/start flow, then archive the old quiz route and prove an already-started legacy journey remains accessible.

## 7. End-to-end verification and delivery

- [x] 7.1 Run backend unit/API suites, migration checks, formatting/static checks, and a MySQL-backed integration pass covering two users, registration/re-login, disabled test auth, legacy conversion, lifecycle visibility, archived continuation, local storage, and fake OSS/TTS.
- [x] 7.2 Run independent admin tests and production build, then exercise media upload, lifecycle actions, side-by-side real-time logs, TTS preview/approval, and Shanghai package publication against a disposable backend database.
- [ ] 7.3 Run Flutter analysis/tests and build a release APK configured for the production API; install-smoke registration/login, test-account switching in the test build, horizontal route selection, retained simulation switch, real location eligibility, audio/transcript, photo upload, reconstruction overlay, and expired-token re-login.
- [ ] 7.4 Deploy backend migration/code before the new APK, migrate media with dry-run and checksum verification, confirm only published routes and cities are public, and run a tester A/B isolation smoke test with private OSS photos while confirming test login is unavailable in production.
- [ ] 7.5 Commit and push backend/client/OpenSpec changes to `main` in the DeepTravel repository, commit and push admin changes to its `main`, and deliver the verified APK plus idempotent server pull/migrate/restart/health-check commands.
