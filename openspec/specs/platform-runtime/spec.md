# platform-runtime Specification

## Purpose
Make the MVP reproducible for development and evaluation with deterministic data, observable health, durable storage, and automated verification.

## Requirements

### Requirement: Reproducible local runtime
The project SHALL provide a documented Docker Compose runtime for the API and MySQL with health-gated startup and deterministic seed data.

#### Scenario: Fresh startup
- **WHEN** a developer starts the documented Compose profile on a clean database volume
- **THEN** the database becomes healthy, schema is created, seed data is loaded, and the API reports healthy

### Requirement: Versioned API and structured errors
The API SHALL expose product endpoints below `/api/v1` and return errors with stable code, localized message, and optional details.

#### Scenario: Validation error
- **WHEN** a request has invalid input
- **THEN** the API returns a 4xx response with the structured error contract

### Requirement: Guest authorization
The system SHALL issue expiring guest tokens containing no personal information and SHALL require them for journey resources.

#### Scenario: Missing guest token
- **WHEN** a client accesses a journey endpoint without a valid guest token
- **THEN** the system returns an unauthorized structured error

### Requirement: Automated verification
The repository SHALL include automated tests for the journey state rules, public API contract, demo repository behavior, and essential Flutter screens.

#### Scenario: Test suites run
- **WHEN** a developer executes the documented test commands
- **THEN** tests run without depending on paid services or private credentials
