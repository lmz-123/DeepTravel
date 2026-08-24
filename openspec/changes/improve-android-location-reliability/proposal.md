## Why

Android discovery can obtain a coordinate and still report location failure when the platform reverse geocoder is unavailable or returns a district, province, or English city name that does not exactly equal the backend display name. Geolocator otherwise prefers Google FusedLocationProviderClient when Google Play Services appears installed, but the product's target devices are domestic Android devices where GMS is commonly absent or unusable. The current outer Dart timeout also does not cancel native work. Formal journeys depend on timely, fresh, accurate samples and must not wait for a provider the target environment does not support.

Location is a core product capability, so coordinate acquisition, city resolution, and field triggering must fail independently and remain diagnosable without collecting a location trail.

## What Changes

- Treat a fresh coordinate as successful discovery location even when reverse geocoding or city-name matching fails.
- Gather all useful administrative-name candidates and match them generically against backend city names and slugs; when text is unavailable, resolve a supported city from existing published route centers within a conservative recognition radius.
- On Android, bypass Google FusedLocationProviderClient and use Android LocationManager directly with a native Geolocator time limit; use a strictly fresh cached sample only as a bounded discovery fallback.
- Make the formal-journey stream use LocationManager directly with more frequent high-accuracy samples.
- Reject stale/future field samples before trigger evaluation while preserving each point's configured accuracy, radius, stable-sample, hysteresis, and idempotency policy.
- Emit privacy-safe location stage, duration, provider-strategy, accuracy-bucket, and failure diagnostics without coordinates, locality text, or calculated distance.

### Non-goals

- No map, turn-by-turn navigation, continuous location upload, breadcrumb persistence, or server-side traveler-location endpoint.
- No Baidu/AMap SDK integration or BD-09/GCJ-02 conversion in this change; runtime and content coordinates remain WGS-84.
- No CMS schema change, city polygon editor, trigger-region content rewrite, or automatic publication change.
- No changes to offline package downloads, route cards, narration, footprints, or authentication.

### MVP validation goals

- A coordinate followed by geocoder failure still produces truthful scenic-area distance ordering and does not show a location-acquisition failure.
- Shenzhen/Shanghai matching tolerates administrative suffixes, district-prefixed results, English slug names, and multiple placemark fields without a Flutter city allowlist.
- A timed-out Android LocationManager request is natively cancelled; repeated retries do not accumulate native requests or wait on GMS.
- A formal journey receives fresh high-accuracy LocationManager samples on domestic Android devices, and stale samples never trigger a story point.
- CMS client diagnostics identify the failed stage and provider strategy without storing raw or derived location values.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `location-aware-city-discovery`: Separates coordinate success from reverse-geocoder/city-resolution success and uses Android LocationManager directly.
- `free-roam-location-experience`: Requires fresh LocationManager field samples for Android continuous triggering.
- `platform-runtime`: Adds privacy-safe location diagnostics suitable for the existing CMS runtime-log console.

## Impact

- Flutter discovery location adapter, discovery controller/domain state, journey platform location adapter, trigger engine, and focused tests.
- Existing public API, database, CMS content model, offline package format, and WGS-84 trigger-region contract remain unchanged.
