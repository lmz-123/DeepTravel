## Context

See `proposal.md` for motivation. The main repository already owns the Flask/MySQL content model, publication lifecycle, Flutter client, managed story fragments, complete `StoryArc` content, approved narration tracks, home-story publication, media descriptors, route detail, and a stable-ID single-route importer. The independent admin service maps these tables but must not own DDL. The active `expand-community-story-and-city-experience` change is therefore a prerequisite: this change extends its canonical story and playback work rather than creating a parallel player or transcript store.

Requirement one remains independent. Its current-city point ordering may consume location, but favorites, home story placements, and recommended roaming order introduced here must not affect that ordering.

## Goals / Non-Goals

**Goals:**

- Add a distribution layer that references, but never duplicates, canonical fragment or story-arc content.
- Return five editorial home module slots and a pre-trip projection from published content.
- Preserve arbitrary backend-provided themes and tags through API and Flutter presentation.
- Provide account-isolated favorites and explicit offline preparation.
- Extend the existing importer into a previewable, atomic multi-city graph import without breaking single-route packages.

**Non-Goals:**

- General recommendation ranking, preference inference, live weather retrieval, social favorites, or route navigation redesign.
- A new authoring format for the canonical transcript, a second audio player, or a replacement for existing lifecycle services.
- Automatic publication, remote media ingestion, or partial-success multi-city imports.

## Decisions

### 1. Reference canonical stories through a typed distribution record

A `story_catalog_item` identifies a canonical source with `(source_kind, source_id)`, where the initial source kinds are managed story fragment and complete story arc. It stores distribution metadata only: public title/summary/cover overrides where allowed, city/district/theme/point/story relations, type, observable detail, optional attention hint, and eligibility flags. Related-story order is advisory metadata only. Transcript text and narration bytes remain owned by the canonical source.

Channel presentation variants provide `short_preview` and `on_site_complete` roles. Each variant points to an existing reviewed fragment/arc representation and approved narration track in the catalog item's canonical lineage; it never stores copied text or media. A fragment-only catalog item can omit the complete role. An arc-backed item can use an approved related fragment/excerpt for the short role and the arc track for the complete role. Home and pre-trip default to the short role when present, while on-site defaults to the complete role; each placement can only select a valid reviewed role.

The record and variants capture the approved source revision/hash and narration revision used at review time. A canonical update makes affected variants and placements non-publishable until they are reviewed against the new revision. This prevents apparently shared stories from silently serving unrelated or stale text/audio while still supporting intentional short and complete forms.

Alternative considered: copy transcript and audio into a home/pre-trip story table. Rejected because manual and imported updates would drift across channels.

### 2. Use explicit placements for fixed product modules and generic content values

`story_placement` connects a catalog item to a channel, module key, optional route, editorial order/weight, lifecycle state, and active window. The five required home module keys are stable presentation slots, with `today_city_story` marked as the primary home entry; story type, theme, companion tag, and other content labels remain string/catalog backed and are returned with display labels. Unknown content values survive serialization and render generically in Flutter.

“今天适合去哪儿” is editorial content for the current city. It does not inspect live weather or compute personalization. A city-home endpoint returns module objects even when empty, plus an explicit reason, configured fallback cities/content, and the existing switch-city action metadata.

Alternative considered: infer modules from story types on the client. Rejected because module policy and empty-state behavior would become client-hardcoded.

### 3. Build public projections only from approved canonical and placement state

Public queries require the canonical source, selected presentation variant, narration/media references, catalog item, placement, city, and related route/point to satisfy their respective publication rules. They return a stable story identity, canonical revision, and selected variant role so the shared listening/reading route can be reused from home, pre-trip, on-site, and post-trip surfaces. Sources and fact status are exposed in an appropriate public form; internal review notes remain private.

Duration is derived from approved audio metadata when available, otherwise from the transcript estimate. Three to eight minutes produces an editorial warning only. Structural, source, fact, relation, canonical-version, and media failures remain hard publication blockers.

Alternative considered: make duration a hard gate. Rejected because the requirement describes it as guidance and legitimate complete reconstructions can be longer.

### 4. Extend route detail with a pre-trip projection

Route detail gains a pre-trip projection containing the theme story, story directions, advisory order, companion tags, safety/rest/accessibility/weather-adaptation editorial tips, and eligible offline resources. It composes canonical catalog stories rather than embedding copied bodies. Pre-trip access is independent of arrival and journey state; existing on-site progression rules remain unchanged.

