## ADDED Requirements

### Requirement: Downloaded journeys can start and progress offline

An authenticated traveler with a complete verified route package SHALL be able to start that route without network access. The client SHALL retain route state, revealed text, cached audio, and playback progress locally until server synchronization is available.

#### Scenario: First offline start

- **WHEN** the traveler starts a downloaded route while the API is unreachable
- **THEN** the client creates a durable local journey alias and opens the active route
- **AND** location or simulated triggers can reveal packaged text and play cached narration

#### Scenario: App restarts before synchronization

- **WHEN** the app restarts while an offline journey and playback checkpoint are pending
- **THEN** the client restores the same local journey state and playback position
- **AND** it does not require a successful API response before continuing
