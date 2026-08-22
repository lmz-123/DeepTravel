## MODIFIED Requirements

### Requirement: Inspect a complete route
The system SHALL return the route narrative, ordered stop or fragment previews, map coordinates, arrival radius, configured interaction type, editorial verification state, a backward-compatible default narration URL, and every complete published narration voice profile with its per-fragment public track mapping. All profile labels, order, metadata, and URLs SHALL come from the backend.

#### Scenario: Stops are ordered
- **WHEN** a client requests a published route detail
- **THEN** stops or fragments are returned in ascending route position

#### Scenario: Voice profiles are available
- **WHEN** two published profiles have approved current-script tracks for every narrated fragment
- **THEN** route detail identifies both profiles, the route default, and the matching audio URL for each fragment

#### Scenario: Incomplete profile exists
- **WHEN** a profile has only some required fragment tracks
- **THEN** neither the profile nor its partial track metadata appears in the public route payload

#### Scenario: Demonstration copy is identified
- **WHEN** a route contains content that has not completed publication review
- **THEN** the response identifies it as demonstration content requiring verification

