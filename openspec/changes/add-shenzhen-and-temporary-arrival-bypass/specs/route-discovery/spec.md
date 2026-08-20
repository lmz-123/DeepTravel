## MODIFIED Requirements

### Requirement: Browse published routes by city

The system SHALL return Shenzhen and Shanghai as published cities and SHALL return each city's published featured route with title, theme, duration, distance, difficulty, backend-served cover image, and featured state. Shenzhen route content SHALL be marked as demonstration content until editorial verification is complete.

#### Scenario: Featured route is discoverable

- **WHEN** a client requests routes for Shenzhen or Shanghai
- **THEN** the response includes that city's featured route and all summary metadata
- **AND** the route contains five ordered stops in route detail

#### Scenario: Unknown city

- **WHEN** a client requests routes for an unknown city slug
- **THEN** the system returns a structured not-found error
