## 1. Baseline and additive content contracts

- [ ] 1.1 Capture regression fixtures for current route detail/pretrip, legacy random home story, unified city-story home, stop/fragment tags, media URLs, on-site playback, and floating-orb behavior before changing contracts.
- [ ] 1.2 Add a reversible Alembic migration owned by the main repository for versioned route pre-departure introduction text and narration tracks/provenance, preserving existing `route_pretrip_guidance` rows and mixed-version reads; verify MySQL upgrade/downgrade and data retention.
- [ ] 1.3 Extend SQLAlchemy/domain/repository mappings with transcript hash, script version, selected/approved track, lifecycle metadata, and safe public media resolution; add mapping tests for absent, draft, stale, and published records.
- [ ] 1.4 Define additive public/admin-compatible `predeparture`, scenic media inventory, and provider-readiness response schemas with bounded text/list sizes and no credentials, raw filesystem roots, or private canonical references; add schema/serialization tests.

## 2. Scenic pre-departure application behavior

- [ ] 2.1 Implement route-scoped pre-departure create/update/review/publish eligibility so text edits invalidate mismatched narration and draft content never enters public route detail; test every allowed/rejected state.
- [ ] 2.2 Extend route detail with the published concise introduction and approved audio independent of location/journey state, while preserving existing deeper pretrip/offline fields and old-client response compatibility; add API tests for configured, absent, stale, and unavailable audio.
- [ ] 2.3 Extend route narration/media validation to include pre-departure tracks, exact script/hash matching, approved profile metadata, MIME/checksum/size, and safe URL resolution; test publication blockers and rollback behavior.
- [ ] 2.4 Add content-package/import/export round-trip support for pre-departure text and approved media references without embedded binary or arbitrary remote fetches; verify idempotency and field-specific validation errors.

## 3. Unified city-story source and migration

- [ ] 3.1 Implement a dry-run-capable idempotent mapper from eligible `home_story_publications` to canonical story-catalog items, approved variants, and city-home placements keyed by source identity; report ready/conflicted/blocked records and prove no transcript/media copy.
- [ ] 3.2 Apply the mapping transactionally with stable IDs and optimistic revision checks, retain audit output, and test repeat, partial-retry, stale-track, missing-source, and rollback cases.
- [ ] 3.3 Switch city-story collection/detail and random selection to the unified eligible catalog projection while preserving documented legacy read response shapes; make legacy writes delegate or reject as read-only and add compatibility tests.
- [ ] 3.4 Update seed/demo/package fixtures to expose one “城市故事” source and remove duplicate client-facing home-listening placement without hardcoded production story IDs; test empty/fallback city behavior.

## 4. Media hierarchy and OSS readiness

- [ ] 4.1 Implement paginated reverse-reference media inventory across city/route/stop/fragment/story/pre-departure/narration usages, returning shared and unassigned classifications without inventing ownership; add query and authorization tests.
- [ ] 4.2 Add a sanitized provider-readiness audit reporting environment label, configured provider/base host, provider counts, published local references, missing metadata, bounded URL checks, and audit time; prove secrets and filesystem roots cannot appear.
- [ ] 4.3 Make production publication/release readiness reject newly published public media that resolves through the local asset route while keeping existing mixed local/OSS reads compatible during migration; add local, fake-OSS, mismatch, and unavailable-audit tests.
- [ ] 4.4 Re-run and, if needed, harden the existing `migrate-media --dry-run`/apply command against all newly referenced story and pre-departure roles; verify checksum idempotency, missing/orphan reporting, reference rollback, and no private-evidence migration.

## 5. Global Flutter audio session

- [ ] 5.1 Introduce a typed application-level audio session coordinator for `predeparture`, `city_story`, and `on_site`, then migrate current city-story and active-tour start/pause/replay/stop transitions without changing adapter responsibilities; add deterministic state-machine tests.
- [ ] 5.2 Enforce atomic source replacement, rapid-tap serialization, logout/account-switch cleanup, error recovery, and back-navigation continuation; add race and lifecycle tests proving at most one active audio source.
- [ ] 5.3 Drive the floating rotating orb from the unified session, including source-specific return context and consistent play/pause/ended state; add widget/navigation tests for all three source types.
- [ ] 5.4 Parse additive pre-departure audio metadata safely and support network/prepared playback with the existing repository/cache boundaries; test old payloads, missing audio, invalid URLs, and retry.

## 6. City manual, tags, and responsive discovery UI

- [ ] 6.1 Refactor route detail into a city-manual composition whose first eligible content is the concise pre-departure text plus one accessible play/pause/replay icon, with no large player, progress, seek, or duration controls; add configured/absent/error widget tests.
- [ ] 6.2 Render ordered free-form `experience_tags` for both legacy stops and managed fragments with a shared wrapping component, unknown-value support, and no empty placeholder; add model and widget tests proving tags do not affect home-card granularity/order.
- [ ] 6.3 Place the scenic/manual carousel and its indicator before city stories, remove device-specific overall fixed heights/offsets, and use content/viewport constraints plus normal sliver spacing; add regression tests for minimum supported phone, long bounded copy, safe areas, orientation, and 200% text scale.
- [ ] 6.4 Remove or redirect any separate client-facing “首页听故事” entry so current city-story cards reuse the unified detail/player, while preserving older deep links through compatibility routing; add navigation and semantics tests.

## 7. Cross-repository verification and production delivery

- [ ] 7.1 Complete and validate the same-named `Travel-Admin` change against the migrated main schema/API, including one scenic workspace, unified city stories, media hierarchy, and provider warning; record contract-version compatibility evidence.
- [ ] 7.2 Run backend Ruff/pytest/MySQL migration suites and Flutter format/analyze/test suites, then run `openspec validate unify-scenic-content-and-pretrip-experience --strict`; resolve all failures before deployment.
- [ ] 7.3 Audit production API/admin provider configuration without printing secrets, apply matching OSS settings idempotently, run media dry-run and reviewed migration, and verify all published city/scenic covers and narration roles resolve through OSS/CDN with correct MIME, range/read, size, and checksum.
- [ ] 7.4 Deploy main API migration/code before admin and mobile, smoke-test health, route detail, unified city stories, tag payloads, compatibility reads, media readiness, and rollback paths; do not disable local compatibility or delete media during burn-in.
- [ ] 7.5 Increment `mobile/pubspec.yaml`, build the production API APK with `TEST_AUTH_ENABLED=false`, verify manifest version/signature, and install-smoke pre-departure/orb switching, city stories, tags, responsive layout, existing journeys, and real/simulated location modes.
- [ ] 7.6 Inspect both worktrees, commit and push reviewed main/admin changes independently to their `main` branches, and deliver commit hashes, validation results, APK path/version, and exact idempotent deployment commands.
