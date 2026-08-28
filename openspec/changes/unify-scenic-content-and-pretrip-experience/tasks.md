## 1. Baseline and additive content contracts

- [x] 1.1 Capture regression fixtures for current route detail/pretrip, legacy random home story, unified city-story home, stop/fragment tags, media URLs, on-site playback, and floating-orb behavior before changing contracts.
- [ ] 1.2 Add a reversible Alembic migration owned by the main repository for versioned route pre-departure introduction text and narration tracks/provenance, preserving existing `route_pretrip_guidance` rows and mixed-version reads; verify MySQL upgrade/downgrade and data retention.
- [x] 1.3 Extend SQLAlchemy/domain/repository mappings with transcript hash, script version, selected/approved track, lifecycle metadata, and safe public media resolution; add mapping tests for absent, draft, stale, and published records.
- [ ] 1.4 Define additive public/admin-compatible `predeparture`, scenic media inventory, and provider-readiness response schemas with bounded text/list sizes and no credentials, raw filesystem roots, or private canonical references; add schema/serialization tests.

## 2. Scenic pre-departure application behavior

- [ ] 2.1 Implement route-scoped pre-departure create/update/review/publish eligibility so text edits invalidate mismatched narration and draft content never enters public route detail; test every allowed/rejected state.
- [x] 2.2 Extend route detail with the published concise introduction and approved audio independent of location/journey state, while preserving existing deeper pretrip/offline fields and old-client response compatibility; add API tests for configured, absent, stale, and unavailable audio.
- [ ] 2.3 Extend route narration/media validation to include pre-departure tracks, exact script/hash matching, approved profile metadata, MIME/checksum/size, and safe URL resolution; test publication blockers and rollback behavior.
- [ ] 2.4 Add content-package/import/export round-trip support for pre-departure text and approved media references without embedded binary or arbitrary remote fetches; verify idempotency and field-specific validation errors.

## 3. Unified city-story source and migration

- [ ] 3.1 Implement a dry-run-capable idempotent mapper from eligible `home_story_publications` to canonical story-catalog items, approved variants, and city-home placements keyed by source identity; report ready/conflicted/blocked records and prove no transcript/media copy.
- [ ] 3.2 Apply the mapping transactionally with stable IDs and optimistic revision checks, retain audit output, and test repeat, partial-retry, stale-track, missing-source, and rollback cases.
- [x] 3.3 Switch city-story collection/detail and random selection to the unified eligible catalog projection while preserving documented legacy read response shapes; make legacy writes delegate or reject as read-only and add compatibility tests.
- [x] 3.4 Update seed/demo/package fixtures to expose one “城市故事” source and remove duplicate client-facing home-listening placement without hardcoded production story IDs; test empty/fallback city behavior.
- [x] 3.5 Through the companion Admin API, generate and bind canonical city-story narration from the minimal editor, approve/publish the matching track with catalog lifecycle, and add one reviewed educational Shenzhen story without duplicate transcript or media identity.
- [x] 3.6 Preserve one operator-managed public cover on unified city-story collection/detail projections and verify cover-only changes do not revise transcript or narration identity.

## 4. Media hierarchy and OSS readiness

- [ ] 4.1 Implement paginated reverse-reference media inventory across public editorial media, narration, pre-departure, community media, user photos, footprints, evidence, and temporary previews, returning authorized scopes plus shared/unassigned classifications without inventing ownership; add query and privacy tests.
- [x] 4.2 Remove local runtime storage selection and persistent media mounts from API/config/compose paths, require complete public/private OSS plus CDN configuration in development, test, admin-connected, and production runtimes, and fail startup/readiness without it; retain only injectable in-memory fakes for unit tests and add fail-closed tests.
- [ ] 4.3 Define production/test completely shared public/private buckets, identical canonical object keys, media references, CDN base, and private-access behavior, plus a least-privilege expiring prefix only for disposable integration-test fixtures; add fake/policy integration tests proving no environment-specific business-media copies exist and fixtures cannot overwrite or delete canonical objects.
- [ ] 4.4 Add a sanitized OSS-readiness audit reporting environment label, safe public/private resource identity, CDN host, public/private counts, production/test public/private key-checksum agreement, local references/reads/mounts, missing metadata, bounded public/private access checks, and audit time; prove credentials, permanent private URLs, and filesystem roots cannot appear.
- [ ] 4.5 Expand `migrate-media --dry-run`/apply to every public and private persistent category, migrate by checksum with ownership/scope preservation, reconcile database/object counts and orphans, redirect compatible legacy public asset URLs to CDN, then disable local reads/mounts; verify idempotency, authorization, rollback-before-commit, and OSS-only cutover.
- [x] 4.6 Normalize public editorial image uploads to JPEG quality 85 and migrate all currently referenced public PNG city/scenic/stop/story covers to new immutable JPEG objects with transactional reference reconciliation and rollback-object retention.

