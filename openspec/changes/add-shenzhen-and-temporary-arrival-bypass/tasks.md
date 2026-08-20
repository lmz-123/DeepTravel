## 1. Shenzhen backend content

- [x] 1.1 Generate one Shenzhen route visual, store it in backend media storage, and register its media metadata.
- [x] 1.2 Refactor seed reconciliation and add Shenzhen city, featured five-stop route, challenges, and `demo_unverified` content without disturbing existing Shanghai data.
- [x] 1.3 Add focused API tests for both cities, Shenzhen route/media, and idempotent seed behavior.

## 2. Flutter city selection

- [x] 2.1 Add city domain/repository APIs and load backend-provided cities plus a featured route by city slug.
- [x] 2.2 Add Riverpod selected-city state defaulting to Shenzhen and reload discovery content when selection changes.
- [x] 2.3 Replace the fixed Shanghai header with a polished Shenzhen/Shanghai selector and add focused widget/repository tests.

## 3. Temporary tap-to-arrive

- [x] 3.1 Change the client arrival contract to send explicit demo arrival without coordinates and remove the location service, geolocation dependency, and mobile permissions.
- [x] 3.2 Enable the temporary demo-arrival flag in example/Compose defaults while preserving and testing server coordinate validation.
- [x] 3.3 Update arrival UI copy and tests so a tap immediately unlocks the stop without a permission prompt.

## 4. Verification and delivery

- [x] 4.1 Add a short README note for default city, city switching, and the temporary arrival bypass.
- [x] 4.2 Run strict OpenSpec validation, backend tests/lint, and Flutter format/analyze/tests.
- [x] 4.3 Verify the Docker API seed and city/media responses, then commit and push the completed change.
