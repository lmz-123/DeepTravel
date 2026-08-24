## Context

Discovery currently performs one high-priority position request and then calls Android's system Geocoder. It keeps only the first non-empty administrative field and requires an exact normalized match to a backend city name. Any geocoder or match failure restores Shenzhen and marks the entire operation unavailable, even though the coordinate can already rank scenic areas.

On Android, Geolocator selects Google FusedLocationProviderClient whenever Google Play Services reports available and otherwise uses LocationManager. The product primarily targets domestic Android devices where GMS is commonly absent, disabled, incomplete, or unable to produce a timely fix. The current outer Dart timeout does not invoke Geolocator's native cancellation path because `LocationSettings.timeLimit` is unset.

The formal journey already owns a transient WGS-84 stream and a stable trigger engine. This change strengthens sample delivery and freshness without changing trigger-region content or transmitting non-trigger samples.

## Goals / Non-Goals

**Goals:**

- Make coordinate acquisition independent from optional locality presentation.
- Make domestic Android location independent of GMS by forcing LocationManager.
- Preserve WGS-84 end to end and improve field sample freshness.
- Make failures observable without logging location values.

**Non-Goals:**

- No third-party Chinese map SDK, map UI, navigation, city-boundary schema, or location history.
- No change to server trigger validation, offline synchronization, or published trigger-region values.
- No promise of sub-10-metre GPS accuracy where device/environment accuracy cannot support it.

## Decisions

### 1. Coordinate success is the discovery success boundary

`CurrentLocationSource` returns a fresh coordinate plus optional accuracy, provider strategy, cache flag, and a list of transient locality candidates. Reverse-geocoder errors are swallowed only as locality-resolution errors; they do not erase the coordinate.

Cold entry first matches every normalized locality candidate against both backend city display names and slugs. Matching accepts exact values and administrative strings containing one unambiguous backend city value. If no text match exists, the controller compares the coordinate with existing published route centers for selectable cities and accepts the nearest city only inside a conservative 100 km recognition radius. Catalog failures are isolated per city. If no city qualifies, Shenzhen remains selected, but its available route centers can still be ranked from the successful coordinate.

Refresh and manual switch never replace the active city; they always use a successful coordinate directly for that city's card distances.

### 2. Android single-fix requests use LocationManager and native cancellation

Android discovery makes one `AndroidSettings(forceLocationManager: true)` request with `LocationAccuracy.high` and a native ten-second `timeLimit`. It never starts Google FusedLocationProviderClient. Permission denial and disabled location service remain distinct failures.

If the fresh request fails, discovery may use last-known LocationManager data only when it is at most 30 seconds old. Cached data is explicitly marked for diagnostics and remains subject to the controller freshness check. Other platforms use one bounded high-accuracy request.

The application MUST NOT wrap the native request in a separate timeout that leaves native work running.

### 3. Formal journey stream uses LocationManager directly

The journey tracker starts one forced LocationManager stream with Android high accuracy, a three-second interval, a three-metre distance filter, foreground notification, and a twelve-second update limit. A terminal timeout or provider error reaches the journey controller without starting a Google provider.

Stop, route switch, account switch, and controller disposal cancel the subscription. The tracker never starts Google FusedLocationProviderClient.

### 4. Trigger precision uses fresh configured samples

The trigger engine rejects samples more than 15 seconds old or more than five seconds in the future before evaluating any point. It continues to require the point's configured maximum accuracy, entry radius, stable-sample count, sample window, exit radius, and deterministic nearest-point tie break. This avoids silently widening editorial geofences.

Points whose entry radius is materially smaller than field-device accuracy still require separate CMS field calibration; this code change does not invent corrected content values.

### 5. Location diagnostics are coarse and privacy-safe

Discovery and journey adapters report events through the existing runtime reporter. Allowed context includes operation stage, elapsed milliseconds, permission outcome, provider strategy, cached/fresh, accuracy bucket, and normalized failure type. It excludes coordinates, locality/address text, calculated distance, route trace, and raw platform exception messages.

The CMS server-log panel remains server-only; these events appear in its client-log source when runtime log ingestion is enabled in the release environment.

## Module Boundaries

- Platform discovery adapter: permission, direct LocationManager acquisition, geocoder candidates, bounded cache policy.
- Discovery controller: backend-city matching, route-center recognition, active-city ranking, outcome diagnostics.
- Journey platform adapter: continuous LocationManager stream lifecycle.
- Trigger engine: sample freshness and existing independent point policy.
- CMS/backend: unchanged except consuming existing client runtime logs.

## Failure Behavior

- Geocoder unavailable: coordinate remains successful; route distance works; textual city matching falls back to route-center recognition.
- Unsupported location: retain Shenzhen/default content without falsely claiming coordinate acquisition failed.
- LocationManager timeout: native cancellation occurs through `LocationSettings.timeLimit`.
- LocationManager fails: use only an eligible 30-second cached discovery position; formal journey reports interruption and never triggers from cache.
- Runtime log endpoint unavailable: app behavior is unaffected and the bounded local logging queue keeps existing semantics.

## Migration and Rollback

No database or API migration is required. Ship the Flutter client after focused device tests. Rollback is an APK rollback; no data cleanup or content rollback is needed.
