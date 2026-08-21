## MODIFIED Requirements

### Requirement: Automated verification
The repository SHALL include automated tests for journey and fragment state rules, public API contracts, location-trigger hysteresis and deduplication, audio queue transitions, photo-evidence authorization and idempotency, source-publication gates, demo behavior, and essential Flutter screens.

#### Scenario: Test suites run
- **WHEN** a developer executes the documented test commands
- **THEN** deterministic tests run without real walking, paid services, production credentials, or external text-to-speech calls

## ADDED Requirements

### Requirement: Durable private evidence storage
The runtime SHALL provide configurable storage for guest photo evidence behind an interface that preserves journey authorization and can move from local volume storage to object storage without changing API behavior.

#### Scenario: Container is recreated
- **WHEN** the API container is rebuilt while its configured evidence volume is retained
- **THEN** accepted guest evidence and database references remain available

#### Scenario: Storage write fails
- **WHEN** evidence bytes cannot be durably written
- **THEN** the API returns a structured recoverable error and does not commit a successful evidence record

### Requirement: Evidence limits and retention configuration
The runtime SHALL expose deployment configuration for supported image types, maximum upload size and dimensions, evidence retention, and public-media separation.

#### Scenario: Production configuration starts
- **WHEN** the API starts with evidence upload enabled
- **THEN** it reports healthy only after required private storage is writable and keeps private evidence outside public route-media paths

### Requirement: Narration asset health
Published audio-tour routes SHALL reference narration and transcript assets that exist in configured backend media storage.

#### Scenario: Seed or publication validation runs
- **WHEN** an audio-tour route is seeded or prepared for publication
- **THEN** missing narration, transcript, source, or version metadata causes validation failure instead of a partially ready production route
