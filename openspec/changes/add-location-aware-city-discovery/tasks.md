## 1. Minimal point metadata and public contract

- [x] 1.1 Add one main Alembic revision after `20260823_0011` for empty-default `experience_tags_json` on legacy stops and managed story fragments only; add upgrade/downgrade tests.
- [x] 1.2 Extend main ORM/domain mappings and existing content-graph/package normalization for point `experience_tags`, preserving current lifecycle and old-package compatibility.
- [x] 1.3 Add a compact published `scenic_spots` projection to the existing city discovery response using managed fragments or legacy stops, with point identity/title/coordinate/tags and minimal parent-route navigation data.
- [x] 1.4 Add API tests proving draft/unpublished points are excluded, managed and legacy projections do not duplicate content, arbitrary tags pass through, and no route tag/order/city-range field is introduced.

## 2. Flutter location and ranking

- [x] 2.1 Add typed scenic-spot parsing with empty-tag rolling-deployment defaults while keeping existing route detail models and ordering unchanged.
- [x] 2.2 Add a discovery-only bounded one-shot platform location/locality source; accept distance work only for fresh real samples with reported accuracy at most 25 metres and never start/read the journey location stream.
- [x] 2.3 Add pure generic locality normalization/matching against the backend city catalog, with Shenzhen fallback when no selectable city with published points matches; do not consume city coordinates or ranges.
- [x] 2.4 Add pure Haversine point ranking for the active city with server-order/stable-ID tie breaks and no-location fallback; do not rank routes or reorder route contents.
- [x] 2.5 Implement event-scoped discovery state: cold entry may select the matched city, refresh keeps the current city, and manual switch always keeps the chosen city; each event performs one fresh acquisition and stores no processed flag, mode, city preference, or coordinate.
- [x] 2.6 Add unit/controller tests for matched locality, unmatched/no-point Shenzhen fallback, refresh, switch precedence, <=25 m acceptance, >25 m rejection, permission/service/timeout failure, no stale distance, and simulated-journey isolation.

## 3. Flutter presentation

- [x] 3.1 Add concise Chinese location-purpose copy before the first undetermined OS permission request and keep the existing manual city selector usable after decline or denial.
- [x] 3.2 Preserve the current home card visual and route-opening action while presenting one published scenic/story point per card with backend tags and optional honest distance.
- [x] 3.3 Wire pull-to-refresh and city-switch completion to their single fresh location attempts; reset the carousel to the first distance-ranked point without changing route-detail/fragment order.
- [x] 3.4 Add widget tests for cold-entry city display, Shenzhen fallback, nearest point first, backend tag passthrough, manual switch precedence, failure usability, and absence of fake distance.
- [x] 3.5 Audit platform location purpose strings and logs; prove discovery persists/transmits/logs no raw position or calculated distance.

## 4. Cross-repository verification and release

- [x] 4.1 Complete the companion `Travel-Admin` change for stop/fragment tags only and verify it consumes, but does not create, the main migration.
- [x] 4.2 Run `ruff check app tests`, backend tests, Alembic smoke checks, Dart formatting, `flutter analyze`, and Flutter tests.
- [ ] 4.3 Update only the field/privacy/rollout documentation required for this change, bump the full mobile version, build and verify the production Android APK under the project release workflow.
- [x] 4.4 Run strict OpenSpec validation in both repositories and inspect both diffs for unrelated files, route-ranking work, city-range work, persistence modes, or secrets before separate reviewed commits.
