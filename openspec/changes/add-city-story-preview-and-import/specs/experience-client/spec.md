## MODIFIED Requirements

### Requirement: Resilient presentation states
The client SHALL provide loading, actionable empty, offline/demo, and recoverable error states without losing known journey, prepared-content, or favorite state. Home city-story modules with no eligible content SHALL show a clear recommendation or city-switch action rather than an empty region.

#### Scenario: API is unavailable
- **WHEN** a network request fails in API mode
- **THEN** the client presents a retry action and retains locally known state

#### Scenario: Current city has no story content
- **WHEN** all city-story modules for the current city are empty
- **THEN** the client explains that no published content is available and displays a configured fallback recommendation or the existing city selector

## ADDED Requirements

### Requirement: Accessible city knowledge entry points
The client SHALL expose “今天听一段城市故事” as the primary home story entry plus the other four backend-driven city-story modules, allow story audio and transcript access without beginning a trip, and preserve semantic labels, text alternatives, minimum touch targets, and reduced-motion behavior.

#### Scenario: User opens a city story from home
- **WHEN** the user selects a published story card in any home module
- **THEN** the client opens the shared listening and reading experience with accessible controls

### Requirement: Client-independent story values
The client SHALL render backend-provided story types, themes, tags, and editorial tips as content values and SHALL NOT require a client release when a new value is published.

#### Scenario: Unknown content value is returned
- **WHEN** a public response contains a newly configured type label, theme, tag, or tip category
- **THEN** the client renders the safe display label and does not discard the containing story
