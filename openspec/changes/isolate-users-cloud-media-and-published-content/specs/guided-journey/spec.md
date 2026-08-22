## MODIFIED Requirements

### Requirement: Guest journey lifecycle
The system SHALL allow an authenticated user to start, retrieve, resume, advance and complete one user-owned journey for a published route. New journeys MUST NOT start on non-published routes, while an existing owner may continue a route archived after that journey began.

#### Scenario: Start a new journey
- **WHEN** a user starts a published route without an unfinished journey owned by that user
- **THEN** the system creates an active journey at the first stop or fragment

#### Scenario: Resume an existing journey
- **WHEN** a user starts a published route with an unfinished journey owned by that user
- **THEN** the system returns that journey without resetting progress

#### Scenario: Start an archived route
- **WHEN** a user without an existing journey attempts to start an archived route
- **THEN** the system returns not found and creates no journey

#### Scenario: Resume after archival
- **WHEN** the owning user resumes a journey created before its route was archived
- **THEN** the route snapshot and remaining progression remain available

## ADDED Requirements

### Requirement: Fragmented routes progress without answer gating
For a fragmented audio route, the system SHALL advance through dependency, playback and configured evidence rules and MUST NOT require an observation answer unless the route explicitly declares an answer interaction.

#### Scenario: Shanghai passive fragment completes
- **WHEN** the narration completion threshold is acknowledged
- **THEN** the fragment becomes collected without an answer record
