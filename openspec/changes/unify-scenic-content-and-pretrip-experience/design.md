## Context

See `proposal.md` for motivation. The main repository currently exposes route-scoped `RoutePretripGuidance`, city-story catalog projections, legacy `HomeStoryPublication`, stop/fragment `experience_tags`, local/OSS storage adapters, and an idempotent `migrate-media` command. Flutter renders pre-trip as a large section below route metadata, uses separate home-story and on-site playback controllers, and lets only on-site playback drive the floating orb. The discovery page currently places city-story modules before a route carousel whose card/list containers use fixed heights.

The public production payload observed during planning resolves covers and narration under `http://115.29.221.190:5001/api/v1/assets/...`. That is the legacy local-compatible path, not an OSS/CDN URL. SSH credentials were unavailable for a configuration-file audit, so implementation must perform a server-side provider audit before mutation; the externally visible URLs already establish that production public media migration is incomplete.

The independent `Travel-Admin` repository shares MySQL but owns no DDL. Its same-named companion change consumes the contracts defined here.

## Goals / Non-Goals

**Goals:**

- Keep one route/scenic-area aggregate as the owner of pre-departure content while making that relationship explicit in API and CMS projections.
- Unify playback state without putting audio adapters or UI navigation into domain models.
- Reuse canonical city-story and narration identities during migration.
- Derive media ownership from actual references and make production storage truth machine-checkable.

**Non-Goals:**

- Re-key existing routes, stops, fragments, journeys, or media assets.
- Make the admin service a schema owner or introduce another content microservice.
- Remove local storage support from development/tests or delete legacy objects during the initial migration.

## Decisions

### 1. Treat `Route` as the scenic-area compatibility boundary

User-facing copy changes from route to 景点 where the object represents a scenic attraction, but API IDs and persistence keep the existing route identity. `RoutePretripGuidance` remains the lifecycle owner. It gains a versioned concise introduction script and matching narration metadata/tracks, or an equivalent normalized child record if the existing table cannot preserve track history cleanly. Publication requires a non-empty bounded script, transcript hash/script version, and one approved track matching that hash. The route detail returns a compact `predeparture` projection before the existing deeper `pretrip` guidance fields; compatibility serializers may also populate the former from an eligible existing theme-story short variant.

Alternative considered: attach an introduction to every fragment. Rejected because the requested CMS location and manual entry are scenic-level, and per-fragment introductions would multiply content and playback before every stop.

### 2. Use one application-level audio session coordinator

Introduce a session state with a typed source (`predeparture`, `city_story`, or `on_site`), source identity, route/journey context, phase, and return location. Existing audio adapters remain responsible for bytes and platform playback, while the coordinator serializes stop/prepare/play transitions and exposes one state to inline controls and the orb. Starting a new source stops the current adapter before publishing the new active state. Back navigation does not stop an eligible source; explicit stop, replacement, logout/account switch, or unrecoverable error does.

Alternative considered: teach the orb to inspect both existing controllers. Rejected because competing asynchronous states can both claim playback and it does not scale to pre-departure as a third source.

### 3. Render the manual as content-led sections, with pre-departure first

The route page becomes a semantic manual composition: hero/identity, first pre-departure surface when published, summary metrics, then deeper story/map/node content and the start action. The inline audio control is an icon button with play/pause/replay semantics and error feedback; it intentionally has no seek/progress widget. Node components render `experience_tags` from both stop and fragment projections using a shared wrapping chip component.

Alternative considered: a separate pre-departure route/page before the manual. Rejected because it would add navigation and duplicate the initial route detail the user asked to combine.

### 4. Migrate legacy home publications into the city-story catalog by reference

An idempotent migration/application command keys each legacy publication by canonical source kind/id. It creates or reuses the catalog item, adds a presentation variant pointing to the existing selected approved track, and adds the appropriate city-home placement. Presentation title/introduction/cover are retained as catalog presentation metadata. `/stories/random` becomes a compatibility query over eligible unified catalog items; legacy write operations become read-only/delegating before later removal. No transcript or object copy occurs.

