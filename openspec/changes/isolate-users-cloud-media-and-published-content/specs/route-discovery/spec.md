## MODIFIED Requirements

### Requirement: Browse published routes by city
The system SHALL return only cities having at least one explicitly published route and SHALL return only routes whose status is `published` with a publication timestamp. Summaries SHALL include title, theme, duration, distance, difficulty, featured state and absolute backend-configured cloud cover URL.

#### Scenario: Featured route is discoverable
- **WHEN** a client requests routes for a city that has a featured published route
- **THEN** the response includes that route and all summary metadata

#### Scenario: City has only draft or verified routes
- **WHEN** a client lists cities or requests routes for that city
- **THEN** the city is absent from discovery and no non-published route metadata is returned

#### Scenario: Unknown city
- **WHEN** a client requests routes for an unknown city slug
- **THEN** the system returns a structured not-found error

### Requirement: Inspect a complete route
The system SHALL return a complete route only when it is explicitly published, including narrative, ordered stop or fragment previews, map triggers, configured interactions, editorial review state and absolute backend-configured media URLs.

#### Scenario: Stops are ordered
- **WHEN** a client requests a published route detail
- **THEN** stops or fragments are returned in ascending route position

#### Scenario: Non-published route slug is requested
- **WHEN** a route is draft, under review, verified but offline, or archived
- **THEN** the public detail API returns the same structured not-found response as an unknown slug

#### Scenario: Demonstration copy is identified
- **WHEN** a published field-test route contains claims that have not completed editorial or field review
- **THEN** the response identifies the review state without changing the route's explicit publication state

