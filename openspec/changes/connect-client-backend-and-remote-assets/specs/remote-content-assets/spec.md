# Remote Content Assets

## Purpose

Keep route content and fixed media owned by the backend so that the Flutter client is a thin consumer of API data and can receive content updates without an APK rebuild.

## ADDED Requirements

### Requirement: Backend owns seeded experience content and media metadata

The backend SHALL persist route, stop, city, and media-asset metadata in the database during its normal migration and seed process. The Flutter application SHALL NOT contain the production route copy, stop copy, or production media catalog as runtime data.

#### Scenario: Fresh backend starts

- **WHEN** the backend runs migrations and its seed command against an empty database
- **THEN** route discovery and guided-journey endpoints return the seeded experience content
- **AND** each referenced media asset has a corresponding backend media record

#### Scenario: Backend restarts with existing data

- **WHEN** the backend runs its startup seed command against an already initialized database
- **THEN** existing content is preserved
- **AND** missing media metadata is reconciled without creating duplicate records

### Requirement: Backend serves media through a stable API endpoint

The backend SHALL serve only files from its configured media storage directory through an authenticated-independent read endpoint suitable for mobile image loading. The endpoint SHALL reject path traversal outside the media directory.

#### Scenario: Client loads a route image

- **WHEN** the client requests the media URL returned by a route or stop response
- **THEN** the backend returns the stored image with its correct content type

#### Scenario: Unsafe media path is requested

- **WHEN** a request contains a path that resolves outside the configured media directory
- **THEN** the backend returns a not-found response
- **AND** it does not expose arbitrary server files

### Requirement: API responses expose usable media URLs

Route, city, and stop payloads SHALL expose absolute media URLs for referenced images and audio. The URL builder SHALL honor the configured public backend base URL when present and SHALL otherwise derive the URL from the current request.

#### Scenario: Client receives route content

- **WHEN** the client requests a route or journey
- **THEN** every non-empty media field is an absolute HTTP(S) URL
- **AND** the URL points to the backend media endpoint

### Requirement: Production client contains no fixed media bundle

The production Flutter APK SHALL load experience media with network URLs returned by the backend and SHALL not package the route media directory as Flutter assets.

#### Scenario: APK is built for API mode

- **WHEN** the APK is built with API mode enabled
- **THEN** the APK has no dependency on the repository's local route-image bundle
- **AND** image loading uses the backend URLs from API responses
