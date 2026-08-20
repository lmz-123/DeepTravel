## Why

The MVP currently exposes only Shanghai and hardcodes it in the Flutter discovery flow. The next validation needs Shenzhen as the default market while retaining Shanghai selection, and it needs a frictionless temporary arrival flow before real-location validation is restored.

## What Changes

- Seed Shenzhen, one published five-stop Shenzhen route, and backend-owned Shenzhen media; keep Shanghai available.
- Add a client city selector with Shenzhen selected by default and reload the featured route when the city changes.
- Temporarily remove device-location permission/use from the client and send an explicit demo-arrival request when the user taps arrival.
- Enable the backend demo-arrival switch in the MVP deployment configuration while preserving the coordinate-validation implementation for later restoration.
- Add focused backend and Flutter tests plus short deployment/product notes.

### Non-goals

- Production-grade historical verification, CMS authoring, multi-route ranking, or automatic GPS-based city detection.
- Removing the server-side geofence implementation; it remains available for the later return to real arrival validation.
- Persisting the selected city across reinstalls in this iteration.

### MVP validation goals

- A fresh install opens Shenzhen content without asking for location permission.
- A user can switch to Shanghai and back to Shenzhen without restarting the app.
- Tapping arrival immediately unlocks the active stop through the explicitly enabled temporary bypass.

## Capabilities

### New Capabilities

- `city-selection`: Defines available city loading, Shenzhen default selection, and user-driven city switching in the Flutter discovery experience.

### Modified Capabilities

- `route-discovery`: Adds Shenzhen seeded content and requires both Shenzhen and Shanghai to expose featured routes.
- `guided-journey`: Temporarily makes explicit demo arrival the client default while retaining coordinate validation for later use.
- `experience-client`: Removes location permission from the current arrival interaction and makes tap-to-arrive the shipped client behavior.
- `platform-runtime`: Changes MVP runtime defaults to enable the temporary demo-arrival switch and seed both cities idempotently.

## Impact

- Backend seed data, media catalog/storage, and catalog API tests.
- Flutter domain/repository contracts, Riverpod city state, discovery header, arrival flow, dependencies, permissions, and widget tests.
- Docker/environment defaults and concise README guidance.
