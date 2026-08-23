## MODIFIED Requirements

### Requirement: Complete guided loop
The client SHALL present the interaction loop configured by the active route and SHALL preserve the appropriate first-time, active-resume, partial-footprint, and completed-revisit state. Fragmented routes SHALL default to a free-roam surface with nearby story points, per-point theme, expected duration, heard state, location-trigger state, selectable triggered or collected nodes, audio controls, transcript, optional photo keepsakes, and eventual causal reconstruction without answer UI or a mandatory next-stop control. Legacy answer routes MAY retain their existing ordered arrival, observation, answer feedback, and continuation loop for compatibility.

#### Scenario: Start a fragmented field journey
- **WHEN** the user starts a published fragmented route in formal real-location mode
- **THEN** the client opens free roaming, monitors all eligible point regions, and presents nearby story points rather than requiring arrival at the first authored point

#### Scenario: Trigger and hear any point
- **WHEN** any published point qualifies under its independent real-location policy
- **THEN** the client reveals that point, makes its story available, and leaves every other point independently discoverable

#### Scenario: Resume an active partial route
- **WHEN** the user selects a route or footprint with a partially completed owned journey
- **THEN** the client restores its saved point states and nearby surface without the first-time gate or a reset to the first point

#### Scenario: Revisit a completed route
- **WHEN** the user selects a route with only a completed journey
- **THEN** the client opens its unlocked replay or recap state without requesting location or resetting progress

#### Scenario: Complete one stop
- **WHEN** the user arrives and answers a legacy ordered stop
- **THEN** the compatibility client reveals the explanation and enables its existing continuation behavior

## ADDED Requirements

### Requirement: Accessible nearby-point interaction
The nearby story-point surface SHALL remain understandable without color or a continuously viewed map. Each point control SHALL announce its title or safe preview, backend theme, expected duration, heard state, current proximity/trigger state, and available action. The surface SHALL retain readable loading, unavailable-location, empty, offline, and retry states and SHALL not use motion as the only indication of proximity.

#### Scenario: Screen reader reaches a heard point
- **WHEN** assistive technology focuses a heard story point
- **THEN** it announces the point metadata and the action to open or replay it

#### Scenario: No point content is available
- **WHEN** the active route has no currently eligible published story points
- **THEN** the client shows an explicit unavailable-content state and a safe action to leave or refresh rather than an empty rail

#### Scenario: Reduced motion is enabled
- **WHEN** the platform requests reduced motion while proximity state changes
- **THEN** textual and semantic state updates remain available without pulsing, rotating, or map-like animation
