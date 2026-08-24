## 1. OpenSpec and regression boundaries

- [x] 1.1 Add strict delta requirements for coordinate/geocoder separation, direct Android LocationManager use, field-sample freshness, and privacy-safe diagnostics.
- [x] 1.2 Confirm the change adds no CMS schema, third-party map SDK, coordinate-system conversion, trigger-content rewrite, or location persistence.

## 2. Discovery reliability

- [x] 2.1 Add native time-limited forced-LocationManager acquisition and a 30-second last-known fallback without any Google FusedLocationProviderClient request.
- [x] 2.2 Return all useful reverse-geocoder administrative candidates while keeping geocoder failure independent from coordinate success.
- [x] 2.3 Match all locality candidates against backend names/slugs and fall back to nearest published route center inside the supported-city recognition limit.
- [x] 2.4 Keep refresh/manual-city behavior scoped to active-city distance ranking and prevent a successful coordinate from being presented as acquisition failure.
- [x] 2.5 Add discovery diagnostics containing stage/provider/timing/accuracy buckets only.
- [x] 2.6 Add focused tests for district/English/multiple-field matching, geocoder-null coordinate success, route-center city recognition, unsupported-city fallback, and no fake distance after real acquisition failure.

## 3. Formal journey reliability

- [x] 3.1 Update the Android continuous tracker to force LocationManager with high accuracy and a three-second/three-metre sampling policy.
- [x] 3.2 Ensure tracker stop/dispose cancels its subscription and no Google fused stream is started.
- [x] 3.3 Reject stale/future trigger samples while retaining per-point accuracy, stable-sample, hysteresis, nearest-candidate, and idempotency behavior.
- [x] 3.4 Add tests for stale/future trigger rejection and preservation of current stable-sample behavior.

## 4. Verification

- [x] 4.1 Run Dart formatting, focused discovery/location tests, Flutter analyze, and the full Flutter suite.
- [x] 4.2 Run strict OpenSpec validation and inspect the diff for raw location logging, third-party coordinate systems, unrelated UI/content changes, or persistent location state.
