## Purpose

Enable curious travelers to understand, compare, and confidently begin curated cultural walking routes from concise, trustworthy route information.

## ADDED Requirements

### Requirement: Browse published routes by city
The system SHALL return published cities and their published routes with title, theme, duration, distance, difficulty, cover image, and featured state.

#### Scenario: Featured route is discoverable
- **WHEN** a client requests routes for a city that has a featured published route
- **THEN** the response includes that route and all summary metadata

#### Scenario: Unknown city
- **WHEN** a client requests routes for an unknown city slug
- **THEN** the system returns a structured not-found error

### Requirement: Inspect a complete route
The system SHALL return the route narrative, ordered stop previews, map coordinates, arrival radius, challenge type, and editorial verification state.

#### Scenario: Stops are ordered
- **WHEN** a client requests a route detail
- **THEN** stops are returned in ascending route position

#### Scenario: Demonstration copy is identified
- **WHEN** a route contains content that has not completed publication review
- **THEN** the response identifies it as demonstration content requiring verification
