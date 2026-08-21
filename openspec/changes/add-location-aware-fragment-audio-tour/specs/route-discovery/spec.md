## MODIFIED Requirements

### Requirement: Inspect a complete route
The system SHALL return the route narrative question, audio-tour readiness, ordered fragment previews, trigger-region metadata required for client evaluation, narration asset metadata, mission type, dependency information, and editorial verification state without exposing locked fragment spoilers.

#### Scenario: Stops are ordered
- **WHEN** a client requests a route detail that retains legacy stops
- **THEN** stops are returned in ascending route position and linked fragment previews preserve their authored order

#### Scenario: Fragments are ordered
- **WHEN** a client requests a fragmented route detail
- **THEN** fragment previews are returned in authored route position with safe trigger and preparation metadata

#### Scenario: Locked fragment has spoilers
- **WHEN** a fragment's detailed claim or narration should remain undiscovered
- **THEN** the public route response exposes only its safe preview and the authenticated journey endpoint reveals full content after trigger eligibility is satisfied

#### Scenario: Route can be prepared
- **WHEN** the route is audio-tour ready
- **THEN** the response identifies required audio, transcript, cover, trigger, and mission assets plus their version and download size

#### Scenario: Demonstration copy is identified
- **WHEN** a route or fragment contains content that has not completed publication review
- **THEN** the response identifies it as demonstration content requiring verification and does not label its narration as reviewed history

## ADDED Requirements

### Requirement: Audio-tour readiness summary
Route summaries SHALL state whether hands-free triggering, prepared offline playback, photo missions, and background operation are supported and which permissions are required.

#### Scenario: Traveler compares a route
- **WHEN** a city route list includes an audio-led route
- **THEN** its summary identifies estimated duration, walking distance, fragment count, photo-mission count, download size, and location/audio requirements

### Requirement: Source and authenticity preview
Route detail SHALL provide a concise content-method statement describing source quality, review state, and use of fictional framing or reconstructed physical features.

#### Scenario: Route uses fictional framing
- **WHEN** fictional narrative framing wraps reviewed historical claims
- **THEN** route detail identifies the framing as fiction before the traveler starts
