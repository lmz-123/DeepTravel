## 1. Backend media catalog and storage

- [x] 1.1 Add the `media_assets` SQLAlchemy model and Alembic migration with stable key, storage path, MIME type, and timestamps.
- [x] 1.2 Move the existing route image files into backend-owned media storage and update the Docker image/volume configuration to include them.
- [x] 1.3 Update the backend seed process to register media assets idempotently and associate route/stop image references with the media catalog.
- [x] 1.4 Implement the safe `/api/v1/assets/<path>` endpoint and absolute media URL builder with `PUBLIC_BASE_URL` support.
- [x] 1.5 Update route, city, stop, and journey serializers to return absolute media URLs; add backend tests for content type, path traversal, and URL generation.

## 2. Backend real-arrival contract

- [x] 2.1 Make production-like Compose configuration disable demo arrival by default and document `PUBLIC_BASE_URL`.
- [x] 2.2 Add or update API tests for coordinate-based arrival, out-of-geofence rejection, and disabled demo bypass.

## 3. Flutter API-first client

- [x] 3.1 Make API mode the default and keep the backend API base URL build-time configurable.
- [x] 3.2 Update the API repository and domain contract so arrival sends required latitude and longitude without a demo flag.
- [x] 3.3 Add a small location service with permission handling and connect it to the journey arrival action.
- [x] 3.4 Replace local editorial image loading with remote URL loading, including loading and error states, and update all call sites.
- [x] 3.5 Remove the route media directory from the Flutter asset bundle and remove production UI dependencies on bundled demo content.
- [x] 3.6 Update Android/iOS location permissions and Flutter tests for API payloads, location failure states, and remote media rendering.

## 4. Verification and delivery

- [x] 4.1 Run OpenSpec validation, backend tests, Flutter tests, and static analysis.
- [x] 4.2 Start the Docker backend, verify seeded content and media URLs through the API, and verify the mobile client can consume them.
- [x] 4.3 Build an API-mode Android APK with a configurable backend URL and inspect that route images are not packaged as Flutter assets.
- [x] 4.4 Update deployment/build documentation with the pull, environment, Compose, and API-mode APK commands.
