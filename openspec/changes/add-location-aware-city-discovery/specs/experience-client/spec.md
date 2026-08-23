## ADDED Requirements

### Requirement: Discovery explains location before an undetermined permission request
The client SHALL present concise Simplified Chinese purpose copy before its first discovery-related operating-system permission request when permission is undetermined. The copy SHALL explain that location helps choose the initial city and sort nearby scenic areas and that no continuous trail is retained. The traveler SHALL be able to decline and continue with Shenzhen plus the normal city selector.

#### Scenario: Cold entry needs permission
- **WHEN** discovery cold entry needs an operating-system location decision
- **THEN** the app explains the purpose before invoking the permission surface and offers continue and decline actions

#### Scenario: Traveler declines
- **WHEN** the traveler declines the purpose action
- **THEN** no permission request is made and discovery remains usable with Shenzhen and manual city selection

### Requirement: Home cards remain one card per scenic area
The client SHALL retain the original route/scenic-area home card visual structure and existing opening behavior. Each home card SHALL represent one published scenic area, SHALL use that area's route summary, and MAY show an optional distance calculated to that area's center. Internal story nodes MUST NOT become independent home cards. The home carousel SHALL reset to the first card after a completed refresh or city change. Route details and journey presentation SHALL remain unchanged.

#### Scenario: Current distance is available
- **WHEN** a scenic-area card has distance calculated from the current successful one-shot position to its center
- **THEN** the card shows an honest human-readable distance while retaining its original route/scenic-area metadata

#### Scenario: Distance is unavailable
- **WHEN** a scenic-area card is shown without an accepted current sample or valid center
- **THEN** the card shows its published metadata but no zero, placeholder, estimated, or stale distance

#### Scenario: Scenic-area card is opened
- **WHEN** the traveler activates a home scenic-area card
- **THEN** the existing route flow opens with that area's internal story nodes still contained inside it and in their existing order

### Requirement: Discovery failure and empty content stay actionable
Location failures SHALL leave known content and the existing backend-driven city selector usable. If the active city has no public scenic areas, discovery SHALL show a clear empty state with the existing city-switch entry rather than a blank carousel.

#### Scenario: Location fails with known content
- **WHEN** a location attempt fails while the active city has published scenic areas
- **THEN** the scenic-area cards remain visible in backend order and the selector remains available

#### Scenario: Active city has no published points
- **WHEN** the latest discovery response contains no eligible scenic area for the active city
- **THEN** the page shows an empty explanation and a city-switch action
