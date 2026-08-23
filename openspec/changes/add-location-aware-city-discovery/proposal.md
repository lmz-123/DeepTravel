## Why

The discovery page currently opens with a fixed default city and backend scenic-area order. It cannot use one current-position check to choose a useful city on entry or put the closest published scenic area first. Requirement one needs this behavior without adding city-boundary configuration, node recommendation rules, accuracy gating, or location tracking.

## What Changes

- On each cold app entry to discovery, explain the location purpose and request one real current position. A successful position participates in ordering regardless of its reported accuracy.
- Resolve the initial city from the platform-provided locality and the backend-provided selectable city catalog. If that locality has no selectable city with published scenic areas, keep the existing Shenzhen default.
- Do not use city center coordinates, city radii, city polygons, or distance-to-city matching.
- On home refresh, acquire one fresh position and distance-sort only the current city's published scenic-area cards by each area's single center point.
- After a manual city switch, keep the selected city, acquire one fresh position, and distance-sort that city's published scenic-area cards. Location never overrides a manual switch.
- Preserve the original one-card-per-scenic-area layout and route-opening behavior. Story nodes remain inside their parent scenic area and never become independent home cards.
- Keep backend-configured free-form experience tags on scenic/story nodes for existing node, footprint, and content workflows; they do not change the home card's unit.
- If permission, service, geocoding, or acquisition fails, keep discovery usable, retain the current/default city and backend order, and show no fabricated distance.
- Keep every discovery position sample transient; do not persist a first-run marker, selected mode, coordinates, or a continuous trail.

### Non-goals

- No node recommendation, persistent route ranking field, route-detail reordering, journey-location change, or route-card redesign.
- No city recognition radius, city boundary, city-coordinate matching, reverse-geocoding service on the backend, or city-range editor.
- No automatic/manual discovery mode, persisted manual-city preference, “restore automatic mode” action, or first-location-processed flag.
- No new tag taxonomy and no requirement-two or later product work.

### MVP validation goals

- A cold entry with a successfully acquired location selects a matching backend city that has published scenic areas; otherwise it shows Shenzhen.
- Refresh and manual city switch each perform one fresh location attempt and sort only the active city's home scenic-area cards by area-center distance.
- The nearest published scenic area is the first home card; its story nodes remain contained and retain their existing order after the card is opened.
- Denied or unusable location never blocks the app and never causes a fake or stale distance to appear.
- Arbitrary backend node tags remain backend-driven without changing homepage granularity.

## Capabilities

### New Capabilities

- `location-aware-city-discovery`: Defines cold-entry city fallback, refresh/switch location attempts, scenic-area-center sorting without accuracy gating, and privacy/failure behavior.

### Modified Capabilities

- `route-discovery`: Adds a derived center point to each published scenic-area/route summary without flattening its story nodes into home content.
- `experience-client`: Adds the location-purpose prompt, nearest-scenic-area home ordering, and truthful degraded presentation while retaining the original cards.

## Impact

- Main API: additive point-tag storage plus one derived center coordinate on each existing published route/scenic-area summary; the obsolete flat home-node projection is removed.
- Flutter: one-shot platform location/locality adapter, scenic-area-center distance ranking for original home cards, city fallback behavior, and permission/failure UI.
- Independent `Travel-Admin`: matching point-tag mapping and editing only; the main repository remains migration authority.
- Existing route detail, journey, story progression, city selector options, and card visual structure remain in place.
