## MODIFIED Requirements

### Requirement: Complete guided loop

The client SHALL present tap-to-arrive, story, audio controls, observation, answer feedback, and continuation for each stop. During the temporary bypass phase, tapping arrival SHALL NOT request device location permission.

#### Scenario: Complete one stop

- **WHEN** the user taps arrival and answers a stop
- **THEN** the client reveals the explanation and enables progression to the next stop
- **AND** no location permission dialog is shown
