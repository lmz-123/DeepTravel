## 1. Baseline contracts and scope guardrails

- [x] 1.1 Add contract tests that capture the current journey collection, fragmented ledger, evidence retention, footprint navigation, community placement and discovery-home behavior before replacement.
- [x] 1.2 Inventory every existing footprint dependency on `JourneyContext`, narration/player state, voice fields, route statistics, evidence and `NodeCommunitySection`; record the exact removals and the separate journey navigation that remains.
- [x] 1.3 Define and test the footprint privacy/logging policy: owner-only metadata/photo access, no public object reference, no private text/image/filter payload in routine logs, no automatic community publication and no location fields.
- [x] 1.4 Lock non-goals with diff checks and regression tests so trigger radii, nearby ordering, audio ownership, causal reconstruction, city selection, route recommendation and simulation behavior remain unchanged.

## 2. Backend schema and semantic snapshot model

- [x] 2.1 Add story-content fields for reviewed footprint editorial summary and stable short-summary options, including normalization, bounded validation and backward-compatible fallback tests for existing published content.
- [x] 2.2 Add `footprint_entries` persistence with owner/journey/source uniqueness, semantic city/scene/story/title/summary/choice/theme snapshots, source revision, draft/organized state, short user fields and indexed timestamps; verify migration upgrade and model constraints on SQLite tests and MySQL-compatible DDL.
- [x] 2.3 Add a normalized footprint-theme relation if query-plan validation shows JSON filtering cannot meet owner/city/theme/time pagination requirements; otherwise document and test the selected JSON index/query strategy.
- [x] 2.4 Add `footprint_photos` persistence with one-photo uniqueness, durable private object metadata, idempotent replacement fields and soft-delete/account-lifecycle fields, explicitly outside evidence expiry.
- [x] 2.5 Add database/migration tests proving no audio URL, playback progress, narration profile/provider/version or raw storage credential is stored in the footprint aggregate.

## 3. Backend footprint application service and APIs

- [x] 3.1 Implement owner-scoped, idempotent footprint draft upsert from a revealed fragment or legacy completed stop, including server-only editorial fallback and stable snapshot choice IDs/text; test later-point-first and repeated reconciliation.
- [x] 3.2 Integrate non-blocking draft reconciliation with formal trigger success and ledger reads without changing trigger, playback, collection, photo-optionality or reconstruction rules; test footprint failure/retry seams independently from journey state.
- [x] 3.3 Implement cursor-paginated `GET /footprints` with combined owner, city, arbitrary theme, time, organization and incomplete-journey filters plus stable newest/oldest ordering and server-derived filter facets; add authorization, pagination and empty-result tests.
- [x] 3.4 Implement owner-only `GET /footprints/<id>` and `PATCH /footprints/<id>` with explicit clearing, Unicode-aware short limits, summary-choice validation, idempotent retries and draft/organized transitions; add cross-account and stale-choice tests.
- [x] 3.5 Implement `GET /footprints/resume-candidate` selecting only the current user's most recent eligible deferred/incomplete footprint, with deterministic ties and no stale-user cache behavior; add none/one/multiple-owner tests.
- [x] 3.6 Implement footprint policy metadata exposing supported image rules and short-field limits without exposing storage configuration; add API contract tests for rolling client compatibility.
- [x] 3.7 Implement related-content lookup using only published city-story catalog records, exact city then overlapping themes and bounded backend order; test archived/draft exclusion and no-result behavior.
- [x] 3.8 Add explicit response-schema tests proving footprint list/detail/home/related DTOs omit all audio, playback, voice, provider, object-key, location and unrelated route-statistics fields.

## 4. Durable private footprint photos

- [x] 4.1 Add a dedicated private footprint-photo storage namespace and service with format/size/dimension validation, owner authorization and staged-object rollback cleanup; do not reuse evidence retention as the source of truth.
- [x] 4.2 Implement idempotent POST/replace, authenticated byte GET and DELETE endpoints for one footprint photo, including privacy-safe not-found behavior and no public asset URL.
- [x] 4.3 Add tests for upload retry, replacement cleanup, delete retry, invalid/spoofed image rejection, storage/database failure cleanup, cross-account access, account deletion and survival past evidence expiry.
- [x] 4.4 Ensure runtime logging and error details contain only safe footprint/photo identifiers and state codes, never image bytes, personal text, object keys or signed URLs; add redaction/contract tests.

## 5. Independent admin content and JSON import

- [x] 5.1 In the separate `Travel-Admin` repository, extend the shared content graph/schema with footprint editorial summary, stable summary-option objects and arbitrary footprint themes while preserving existing content-package compatibility.
- [x] 5.2 Add story-point manual editor controls for the new fields with concise-copy guidance, unique option-ID validation, draft/review/approval/publish lifecycle and no audio/provider coupling.
- [x] 5.3 Extend JSON validation, preview, deduplication and import/export so manual editing and import use the same fields and return exact paths for invalid lengths, blank summaries or duplicate option IDs.
- [x] 5.4 Add independent-admin unit/API/UI tests covering valid arbitrary Chinese themes, old packages without new fields, review/publication behavior and round-trip manual edits after import.
- [x] 5.5 Inspect and commit/push admin changes independently from the main repository; record its deployment and rollback commands without mixing generated assets or secrets.

