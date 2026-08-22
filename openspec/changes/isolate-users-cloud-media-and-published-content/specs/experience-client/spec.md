## MODIFIED Requirements

### Requirement: Complete guided loop
The client SHALL present the interaction loop configured by the active published route. Fragmented routes SHALL present trigger state, audio controls, transcript, optional photo observation and continuation/reconstruction without rendering answer UI; legacy answer routes SHALL retain arrival, story, observation, answer feedback and continuation for existing journeys.

#### Scenario: Complete one stop
- **WHEN** the current stop's configured fragmented or legacy completion rule is satisfied
- **THEN** the client reveals the configured result, updates progress, and enables any newly eligible route interaction

#### Scenario: Complete one fragmented stop
- **WHEN** the user completes narration and any configured photo rule
- **THEN** the client collects the fragment and enables the next configured dependency without asking a multiple-choice question

#### Scenario: Resume one legacy answer stop
- **WHEN** an owner resumes an archived legacy quiz journey
- **THEN** the client still reveals its answer feedback and enables its original progression

## ADDED Requirements

### Requirement: Client authenticates an account
The client SHALL provide registration and login for normal builds, retain the current authenticated session securely, and provide one-tap switching among configured test accounts only in a test-auth-enabled build.

#### Scenario: Token expires between launches
- **WHEN** a journey request reports expired authorization
- **THEN** the client returns to account authentication without clearing server-owned progress and resumes it after the same user logs in

#### Scenario: Tester switches accounts
- **WHEN** the test build switches from tester A to tester B
- **THEN** cached private journey state is cleared from presentation and only tester B's server-owned progress is shown

### Requirement: Client hides non-published catalog records defensively
The client SHALL render only routes identified as `published` and SHALL show a neutral empty state rather than substituting destination-specific content.

#### Scenario: Stale API includes a verified route
- **WHEN** a route list unexpectedly contains `verified` content
- **THEN** the client omits it and logs a non-sensitive catalog-contract warning

### Requirement: Client presents private cloud evidence safely
The client SHALL request evidence through owner-authorized API responses, handle signed URL expiry by refreshing access and MUST NOT persist a shareable private evidence URL beyond its validity.

#### Scenario: Evidence URL expires while viewing
- **WHEN** the cloud response reports expiration
- **THEN** the client requests fresh owner-authorized access without re-uploading the photo
