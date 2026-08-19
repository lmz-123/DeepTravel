# Design: Connect Client to Backend and Remote Assets

## Context

The current Flutter application can run with a local demo repository and bundled route images. The Flask API and database already model most of the route and journey lifecycle, but the client defaults to demo mode, arrival requests default to a demo bypass, and API media fields are only relative asset strings. This makes the APK appear functional without proving that the deployed backend is the source of truth.

## Goals

- Make API mode the normal client runtime.
- Keep route copy, stop copy, prompts, insights, and media metadata in backend database records.
- Serve image assets from backend-owned storage through a safe API endpoint.
- Return absolute media URLs that work for a deployed server and mobile clients.
- Confirm arrival using real device coordinates.
- Keep the Flutter layers separable: presentation -> application/provider -> repository -> API client.
- Remove production media files from the Flutter asset bundle.

## Non-goals

- Building an admin CMS or a general-purpose object-storage service.
- Adding payments, social features, offline map tiles, or a content authoring workflow.
- Making demo bypasses available in production.

## Decisions

### Backend media boundary

Add a `media_assets` database table containing a stable asset key, storage path, MIME type, and timestamps. Seed the existing route and stop images into the backend media directory and associate them with route/stop records. The binary files remain in backend-managed media storage rather than Flutter assets; this keeps the database as the content catalog while avoiding database BLOB coupling for the MVP.

Expose `GET /api/v1/assets/<path>` from the Flask API. The implementation resolves the requested path beneath the configured media root and rejects traversal. Serializers convert relative asset references into absolute endpoint URLs using `PUBLIC_BASE_URL` when set, otherwise the current request origin.

### Client API boundary

Set `APP_MODE` default to `api`. Keep build-time `API_BASE_URL` configuration so the same source can target local Docker, a staging server, or production. The API repository maps JSON into domain models; presentation widgets do not know whether a value came from a database.

### Remote image rendering

Change the editorial image widget to consume a URL/source value and use `Image.network` with loading and error treatments. Remove the route image directory from `pubspec.yaml` so an API-mode APK cannot silently depend on local media.

### Arrival flow

The journey screen obtains a one-shot location after the user taps confirm, then passes latitude and longitude through the repository to the existing backend geofence endpoint. Permission denial, location failure, and out-of-geofence responses remain recoverable UI states. The client does not send `demo: true`.

## Data flow

```text
MySQL media_assets + route/stop rows
          |
          v
Flask serializers ---> absolute /api/v1/assets/... URL
          |                         |
          v                         v
Flutter API repository ---> Image.network
          |
          v
Flutter location service ---> POST /journeys/{id}/arrive {latitude, longitude}
```

## Compatibility and migration

- Existing route and stop rows keep their logical media references; the seed process registers missing media records and normalizes references.
- Existing API consumers that only display text remain compatible; media fields become absolute URLs.
- Existing explicit demo tests may remain as development fixtures, but the shipped client defaults to API mode and does not package route media.
- `PUBLIC_BASE_URL` is optional for local development and recommended behind a reverse proxy.

## Verification

- Backend unit/API tests cover media lookup, path safety, absolute URL serialization, coordinate arrival, and geofence rejection.
- Flutter tests cover API repository payloads and remote image widget states without loading local route assets.
- Build an API-mode Android APK with a supplied `API_BASE_URL` and inspect the APK asset list for the removed route-image bundle.