## 6. Flutter footprint domain, repositories and state

- [x] 6.1 Add footprint-only domain models for semantic snapshot, summary options, user fields, private-photo state, themes, time and minimal journey-resume reference; add JSON tests that reject accidental audio/playback/voice assumptions and tolerate additive server fields.
- [x] 6.2 Add repository methods for list/facets, detail, patch/defer, resume candidate, photo lifecycle and related content with authenticated requests, idempotency and typed privacy-safe failures; add API and demo/offline fakes without hard-coded city/content data.
- [x] 6.3 Add account-scoped Riverpod list/filter/detail/editor/photo/related-content controllers that preserve known data on refresh failure, cancel stale filter/detail responses and clear all private caches on account exit/change; add controller race/isolation tests.
- [x] 6.4 Keep footprint controllers independent of active/home narration players, voice preferences and audio ownership; add a dependency/import audit test or architecture check that fails if those modules are introduced.
- [x] 6.5 Add safe local pending-edit/photo retry state only where necessary, encrypt or isolate it under the current user, reconcile server authority without duplicating records, and test app restart/account-switch cleanup.

## 7. Flutter footprint entry, browsing and lightweight editing

- [x] 7.1 Keep the drawer/global destination label “足迹” and replace the route-led footprint list with semantic record cards showing city, scene/story, concise summary, themes, time, organization/private-photo state and no route progress statistics; add semantics and text-scale tests.
- [x] 7.2 Add server-derived city, arbitrary theme, time/order and incomplete-journey filters with combined filtering, pagination, clear action and truthful loading/empty/offline/retry states; add widget tests without fixed city/theme constants.
- [x] 7.3 Rebuild footprint detail around “见地讲述 / 我看到的 / 我留下的”, compact missing-user-content invitations and authenticated photo viewing, and remove replay, playback progress, voice/version labels and inline community; add negative widget tests for every forbidden surface.
- [x] 7.4 Add short-form organization UI for zero-or-one summary choice, observation and personal sentence, explicit clearing, character feedback, save and “稍后再整理”; verify dismissal and errors never block or mutate journey progress.
- [x] 7.5 Present incomplete journey status as a visually secondary “继续漫游” action that loads the existing owner journey context and leaves the footprint readable on failure; add active, completed, archived and unavailable-journey tests.
- [x] 7.6 Add related published city-reading cards after the private record, with no empty rail when unavailable and no private/community leakage; add navigation and stale-response tests.
- [x] 7.7 Add the discovery-home “继续我的足迹” module from the owner resume-candidate endpoint, opening footprint organization rather than starting/resetting a journey, while discovery remains usable if it fails; add account-switch and absent-candidate tests.

## 8. Local share-card privacy boundary

- [x] 8.1 Add the maintained platform-share dependency and a footprint share-card renderer with deterministic local PNG output, accessible preview, text-only default and no account ID, journey ID, coordinates, storage path or unselected private content.
- [x] 8.2 Add an explicit private-photo inclusion toggle and confirmation before authenticated photo bytes enter the export, and prove no photo request occurs for the default text-only card.
- [x] 8.3 Open only the native share sheet, never the community create API, and clean per-user temporary export files after cancellation/success where observable, account exit and cache maintenance.
- [x] 8.4 Add renderer/golden, privacy, cancellation, reduced-motion and platform-adapter tests for text-only, confirmed-photo, missing-photo and offline-known-content cards.

## 9. Historical backfill and compatibility

- [x] 9.1 Implement a resumable idempotent backfill command for all owner-visible revealed fragmented points and completed legacy stops, preserving source trigger/creation time and never changing journey ledger, completion or causal order.
- [x] 9.2 Copy at most one eligible non-expired legacy evidence image into the durable footprint namespace with checksum deduplication and failure journaling, leaving original evidence lifecycle untouched.
- [x] 9.3 Add backfill dry-run/reporting plus tests for partial/completed/archived journeys, legacy stops, no-photo records, multiple users, reruns, missing content fallback and storage failure recovery.
- [x] 9.4 Verify old clients continue using journey/evidence endpoints while new clients handle pre-deployment servers with truthful unavailable footprint states; document server-first rolling deployment and data-preserving rollback.

## 10. Verification and delivery

- [x] 10.1 Run focused and full backend formatter/lint/tests, migration upgrade checks and API privacy/schema audits; confirm existing trigger, reconstruction, community, evidence-retention and legacy-route suites remain green.
- [x] 10.2 Run independent-admin formatter/lint/tests and inspect its diff for unrelated content, route, audio or publication changes before separate commit/push.
- [x] 10.3 Run Flutter formatting, analyze, focused/full tests, architecture/import audit, semantics/text-scale/reduced-motion checks and verify the footprint screens instantiate no audio player or community request.
- [x] 10.4 Run strict OpenSpec validation and inspect both repository diffs for hard-coded cities/themes/summaries, public photo URLs, audio coupling, map/route-recommendation work, secrets and unrelated generated files.
- [x] 10.5 Update only footprint API/privacy/content/backfill/deployment documentation, increment the full mobile version, and build/inspect the production Android APK only when required runtime credentials are available.
- [ ] 10.6 Commit and push scoped main and admin changes independently, then report hashes, validation evidence, backfill dry-run/execute commands and exact API/admin deployment/rollback sequences.
