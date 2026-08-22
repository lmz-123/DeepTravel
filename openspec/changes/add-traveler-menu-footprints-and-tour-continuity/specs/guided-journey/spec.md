## MODIFIED Requirements

### Requirement: Guest journey lifecycle
The system SHALL allow an authenticated user to start, retrieve, resume, advance, complete, and revisit one user-owned journey for a published route. Starting a route MUST return the active owned journey when one exists; otherwise it MUST return the most recently completed owned journey for revisit when one exists; only a route with no owned active or completed journey may create a new active journey at the first stop or fragment.

#### Scenario: Start a new journey
- **WHEN** a user starts a published route without an active or completed journey owned by that user
- **THEN** the system creates an active journey at the first stop or fragment

#### Scenario: Resume an existing journey
- **WHEN** a user starts a published route with an unfinished journey owned by that user
- **THEN** the system returns that journey without resetting progress

#### Scenario: Revisit an existing completed journey
- **WHEN** a user starts a published route with no active journey and at least one completed journey owned by that user
- **THEN** the system returns the most recently completed journey without creating a new record or relocking completed content

#### Scenario: Start an archived route
- **WHEN** a user without an existing journey attempts to start an archived route
- **THEN** the system returns not found and creates no journey

#### Scenario: Resume or revisit after archival
- **WHEN** the owning user opens a journey created before its route was archived
- **THEN** the route snapshot and existing progression or recap remain available without creating another journey
