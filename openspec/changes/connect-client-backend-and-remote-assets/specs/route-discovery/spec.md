# Route Discovery Delta

## MODIFIED Requirements

### Requirement: Browse published routes

The system SHALL provide a discovery surface listing published routes from the backend, including title, city, duration, stop count, and a backend-served cover image URL when one exists.

#### Scenario: Published routes are available

- **WHEN** a user opens discovery
- **THEN** the client requests the published route list from the backend
- **AND** each route card renders its returned remote cover image URL

#### Scenario: No routes are available

- **WHEN** the backend returns an empty published list
- **THEN** the client shows a deliberate empty state
- **AND** it does not substitute hardcoded route cards

### Requirement: Inspect a complete route before starting

The system SHALL let the user inspect a selected route's editorial description, cover image, and ordered stop preview from backend data before starting the journey.

#### Scenario: User opens route detail

- **WHEN** a user selects a published route
- **THEN** the client loads the complete route detail from the backend
- **AND** the route detail uses the backend media URL for its cover image
