## 1. Minimal point metadata and public contract

- [x] 1.1 Add one main Alembic revision after `20260823_0011` for empty-default `experience_tags_json` on legacy stops and managed story fragments only; add upgrade/downgrade tests.
- [x] 1.2 Extend main ORM/domain mappings and existing content-graph/package normalization for point `experience_tags`, preserving current lifecycle and old-package compatibility.
- [x] 1.3 Remove the obsolete flat `scenic_spots` home projection and add one nullable derived `center` to each existing published route/scenic-area summary, using managed published fragment regions or legacy stop coordinates without a schema migration.
- [x] 1.4 Add API tests proving one home summary is returned per published scenic area, center derivation works for managed and legacy content, internal nodes are not emitted as home siblings, and no persistent route order/city-range field is introduced.

## 2. Flutter location and ranking

- [x] 2.1 Remove the obsolete home `ScenicSpot` projection/card model, parse optional centers on existing route summaries, and keep route detail/node models and ordering unchanged.
- [x] 2.2 Remove discovery accuracy gating so every successful bounded one-shot real position participates in distance work; never start/read the journey location stream.
- [x] 2.3 Add pure generic locality normalization/matching against the backend city catalog, with Shenzhen fallback when no selectable city with published scenic areas matches; do not consume city coordinates or ranges.
- [x] 2.4 Add pure Haversine scenic-area-center ranking for the active city with server-order/stable-route-ID tie breaks, centered-before-uncentered handling, and no-location fallback; never rank or surface internal nodes.
- [x] 2.5 Reconcile event-scoped discovery state with route/scenic-area cards: cold entry may select the matched city, refresh keeps the current city, and manual switch always keeps the chosen city; each event performs one fresh acquisition and stores no processed flag, mode, city preference, or coordinate.
- [x] 2.6 Update unit/controller tests to prove low/high/missing reported accuracy never changes scenic-area ordering, while permission/service/timeout/acquisition failure, no stale distance, node containment, and simulated-journey isolation remain covered.

## 3. Flutter presentation

- [x] 3.1 Add concise Chinese location-purpose copy before the first undetermined OS permission request and keep the existing manual city selector usable after decline or denial.
- [x] 3.2 Restore the original one-card-per-route/scenic-area home carousel and route-opening action, with optional honest center distance; remove every homepage title/favorite/tag treatment that independently represents a story node.
- [x] 3.3 Wire pull-to-refresh and city-switch completion to their single fresh location attempts; reset the carousel to the first distance-ranked scenic area without changing route-detail/fragment order.
- [x] 3.4 Update widget/copy coverage to remove the accuracy warning and retain cold-entry city display, Shenzhen fallback, nearest scenic area first, original route card content, manual switch precedence, failure usability, node containment, and absence of fake distance.
- [x] 3.5 Audit platform location purpose strings and logs; prove discovery persists/transmits/logs no raw position or calculated distance.

## 4. Cross-repository verification and release

- [x] 4.1 Complete the companion `Travel-Admin` change for stop/fragment tags only and verify it consumes, but does not create, the main migration.
- [x] 4.2 Re-run `ruff check app tests`, backend tests, Alembic smoke checks, Dart formatting, `flutter analyze`, and Flutter tests after restoring scenic-area cards and center ranking.
- [x] 4.3 Update only the field/privacy/rollout documentation required for this change, bump the full mobile version, build and verify the production Android APK under the project release workflow.
- [x] 4.4 Re-run strict OpenSpec validation in both repositories and inspect both diffs for unrelated files, flat home-node projections, city-range work, persistence modes, accuracy gating, or secrets before the follow-up commit.
