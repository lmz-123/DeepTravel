## Context

The backend already supplies the selectable published-city catalog and stores WGS-84 coordinates for legacy stops and managed story fragments. The Flutter discovery page already has a backend-driven city selector and a route-card carousel, but it defaults to Shenzhen and does not rank the home choices by the traveler's current position. The existing journey tracker is continuous and must not be reused for discovery.

The requested behavior is intentionally small: location affects the initial default and home-card order. It does not introduce a persistent discovery mode, city-coverage model, or any reordering after a route is opened.

## Goals / Non-Goals

**Goals:**

- Use one high-accuracy platform position on cold discovery entry, refresh, and city switch.
- Select the initial city only when the platform locality matches a backend-selectable city with published points; otherwise use Shenzhen.
- Sort published scenic/story point cards for the active city by geodesic distance.
- Keep point tags fully backend-driven and location samples transient.

**Non-Goals:**

- No city center/radius/polygon configuration or distance-based city recognition.
- No route recommendations, route order field, card redesign, or route-internal point sorting.
- No persistence of discovery mode, manual city, prompt suppression, first-run completion, coordinates, or distances.
- No change to simulated/real journey settings, arrival checks, free-roam triggers, or later requirements.

## Decisions

### 1. Initial city uses platform locality plus the existing backend catalog

On cold entry, discovery asks for one real high-accuracy position and resolves its administrative locality through the platform location stack. A pure normalizer compares that locality with the names of cities already returned by the backend's selectable city catalog. Generic normalization may remove administrative suffixes such as `市`; Flutter does not contain a city list.

The locality is accepted only when the matched backend city has at least one published scenic/story point in the discovery payload. If locality is unavailable, unmatched, or has no published point, discovery uses the project's existing Shenzhen default. This design never reads a city center, recognition radius, or boundary and never calculates distance from the user to a city.

The same automatic city choice is not rerun after a manual switch. Location acquired for refresh or switching is used only to sort the already active city.

### 2. Location attempts are event-scoped and require 25-metre accuracy

Create a discovery-only `CurrentLocationSource` with a bounded one-shot operation returning a real platform position and optional locality. Invoke it only for:

1. cold entry to the discovery page;
2. an explicit home refresh;
3. completion of a manual city switch.

Only a fresh sample whose reported horizontal accuracy is at most 25 metres can produce distance ordering or distance labels. An inaccurate, denied, disabled, timed-out, or failed attempt is treated as unavailable. Discovery never starts the journey stream and never substitutes simulated journey coordinates.

No first-entry-processed value is persisted. “Cold entry” is an in-memory page/application lifecycle event, not an installation-history flag.

### 3. The home response exposes scenic points, not route recommendations

Extend the existing city discovery response with a flat compact `scenic_spots` projection built only from formally published content. Each item contains the point's stable ID, title, WGS-84 coordinate, ordered free-form `experience_tags`, and the minimal parent-route identity needed by the existing tap flow.

Managed routes project eligible story fragments; legacy routes project eligible stops. The projection does not add route order, route tags, point recommendation order, transcripts, journey state, or editorial fields.

Flutter renders one home card per projected point using the current route-card visual structure. A tap continues into the point's parent route through the existing route navigation. Thus the recommended object is the scenic/story point even though the familiar card shell and route entry remain.

### 4. Ranking is local, scoped to the selected city, and does not leak inward

For an accepted sample, a pure Flutter service calculates Haversine distance to every projected point in the active city and sorts ascending by unrounded metres. Exact ties use the server response order followed by stable point ID. The first home card is therefore the closest published point.

On refresh, the active city is unchanged. On manual switch, the user's chosen backend city is applied before acquisition and cannot be replaced by locality. Ranking affects only the home carousel. Route details, fragment/stop position, and journey progression remain untouched.

Without an accepted sample, the client preserves server response order and omits all distance copy. A prior event's sample is not reused after a refresh or switch failure.

### 5. Tags live only on point records

Add `experience_tags_json` to `stops` and `story_fragments`, defaulting to an empty JSON array. Do not add tags or a discovery-order field to routes. Admin and existing package/graph paths expose the editorial name `experience_tags` and normalize by trimming, removing empty values, and de-duplicating in first-occurrence order. Tags remain arbitrary display strings subject only to modest shape/length limits.

The ten product examples are fixtures/help text, not a client enum or server allowlist. Only published point values reach the public projection.

### 6. Failure remains the current simple discovery behavior

Before an undetermined OS permission request, show concise Chinese purpose copy explaining city choice and nearby-point ordering. Declining or denial leaves the city selector and normal browsing available.

On cold-entry failure, retain Shenzhen and server order. On refresh or switch failure, retain the selected city and server order. No state asks the user to enable an automatic mode, and no repeated-prompt suppression preference is added beyond the operating system's permission state.

### 7. Privacy boundary

Coordinates, accuracy, locality, sample timestamps, and calculated distances exist only in transient client memory. They are not sent to the API/admin service, persisted, or written to logs/analytics. Logs may record only a coarse outcome category. Disposing or replacing the ranking state releases the prior sample.

## API and Module Boundaries

- Backend catalog: filters published cities/points and serializes compact point metadata; it never receives traveler coordinates.
- Main Alembic: owns the two additive point-tag columns.
- Flutter discovery domain: owns locality matching, quality checks, Haversine ranking, and stable fallback.
- Flutter presentation: owns purpose/failure copy, the existing city selector, and the retained card visual.
- Journey location: remains unchanged and is not a discovery dependency.
- Independent admin: edits matching point tags and consumes the main migration without creating one.

## Failure Behavior

- Missing point tags from an older API parse as `[]`.
- Missing/invalid point coordinates exclude only that point from distance ordering; the point remains available in server order without a distance.
- A failed catalog refresh retains known city/content state and exposes the existing retry path.
- A city switch succeeds even when the subsequent location attempt fails.
- If Shenzhen is temporarily absent from the selectable catalog, retain the current valid catalog selection rather than inventing another city identifier.

## Risks / Trade-offs

- [Platform locality names can differ from backend display names] → Apply generic administrative-suffix normalization; unmatched results deliberately fall back to Shenzhen rather than adding a city-coordinate system.
- [25-metre accuracy may be unavailable indoors] → Fall back to server order and omit distance instead of accepting imprecise data.
- [A point card still opens a parent route] → Keep the existing navigation contract while ensuring the home title/tags/distance describe the point, not a newly ranked route.
- [Two point storage models exist] → Add the same tag field to stops and fragments, project managed fragments first and legacy stops only for legacy routes.

## Migration Plan

1. Add the main Alembic revision for stop/fragment point tags and update compatible API mappings/projection.
2. Deploy the API migration and response before the independent admin and Flutter client.
3. Deploy admin point-tag support; existing import/export paths preserve the new field without adding a new import feature.
4. Ship the Flutter client, then verify cold-entry match/fallback, refresh, city switch, 25-metre gating, nearest-first point cards, tag passthrough, and denial fallback.
5. Roll back application versions without dropping the additive tag columns.
