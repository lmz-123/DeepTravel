# Guided Journey Delta

## MODIFIED Requirements

### Requirement: Arrival confirmation uses real coordinates by default

The client SHALL obtain the device's current coordinates after the user taps the arrival action and SHALL send those coordinates to the backend. The backend SHALL validate the coordinates against the stop geofence. A demo arrival bypass SHALL be unavailable unless explicitly enabled in backend configuration, and the production client SHALL never request that bypass.

#### Scenario: User confirms arrival within the geofence

- **WHEN** the user grants location permission and confirms arrival near the active stop
- **THEN** the client sends latitude and longitude to the arrival endpoint
- **AND** the backend accepts the arrival and returns the updated journey state

#### Scenario: User denies location permission

- **WHEN** the user denies location permission
- **THEN** the client explains that location is required for arrival confirmation
- **AND** it does not send a demo bypass request

#### Scenario: User is outside the geofence

- **WHEN** the submitted coordinates are outside the stop's allowed radius
- **THEN** the backend rejects the arrival with a recoverable response
- **AND** the client keeps the stop active

#### Scenario: Demo bypass is disabled

- **WHEN** a client submits a demo arrival while the backend bypass flag is disabled
- **THEN** the backend rejects the request

## ADDED Requirements

### Requirement: Journey content is refreshed from the backend

The active journey SHALL use the route, stop, prompt, and insight content returned by the backend rather than client-bundled fixed content.

#### Scenario: Journey opens after route selection

- **WHEN** the journey is opened
- **THEN** its content and remote media references come from the backend response
