## MODIFIED Requirements

### Requirement: Browse published routes by city
The system SHALL return published cities and their published routes with title, theme, duration, distance, difficulty, cover image, featured state, companion tags, and an indication of available pre-trip knowledge content. Values configured as tags SHALL be returned as backend data rather than a closed client enum.

#### Scenario: Featured route is discoverable
- **WHEN** a client requests routes for a city that has a featured published route
- **THEN** the response includes that route and all summary metadata

#### Scenario: Unknown city
- **WHEN** a client requests routes for an unknown city slug
- **THEN** the system returns a structured not-found error

### Requirement: Inspect a complete route
The system SHALL return the route narrative, ordered stop previews, map coordinates, arrival radius, challenge type, editorial verification state, pre-trip story directions, related reusable stories, and configured safety, rest, accessibility, and weather-adaptation tips. The returned order SHALL be advisory before a journey and SHALL NOT prevent users from opening another available preview.

#### Scenario: Stops are ordered
- **WHEN** a client requests a route detail
- **THEN** stops are returned in ascending route position

#### Scenario: Demonstration copy is identified
- **WHEN** a route contains content that has not completed publication review
- **THEN** the response identifies it as demonstration content requiring verification

#### Scenario: Pre-trip content is opened away from the route
- **WHEN** a user requests a published reusable story before reaching the route
- **THEN** the story remains readable and playable without location arrival or journey progression
