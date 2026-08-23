## 1. Baseline and schema ownership

- [x] 1.1 Reconcile this change with `expand-community-story-and-city-experience`, document the canonical fragment/story-arc APIs being reused, and add regression tests that lock their current public behavior.
- [x] 1.2 Add main-repository SQLAlchemy models and an Alembic migration for catalog items/source revisions, story relations, placements, pre-trip guidance, traveler favorites, and import preview/audit records with uniqueness, revision, and lifecycle constraints.
- [x] 1.3 Add migration upgrade/downgrade and model constraint tests, including account favorite isolation and package ID/version/checksum uniqueness.

## 2. Canonical city story catalog

- [x] 2.1 Implement typed canonical source resolution plus reviewed `short_preview` and `on_site_complete` presentation variants for managed fragments/complete story arcs without copied transcript or narration fields.
- [x] 2.2 Implement catalog metadata, city/district/theme/point/story relations with advisory order, observable details, optional attention hints, sources, fact status, review status, arbitrary labels, and publication validation.
- [x] 2.3 Implement canonical revision/hash tracking so source changes invalidate incompatible narration or placement approval, with focused lifecycle tests.
- [ ] 2.4 Implement duration derivation and the non-blocking three-to-eight-minute editorial warning, with boundary tests.
- [x] 2.5 Implement channel placements for the five fixed home module keys, editorial order/weight, route/channel eligibility, active windows, and existing lifecycle locks.
- [x] 2.6 Add domain/application tests proving unpublished, stale, unverified, missing-media, and invalid-relation stories cannot enter public projections.

## 3. Public home story experience

- [x] 3.1 Add a current-city home content query/API returning the five module slots, published catalog cards, backend display labels, shared story identity/revision, and configured ordering.
- [x] 3.2 Add actionable no-content responses with an explicit reason, configured fallback cities/content, and existing city-switch action metadata.
- [x] 3.3 Reuse the existing full-story/fragment listening projection so home, pre-trip, on-site, and post-trip entry points resolve the same canonical identity/revision and the configured approved short or complete presentation variant.
- [ ] 3.4 Add API contract tests for city isolation, publication filters, all five modules, unknown content values, canonical consistency, and actionable empty states.

## 4. Pre-trip route experience

- [x] 4.1 Extend route summaries/details with pre-trip availability, companion tags, theme story, major story directions, advisory order, and safety/rest/accessibility/weather-adaptation editorial tips.
- [x] 4.2 Ensure pre-trip story reading/listening is independent of arrival and journey progression while leaving existing on-site stop behavior unchanged; add regression tests for both modes.
- [x] 4.3 Add versioned offline resource manifests for eligible audio/transcripts with checksum, size, kind, and valid download references.
- [ ] 4.4 Add API tests for arbitrary backend labels, omitted optional guidance, no quiz/exam contract, advisory-order access, and offline manifest invalidation.

## 5. Traveler favorites

- [x] 5.1 Implement authenticated idempotent add/list/remove operations for city, point, and theme favorites using stable typed targets.
- [x] 5.2 Prevent cross-account access and draft-content leakage, and return a removable minimal unavailable-target state when saved content is unpublished.
- [ ] 5.3 Add authorization, isolation, retry/idempotency, unavailable-target, and location-order independence tests.

## 6. Multi-city JSON import service

- [x] 6.1 Define and document the versioned multi-city JSON schema, stable identifiers, package version/checksum rules, entity limits, JSON Pointer errors, and managed-media descriptor contract.
- [x] 6.2 Implement bounded parsing and whole-graph normalization for cities, routes, points, stories, media references, coordinates/ranges, tags, relations, advisory order, and requested placements; reject binary and arbitrary remote media.
- [ ] 6.3 Refactor supported single-route import and manual application commands to share normalization, validation, stable-ID, media, and lifecycle semantics while preserving existing endpoint contracts.
- [x] 6.4 Implement zero-content-write dry-run diffing for new, updated, unchanged, conflicted, and invalid records with exact paths and missing-media/relation/fact blockers.
- [x] 6.5 Implement short-lived editor/package/revision-bound confirmation tokens and reject expired, changed-package, unauthorized, or stale-target confirmations.
- [x] 6.6 Implement whole-package transactional confirmation that writes only draft/pre-publication states, records a redacted audit result, rolls back on any failure, and treats identical package replays as unchanged.
- [ ] 6.7 Add schema fixtures and service/API tests for multiple cities, field errors, graph conflicts, TOCTOU conflicts, rollback, idempotent replay, lifecycle enforcement, and legacy single-route compatibility.

## 7. Flutter home and shared story UI

- [x] 7.1 Add client models/repositories/providers for backend-driven home modules and actionable empty/fallback responses while preserving unknown safe labels.
- [x] 7.2 Build “今天听一段城市故事” as the primary accessible home entry plus the other four modules, and connect every card to the existing shared story player/reader without a preference questionnaire.
- [ ] 7.3 Add widget/provider tests for loading, success, partial modules, all-empty fallback, retry, reduced motion, semantics, unknown labels, and city changes.

## 8. Flutter pre-trip, favorites, and offline preparation

- [x] 8.1 Extend route detail with theme story, duration/distance, story directions, advisory order, companion tags, and optional departure-tip sections without quiz UI.
- [x] 8.2 Add authenticated city/point/theme favorite controls and state reconciliation, including sign-in-required and unavailable-target handling.
- [x] 8.3 Implement explicit offline preparation with version/checksum verification, progress, partial failure, retry, stale-resource invalidation, and removal.
- [ ] 8.4 Add unit/widget/integration tests proving pre-trip access works away from the route, stories open out of order, no examination appears, favorites remain account scoped, and failed resources are not marked prepared.

## 9. Verification and delivery

- [x] 9.1 Run affected backend test suites, migration checks, API contract tests, Flutter analyze/tests, and formatters; resolve regressions without deleting unrelated user changes.
- [ ] 9.2 Verify the companion `Travel-Admin` change against the same migrated schema and complete a manual upload → dry-run → confirm → edit → review smoke test.
- [x] 9.3 Update API/import schema and operator documentation, record compatibility/deprecation notes, and run `openspec validate add-city-story-preview-and-import --strict` in both repositories.
- [x] 9.4 Update mobile build metadata, produce and inspect the Android APK when required credentials are available, then commit and push scoped main-repository changes.
