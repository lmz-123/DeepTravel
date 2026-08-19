## Why

The current APK starts in demo mode, keeps route imagery in Flutter assets, and sends demo arrival requests even when the API repository is selected. This prevents a deployed Flask service from being the real source of truth for the product and makes production content updates impossible without rebuilding the app.

## What Changes

- Make API mode the default runtime for the production APK; keep demo mode only as an explicit development override.
- Serve route and stop images from the Flask backend and return resolvable media URLs from API responses.
- Move the existing fixed route content and media metadata into backend seed/database records; remove client-side route content as a runtime dependency.
- Make the Flutter API repository resolve route content, journey state, answers, arrivals, and recap against the configured backend URL.
- Replace demo arrival requests with real device location requests and preserve a clearly isolated development-only demo override.
- Add backend and Flutter tests for remote media URLs, API-mode startup, and coordinate-based arrival.

## Capabilities

### New Capabilities

- `remote-content-assets`: The backend owns seeded route content and serves media assets through stable API-relative URLs.

### Modified Capabilities

- `experience-client`: API mode becomes the production default and displayed imagery is loaded from backend media URLs.
- `guided-journey`: Production arrival uses device coordinates; demo arrival is restricted to explicit development configuration.
- `route-discovery`: Route and stop imagery are backend-owned media references rather than bundled client assets.
- `platform-runtime`: The deployed runtime exposes media resources and documents production API configuration.

## Impact

- Backend: static media endpoint, seed/media path changes, serializers, tests, and deployment configuration.
- Flutter: API-mode configuration, remote image widget, repository URL resolution, location permission/request flow, and tests.
- Assets: existing generated route images move from `mobile/assets/images/` into backend-served media storage; no new third-party content is introduced.
- Deployment: the API base URL must be supplied when building the production APK; development demo mode remains opt-in only.

## Non-goals

- No CMS, paid content, user accounts, offline media cache, map tile provider, or audio hosting platform is added in this change.
- Existing historical copy remains marked as demonstration/unverified content until editorial review is completed.

## MVP Validation Goals

- A clean backend deployment seeds content and returns route/detail responses whose media URLs are reachable from a phone.
- An API-mode APK loads route and stop images over HTTP(S), starts a guest journey, submits real coordinates, answers challenges, and completes recap without bundled route content.
- Demo mode can still be enabled explicitly for development tests, but is not used by the production build.
