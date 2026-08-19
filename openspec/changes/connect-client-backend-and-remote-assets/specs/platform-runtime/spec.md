# Platform Runtime Delta

## MODIFIED Requirements

### Requirement: Reproducible local runtime

The project SHALL provide a Docker Compose runtime for the Flask API and MySQL, including a persistent backend media volume or image-bundled media directory, with configuration for the public API base URL and media URL generation.

#### Scenario: Developer starts the stack

- **WHEN** a developer runs the documented Compose command with the environment file
- **THEN** MySQL, migrations, seed data, API endpoints, and backend media serving start successfully
- **AND** API responses contain URLs reachable from the configured client environment

#### Scenario: Fresh startup

- **WHEN** a developer starts the documented Compose profile on a clean database volume
- **THEN** the database becomes healthy, schema is created, seed data is loaded, backend media is available, and the API reports healthy

### Requirement: API contract is versioned and testable

The backend SHALL expose versioned route, journey, arrival, answer, recap, and media endpoints under `/api/v1`, and automated tests SHALL verify the real-coordinate arrival path and media URL behavior.

#### Scenario: API contract tests run

- **WHEN** the backend test suite runs
- **THEN** it verifies published route content, coordinate-based arrival, rejected out-of-geofence arrival, and media endpoint responses

## ADDED Requirements

### Requirement: Production configuration does not enable demo arrival

The default deployment configuration SHALL disable demo arrival bypasses, while allowing a developer to explicitly enable them for local testing.

#### Scenario: Production-like configuration is loaded

- **WHEN** the API starts with the example deployment configuration
- **THEN** demo arrival bypass is disabled
