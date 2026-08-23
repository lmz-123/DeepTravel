## MODIFIED Requirements

### Requirement: Complete guided loop
The client SHALL present the interaction loop configured by the active route and SHALL preserve the appropriate first-time, active-resume, partial-footprint, and completed-revisit state. Fragmented routes SHALL retain the existing node rail and node pages while allowing every published node to be selected independently of authored order. Immediately below the rail and before the audio playback card, the selected node SHALL expose its backend story-point copy, theme, expected duration, heard state and location-trigger state. Untriggered selection SHALL remain informational and MUST NOT unlock, play or collect content; triggered or collected selection SHALL retain the existing audio, transcript and optional photo experience. The journey SHALL support eventual causal reconstruction without answer UI or a mandatory next-stop control. Legacy answer routes MAY retain their existing ordered arrival, observation, answer feedback, and continuation loop for compatibility.

#### Scenario: Start a fragmented field journey
- **WHEN** the user starts a published fragmented route in formal real-location mode
- **THEN** the client opens free roaming, preserves the existing node rail, monitors all eligible point regions, and allows any node to be selected without requiring arrival at the first authored point

#### Scenario: Trigger and hear any point
- **WHEN** any published point qualifies under its independent real-location policy
- **THEN** the client reveals that point, makes its story available, and leaves every other point independently discoverable

#### Scenario: Resume an active partial route
- **WHEN** the user selects a route or footprint with a partially completed owned journey
- **THEN** the client restores its saved point states, original node rail and selected node without the first-time gate or a reset to the first point

#### Scenario: Revisit a completed route
- **WHEN** the user selects a route with only a completed journey
- **THEN** the client opens its unlocked replay or recap state without requesting location or resetting progress

#### Scenario: Complete one stop
- **WHEN** the user arrives and answers a legacy ordered stop
- **THEN** the compatibility client reveals the explanation and enables its existing continuation behavior

## ADDED Requirements

### Requirement: Accessible node-rail interaction
The existing story-node rail SHALL remain the primary node selector and SHALL remain understandable without color or a continuously viewed map. Every published node control SHALL be enabled for selection and announce its position, title or safe preview, heard state and available action. Selecting a node SHALL expose backend story-point copy, theme, expected duration and current proximity/trigger state in a detail region immediately below the rail and before the audio playback card. The rail SHALL render the actual backend node count rather than assuming five nodes, and SHALL adapt visual node size and spacing to density while preserving a safe touch target and horizontal scrolling when the available width cannot safely contain every node. The surface SHALL retain readable loading, unavailable-location, empty, offline, and retry states and SHALL not use motion as the only indication of proximity.

#### Scenario: Route has a non-five node count
- **WHEN** the backend returns a fragmented route with fewer or more than five published nodes
- **THEN** the rail renders exactly that node count, adapts spacing or visual size to the available width, and remains selectable without overflow or clipped controls

#### Scenario: Select a node before the audio card
- **WHEN** the traveler selects any node from the rail
- **THEN** its backend preview and status appear directly below the rail, and the existing audio card remains below that detail region

#### Scenario: Screen reader reaches a heard point
- **WHEN** assistive technology focuses a heard story point
- **THEN** it announces the point metadata and the action to open or replay it

#### Scenario: Screen reader reaches an untriggered point
- **WHEN** assistive technology focuses an untriggered story point
- **THEN** it announces that the point can be selected for information and will unlock only after entering its location range

#### Scenario: No point content is available
- **WHEN** the active route has no currently eligible published story points
- **THEN** the client shows an explicit unavailable-content state and a safe action to leave or refresh rather than an empty rail

#### Scenario: Reduced motion is enabled
- **WHEN** the platform requests reduced motion while proximity state changes
- **THEN** textual and semantic state updates remain available without pulsing, rotating, or map-like animation
