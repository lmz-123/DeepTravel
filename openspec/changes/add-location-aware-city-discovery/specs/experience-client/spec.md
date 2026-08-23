## ADDED Requirements

### Requirement: Discovery explains location before an undetermined permission request
The client SHALL present concise Simplified Chinese purpose copy before its first discovery-related operating-system permission request when permission is undetermined. The copy SHALL explain that location helps choose the initial city and sort nearby scenic points and that no continuous trail is retained. The traveler SHALL be able to decline and continue with Shenzhen plus the normal city selector.

#### Scenario: Cold entry needs permission
- **WHEN** discovery cold entry needs an operating-system location decision
- **THEN** the app explains the purpose before invoking the permission surface and offers continue and decline actions

#### Scenario: Traveler declines
- **WHEN** the traveler declines the purpose action
- **THEN** no permission request is made and discovery remains usable with Shenzhen and manual city selection

### Requirement: Home cards present scenic points without redesigning the route flow
The client SHALL retain the current home card visual structure and existing parent-route opening behavior while making each home card's title, tags, and optional distance describe one published scenic/story point. The home carousel SHALL reset to the first card after a completed refresh or city change. Route details and journey presentation SHALL remain unchanged.

#### Scenario: Current distance is available
- **WHEN** a point card has distance calculated from the current successful one-shot position
- **THEN** the card shows an honest human-readable distance and backend-provided point tags

#### Scenario: Distance is unavailable
- **WHEN** a point card is shown without an accepted current sample
- **THEN** the card shows its published metadata and tags but no zero, placeholder, estimated, or stale distance

#### Scenario: Point card is opened
- **WHEN** the traveler activates a home point card
- **THEN** the existing parent-route flow opens without a new route recommendation or changed route order

### Requirement: Discovery failure and empty content stay actionable
Location failures SHALL leave known content and the existing backend-driven city selector usable. If the active city has no public home points, discovery SHALL show a clear empty state with the existing city-switch entry rather than a blank carousel.

#### Scenario: Location fails with known content
- **WHEN** a location attempt fails while the active city has published points
- **THEN** the points remain visible in backend order and the selector remains available

#### Scenario: Active city has no published points
- **WHEN** the latest discovery response contains no eligible point for the active city
- **THEN** the page shows an empty explanation and a city-switch action
