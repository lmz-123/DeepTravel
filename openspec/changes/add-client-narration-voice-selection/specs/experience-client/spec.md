## ADDED Requirements

### Requirement: Account text editing preserves authoritative deletions
Registration and login fields SHALL preserve the exact text editing sequence received from the user and MUST NOT restore text that the user deleted when a later insertion arrives. Rebuilds and asynchronous authentication state changes MUST NOT replace an active field's editing value.

#### Scenario: Deleted username suffix stays deleted
- **WHEN** the traveler enters `liser`, deletes the suffix `er` to leave `lis`, and then enters `tt`
- **THEN** the visible and submitted username is exactly `listt`

#### Scenario: Registration mode changes
- **WHEN** the traveler switches between registration and login while the username field is active
- **THEN** the current text, selection, and subsequent edits remain coherent without restoring a prior editing value

### Requirement: Active narration voice is easy to find
The client SHALL show the effective narration voice on route detail and journey playback and SHALL provide an accessible selector without requiring the traveler to leave the route.

#### Scenario: Route has multiple voices
- **WHEN** the traveler opens a route with at least two selectable profiles
- **THEN** the current profile and a clear change action are visible before starting the route

#### Scenario: Route has one voice
- **WHEN** only the default profile is complete
- **THEN** the client identifies the active voice without presenting a misleading multi-choice control