## 5. Global Flutter audio session

- [ ] 5.1 Introduce a typed application-level audio session coordinator for `predeparture`, `city_story`, and `on_site`, then migrate current city-story and active-tour start/pause/replay/stop transitions without changing adapter responsibilities; add deterministic state-machine tests.
- [ ] 5.2 Enforce atomic source replacement, rapid-tap serialization, logout/account-switch cleanup, error recovery, and back-navigation continuation; add race and lifecycle tests proving at most one active audio source.
- [ ] 5.3 Drive the floating rotating orb from the unified session, including source-specific return context and consistent play/pause/ended state; add widget/navigation tests for all three source types.
- [x] 5.4 Parse additive pre-departure audio metadata safely and support network/prepared playback with the existing repository/cache boundaries; test old payloads, missing audio, invalid URLs, and retry.

## 6. City manual, tags, and responsive discovery UI

- [x] 6.1 Refactor route detail into a city-manual composition whose first eligible content is the concise pre-departure text plus one accessible play/pause/replay icon, with no large player, progress, seek, or duration controls; add configured/absent/error widget tests.
- [x] 6.2 Render ordered free-form `experience_tags` for both legacy stops and managed fragments with a shared wrapping component, unknown-value support, and no empty placeholder; add model and widget tests proving tags do not affect home-card granularity/order.
- [x] 6.3 Place the scenic/manual carousel and its indicator before city stories, preserve the established 505/276 default scenic-card visual baseline while allowing measured accessibility growth, remove device-specific overall section offsets, and use normal sliver spacing; add regression tests for the default baseline, minimum supported phone, long bounded copy, safe areas, orientation, and 200% text scale.
- [x] 6.4 Remove or redirect any separate client-facing “首页听故事” entry so current city-story cards reuse the unified detail/player, while preserving older deep links through compatibility routing; add navigation and semantics tests.
- [x] 6.5 Include configured pre-departure narration in the same scenic coverage and generate-missing/regenerate-all batch as later story nodes; verify combined counts and current/stale matching.

## 7. Cross-repository verification and production delivery

- [ ] 7.1 Complete and validate the same-named `Travel-Admin` change against the migrated main schema/API, including one scenic workspace, unified city stories, media hierarchy, and provider warning; record contract-version compatibility evidence.
- [ ] 7.2 Run backend Ruff/pytest/MySQL migration suites and Flutter format/analyze/test suites, then run `openspec validate unify-scenic-content-and-pretrip-experience --strict`; resolve all failures before deployment.
- [ ] 7.3 Provision and audit one public OSS bucket/CDN plus one private OSS bucket used identically by production/test without printing secrets, apply the same canonical resource configuration to API/admin in both runtimes, restrict only disposable integration-test fixture writes to a temporary prefix, and run reviewed full public/private migration.
- [ ] 7.4 Verify all database media/evidence references and OSS objects reconcile; public samples use the same CDN URL with correct MIME/range/size/checksum, private samples resolve the same object keys through the same authorization/short-signing behavior, production/test have no environment-specific business-media copies, and no local reference/read/mount remains.
- [ ] 7.5 Deploy main API migration/code before admin and mobile, smoke-test health, route detail, unified city stories, tag payloads, compatibility CDN redirects, private access, media readiness, and rollback paths; never re-enable local persistence or delete OSS objects during burn-in.
- [ ] 7.6 Increment `mobile/pubspec.yaml`, build the production API APK with `TEST_AUTH_ENABLED=false`, verify manifest version/signature, and install-smoke pre-departure/orb switching, city stories, tags, responsive layout, existing journeys, shared CDN assets, private media access, and real/simulated location modes.
- [ ] 7.7 Inspect both worktrees, commit and push reviewed main/admin changes independently to their `main` branches, and deliver commit hashes, validation results, APK path/version, and exact idempotent OSS configuration/migration/deployment commands.
