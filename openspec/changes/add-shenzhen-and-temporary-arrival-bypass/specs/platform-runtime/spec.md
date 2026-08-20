## MODIFIED Requirements

### Requirement: Reproducible local runtime

The project SHALL provide a documented Docker Compose runtime for the API and MySQL with health-gated startup, deterministic Shenzhen and Shanghai seed data, backend-hosted city media, and the temporary demo-arrival switch enabled by the MVP environment template.

#### Scenario: Fresh startup

- **WHEN** a developer starts the documented Compose profile on a clean database volume
- **THEN** the database becomes healthy, schema is created, both cities and their routes are seeded, media is available, and the API reports healthy

#### Scenario: Existing database startup

- **WHEN** the seed command runs against a database that already contains Shanghai
- **THEN** missing Shenzhen data and media records are added idempotently
- **AND** existing journey and catalog data is preserved
