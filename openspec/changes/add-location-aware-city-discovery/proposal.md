## Why

The discovery page currently opens with a fixed default city and backend route order. It cannot use one current-position check to choose a useful city on entry or put the closest published scenic/story point first. Requirement one needs this behavior without adding city-boundary configuration, route recommendation rules, accuracy gating, or location tracking.

## What Changes

- On each cold app entry to discovery, explain the location purpose and request one real current position. A successful position participates in ordering regardless of its reported accuracy.
- Resolve the initial city from the platform-provided locality and the backend-provided selectable city catalog. If that locality has no selectable city with published scenic/story points, keep the existing Shenzhen default.
- Do not use city center coordinates, city radii, city polygons, or distance-to-city matching.
- On home refresh, acquire one fresh position and distance-sort only the current city's published scenic/story cards.
- After a manual city switch, keep the selected city, acquire one fresh position, and distance-sort that city's published scenic/story cards. Location never overrides a manual switch.
- Preserve the current home card layout and route-opening behavior, but make the card's recommended subject a published scenic/story point rather than a route. Do not reorder points inside a route or change journey behavior.
- Add backend-configured free-form experience tags only to scenic/story points and pass them through the existing publication flow.
- If permission, service, geocoding, or acquisition fails, keep discovery usable, retain the current/default city and backend order, and show no fabricated distance.
- Keep every discovery position sample transient; do not persist a first-run marker, selected mode, coordinates, or a continuous trail.

### Non-goals

- No route recommendation, route ranking field, route-detail reordering, journey-location change, or route-card redesign.
- No city recognition radius, city boundary, city-coordinate matching, reverse-geocoding service on the backend, or city-range editor.
- No automatic/manual discovery mode, persisted manual-city preference, “restore automatic mode” action, or first-location-processed flag.
- No tags on routes, no tag taxonomy, and no requirement-two or later product work.

### MVP validation goals

- A cold entry with a successfully acquired location selects a matching backend city that has published scenic/story points; otherwise it shows Shenzhen.
- Refresh and manual city switch each perform one fresh location attempt and sort only the active city's home scenic cards by point distance.
- The nearest published point is the first home card; route contents retain their existing order after the card is opened.
- Denied or unusable location never blocks the app and never causes a fake or stale distance to appear.
- Arbitrary backend point tags render without a Flutter code change.

## Capabilities

### New Capabilities

- `location-aware-city-discovery`: Defines cold-entry city fallback, refresh/switch location attempts, point-distance sorting without accuracy gating, and privacy/failure behavior.

### Modified Capabilities

- `route-discovery`: Exposes published scenic/story point summaries and point tags needed by the existing home card surface without introducing route recommendations.
- `experience-client`: Adds the location-purpose prompt, nearest-point home ordering, backend tags, and truthful degraded presentation.

## Impact

- Main API: additive point-tag storage and a compact published scenic/story point projection in the existing city discovery response.
- Flutter: one-shot platform location/locality adapter, distance ranking for home scenic cards, city fallback behavior, and permission/failure UI.
- Independent `Travel-Admin`: matching point-tag mapping and editing only; the main repository remains migration authority.
- Existing route detail, journey, story progression, city selector options, and card visual structure remain in place.