Alternative considered: keep both tables editable and merge only in Flutter. Rejected because publication state and track selection would continue to drift.

### 5. Derive media hierarchy from reverse references

The backend/admin projection joins `media_assets` to city covers, route covers, stops, fragments, narration tracks, story variants, pre-departure tracks, and other public editorial references. It returns one asset with a list of typed usages and derived city/route scopes. Multiple scopes mark the asset shared; zero usages mark it unassigned. This avoids adding a false single-owner foreign key to reusable assets.

The provider audit reports configured public provider, canonical base host (never credentials), counts by provider, published local references, missing metadata, and a bounded representative URL check. Production readiness fails for new public publication while local references remain. Existing published local content stays readable during migration but is reported as a release blocker.

Alternative considered: move files into city/route directory keys to imply ownership. Rejected because object paths are storage details, shared media would be duplicated, and renaming a city would force object moves.

### 6. Make discovery layout intrinsic and ordered

The scenic/manual carousel is rendered before city stories. Card internals use bounded aspect ratios/minimum constraints and flexible text rather than one overall hard-coded height; the page indicator is part of the same column. A normal sliver gap separates its measured end from city stories. Golden/widget tests cover compact height, narrow width, long allowed copy, and 200% text scaling.

Alternative considered: add a larger fixed top/bottom offset. Rejected because it reproduces the overlap on another screen or font scale.

### 7. Keep module and API failure boundaries explicit

- Catalog application: pre-departure eligibility and unified city-story projection.
- Journey/audio application: active audio arbitration and return context, without content mutation.
- Media application: reverse-reference inventory and provider readiness.
- Presentation API: additive projections and compatibility shapes; no credentials or filesystem roots.
- Flutter data/domain: typed additive parsing with absent-field fallback for rolling deployment.

If pre-departure fails, the manual remains readable. If story compatibility migration finds an ambiguous source/track, it records a blocker and leaves the old publication readable until resolved. If OSS audit cannot verify a URL, it fails readiness without deleting or rewriting the asset.

## Risks / Trade-offs

- [A shared audio coordinator touches mature playback paths] → Add state-machine and rapid-switch tests first, retain adapter contract tests, and roll out pre-departure after city-story/on-site parity passes.
- [Legacy home story metadata may not satisfy catalog publication rules] → Dry-run classifies ready, conflicted, and blocked records with field-level remediation; do not invent missing facts or sources.
- [Production contains mixed local/OSS records] → Keep reads compatible, block new local publication, migrate by checksum in batches, and verify references before disabling any local path.
- [Intrinsic cards can grow excessively with malformed copy] → Enforce backend length bounds and use accessible truncation/expansion rules tested at large text scale.
- [Derived media inventory queries become expensive] → Return paginated summaries/counts and load resource details per selected city/scenic area with indexed reference lookups.

## Migration Plan

1. Add backend schema/compatibility reads for versioned pre-departure script and tracks; deploy API that tolerates absent data and preserves current route/pretrip responses.
2. Add the audio coordinator and migrate existing city-story/on-site state behind tests, then add pre-departure UI, tags, and intrinsic discovery layout.
3. Dry-run legacy home-story-to-catalog mapping, resolve blockers, apply idempotently, switch public and CMS reads, and leave legacy reads delegating during observation.
4. Deploy the CMS companion after the main migration/API is compatible.
5. On production, audit both services' provider settings without printing secrets; configure matching OSS values, run `migrate-media --dry-run`, review missing/orphan/conflict output, then run the migration.
6. Verify every published city/scenic sample and all narration roles return OSS/CDN URLs with correct MIME/range/checksum; retain local files as rollback copies during burn-in.
7. Release the Flutter APK only after API compatibility, unified story projection, tag display, responsive layout, and OSS readiness checks pass.

Rollback disables the new Flutter surfaces via compatible absence/empty projections, restores legacy story reads, and leaves local asset serving in place. It never deletes migrated OSS objects, local rollback copies, or database columns during the first rollback window.