Offline preparation is explicit. A resource manifest contains version, checksum, size, media/text kind, and authenticated/public download reference. Flutter stores only verified eligible resources, reports partial failures, and invalidates stale revisions. Weather-adaptation tips are edited content, not forecasts.

Alternative considered: download all route media automatically. Rejected to avoid unexpected storage/network use and to preserve user choice.

### 5. Store favorites as account-owned typed references

`traveler_favorite` uses `(user_id, target_kind, target_stable_id)` as a unique key for city, point, or theme targets. Create/delete operations are idempotent. Public reads resolve only published targets; unavailable targets return a minimal tombstone that supports removal and exposes no draft fields. Favorites are not inputs to location sorting or module ranking.

Alternative considered: local-only favorites. Rejected because the requirement implies a durable user collection and account isolation provides predictable cross-device behavior.

### 6. Normalize manual and JSON writes into the same commands

The multi-city package has a package ID, schema version, content version, checksum, and arrays/maps of stable-ID entities. Media entries are descriptors referencing existing managed media plus checksum/metadata; binary data and arbitrary remote fetches are rejected. A shared normalization layer converts both existing single-route packages and multi-city packages into the same domain commands used by manual administration.

Dry-run parses and normalizes the whole graph, validates schema and field paths, resolves relations/media/lifecycle constraints, compares record revisions, and returns `new`, `updated`, `unchanged`, `conflicted`, or `invalid` diffs. It creates only an import-preview/audit record, not content records. The returned confirmation token is bound to package checksum, editor, expiry, and target revision snapshot.

Confirm revalidates the token and target revisions, then runs all content mutations in one database transaction. Imported content is draft or the applicable pre-publication state even if the package asks for placement/publication. Any error rolls back the whole package. Replaying the same package ID/version/checksum is unchanged/idempotent; reuse with a different checksum is a conflict.

Alternative considered: best-effort per-city writes. Rejected because cross-city media and story relations could leave an internally inconsistent partial graph.

### 7. Keep module boundaries explicit

- Content domain: canonical source resolution, catalog metadata, relations, facts, placements, and publication invariants.
- Discovery application: published city-home and pre-trip projections only.
- Identity/favorites: authenticated typed-reference commands and queries.
- Import application: package parsing, normalization, diff planning, confirmation, and audit; it calls content application services rather than writing tables ad hoc.
- Flutter presentation: module rendering, shared story player/reader navigation, favorite controls, and offline manifest ownership.
- Admin companion: editing and import orchestration; migrations remain in this repository.

Public endpoints are versioned additions or backward-compatible field additions. Existing `/stories/random`, route detail, managed fragments, home story publication, and single-route import remain available while their internals delegate to shared projections where safe.

## Risks / Trade-offs

- [Canonical source revisions can invalidate many placements] → Show dependency/blocker counts in admin, invalidate deterministically, and support batch re-review without auto-approval.
- [A multi-city dry-run can be expensive] → Enforce file/entity limits, stream upload to bounded temporary storage, prefetch stable IDs in batches, and expire preview tokens.
- [Target data can change between preview and confirmation] → Bind the confirmation token to target revisions and fail atomically with explicit conflicts.
- [Flexible tags can produce inconsistent wording] → Preserve free values for client independence while offering normalized admin suggestions and validation warnings.
- [Offline content can become stale or consume storage] → Use checksums/versioned manifests, explicit user action, per-route status, retry, and removable cached resources.
- [Two repositories can diverge] → Land main migration/API contracts before admin mappings and validate companion OpenSpec changes together.

## Migration Plan

1. Complete and retain compatibility with the active canonical story/listening change.
2. Add nullable catalog, placement, relation, guidance, favorite, and import-audit tables/columns in the main repository; deploy with no public placements.
3. Backfill catalog references for existing eligible home story publications without copying transcript/audio and verify canonical hashes.
4. Deploy admin mappings/editors and import dry-run behind permissions/feature flags.
5. Deploy public home/pre-trip/favorite APIs and Flutter generic rendering/offline preparation; existing home story behavior remains the fallback during rollout.
6. Configure, review, and explicitly publish initial module placements city by city.
7. Roll back by disabling new endpoints/flags and placements first; retain additive tables and audit data until a later safe cleanup migration.
