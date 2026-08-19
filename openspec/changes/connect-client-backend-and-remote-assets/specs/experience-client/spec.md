# Experience Client Delta

## MODIFIED Requirements

### Requirement: Three-tap route start

The client SHALL let a user move from route discovery to an active journey in no more than three intentional taps, using published route data loaded from the backend API by default. The client SHALL show a clear loading state while content is fetched and a recoverable error state when the API is unavailable.

#### Scenario: User starts a published route

- **WHEN** the user opens discovery, selects a published route, and taps start
- **THEN** the client starts the journey using the route and stop data returned by the backend
- **AND** no bundled production route data is used as a fallback

#### Scenario: First launch in demo mode

- **WHEN** the client launches with an explicit development demo mode override
- **THEN** the featured route is visible and can be started without registration or an API key
- **AND** this override is not the default production runtime

#### Scenario: API content is loading

- **WHEN** route content has not finished loading
- **THEN** the client shows a deliberate loading state
- **AND** it does not render stale hardcoded route content as if it were current

### Requirement: Media-aware editorial presentation

The client SHALL render media fields as remote resources returned by the backend, with graceful loading and failure states that preserve the surrounding content and controls.

#### Scenario: Remote image is slow or unavailable

- **WHEN** a remote image is loading or fails
- **THEN** the client shows a compact placeholder or failure treatment
- **AND** the user can continue reading and interacting with the journey

## ADDED Requirements

### Requirement: API mode is the default runtime mode

The client SHALL default to API mode and SHALL accept the backend base URL through build-time configuration.

#### Scenario: Production build starts

- **WHEN** the app starts without an explicit development override
- **THEN** it creates the API-backed experience repository
- **AND** its requests target the configured backend API base URL
