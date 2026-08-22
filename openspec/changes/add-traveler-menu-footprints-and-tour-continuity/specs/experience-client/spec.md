## MODIFIED Requirements

### Requirement: Complete guided loop
The client SHALL present the interaction loop configured by the active route and SHALL preserve the appropriate first-time, active-resume, and completed-revisit state. Fragmented routes SHALL present trigger state, selectable collected nodes, audio controls, transcript, optional photo keepsakes and continuation or reconstruction without answer UI; legacy answer routes SHALL retain arrival, story, observation, answer feedback and continuation for existing journeys.

#### Scenario: Complete one stop
- **WHEN** the user arrives and answers a legacy stop
- **THEN** the client reveals the explanation and enables progression to the next stop

#### Scenario: Complete one fragmented stop without a photo
- **WHEN** the user completes the current narration and does not capture optional evidence
- **THEN** the client updates collected progress, keeps the photo invitation available, and enables the next configured dependency without asking an answer question

#### Scenario: Resume an active route from discovery
- **WHEN** the user selects a route that has an active journey
- **THEN** the client opens the persisted progress directly without showing the first-time start gate

#### Scenario: Revisit a completed route
- **WHEN** the user selects a route that has only a completed journey
- **THEN** the client opens its unlocked replay or recap state without requesting location or resetting progress

## ADDED Requirements

### Requirement: Global private application shell
For authenticated API-mode use, the client SHALL provide a shared application shell that hosts the account drawer across private pages and the freely draggable playback orb on discovery while keeping authentication and user-owned playback state isolated.

#### Scenario: Navigate while audio is active
- **WHEN** the traveler moves among shell pages during narration
- **THEN** a single audio session remains synchronized without creating duplicate players, and its playback-orb state is current whenever discovery is visible

#### Scenario: Another scenic audio starts outside the current journey
- **WHEN** a shell page requests narration owned by a different route
- **THEN** the shared shell delegates to the single audio session, which stops the previous route before exposing the new owner or its playback-orb state

#### Scenario: Authentication expires in the shell
- **WHEN** a private shell request reports expired authorization
- **THEN** playback and private presentation stop, the client returns to authentication, and server progress remains recoverable after the same user logs in

### Requirement: Accessible interactive continuity controls
The brand menu trigger, drawer entries, draggable playback orb, clue nodes, photo thumbnails, and full-photo viewer SHALL expose semantic labels, selected or locked state, minimum touch targets, keyboard or switch-access activation where supported, and restrained motion. Dragging the orb SHALL have an accessible repositioning alternative for travelers who cannot perform a free-form pointer gesture.

#### Scenario: Screen reader reaches a collected clue
- **WHEN** assistive technology focuses a collected clue node
- **THEN** it announces the clue position, title, collected state, and replay action rather than only its color

#### Scenario: Screen reader reaches the playback orb
- **WHEN** assistive technology focuses the discovery-page playback orb
- **THEN** it announces the route, clue, playing or paused state, progress, the action to return to the journey, and available reposition actions without implying an inline play or pause control

#### Scenario: Reposition without a drag gesture
- **WHEN** switch access or a screen reader user invokes a directional reposition action on the playback orb
- **THEN** the client moves it by a predictable step within the same safe bounds and announces the new relative position
