## Purpose

Use bounded one-shot location events to choose a useful initial city and sort only home scenic points, without city geometry, accuracy gating, persistent discovery modes, or location tracking.

## ADDED Requirements

### Requirement: Cold discovery entry selects a backend city or Shenzhen
On cold entry to discovery, the client SHALL explain the location purpose before an undetermined operating-system permission request and SHALL perform at most one bounded real current-position attempt. It SHALL match the platform-resolved locality only against backend-provided selectable cities that contain published scenic/story points. A successful match SHALL become the initial city; otherwise the client SHALL retain the existing Shenzhen default. The client MUST NOT use city coordinates, recognition radii, polygons, or distance-to-city calculations.

#### Scenario: Locality matches a selectable city with points
- **WHEN** cold-entry acquisition yields a usable position and platform locality matching a backend city with published scenic/story points
- **THEN** the city selector shows that city and its home points are eligible for distance ordering

#### Scenario: Locality has no published discovery content
- **WHEN** locality is unavailable, unmatched, or matches no selectable city containing a published point
- **THEN** discovery shows Shenzhen using the existing default behavior

#### Scenario: Backend adds a selectable city
- **WHEN** a newly published city and its points appear in the backend catalog and the platform locality matches its backend name
- **THEN** cold-entry selection can use it without adding a city to Flutter code

### Requirement: Refresh and city switch locate only for active-city point ordering
An explicit home refresh SHALL keep the current city and perform one bounded current-location attempt. A manual city switch SHALL apply the backend-provided selected city first and then perform one bounded current-location attempt. In both cases, a successfully acquired position SHALL be used only to sort the active city's home scenic/story points; location MUST NOT replace the active city or reorder content inside a route.

#### Scenario: Refresh succeeds
- **WHEN** the traveler refreshes home and a current position is returned
- **THEN** the current city remains selected and its home scenic/story point cards are reordered by distance

#### Scenario: Traveler switches cities
- **WHEN** the traveler selects another backend city and location acquisition completes
- **THEN** the chosen city remains active regardless of locality and only that city's home point cards are distance-sorted

#### Scenario: Route is opened after ranking
- **WHEN** a traveler opens a distance-ranked point card
- **THEN** the parent route retains its existing fragment/stop order and journey behavior

### Requirement: Discovery ordering does not gate on reported accuracy
The client SHALL use every successfully acquired real one-shot platform position for discovery distance calculations. Reported horizontal accuracy MUST NOT be used to accept, reject, reorder, or label a discovery position.

#### Scenario: Position is returned with any reported accuracy
- **WHEN** a discovery event successfully returns a real current position
- **THEN** the client calculates and may display point distances without branching on its reported accuracy

#### Scenario: Platform reports low accuracy
- **WHEN** the successful position includes a large, missing, or otherwise low-quality accuracy estimate
- **THEN** discovery still uses its coordinates for the same distance ordering and does not show an accuracy warning

### Requirement: Location failure keeps discovery usable
Declined purpose copy, denied permission, disabled services, timeout, geocoding failure, or acquisition failure MUST NOT block discovery. Cold-entry failure SHALL retain Shenzhen; refresh or switch failure SHALL retain the active city. All failures SHALL preserve backend point order, omit distance copy, and keep the backend-driven city selector usable.

#### Scenario: Permission is declined or denied on cold entry
- **WHEN** the traveler declines the explanation or the operating system denies location permission
- **THEN** discovery remains usable in Shenzhen and exposes normal manual city selection

#### Scenario: Refresh or switch acquisition fails
- **WHEN** a refresh or city-switch location attempt fails or is unusable
- **THEN** the selected city remains active, cards use backend order, and no old or fabricated distance is shown

### Requirement: Discovery does not persist mode or location history
The system MUST keep discovery coordinates, locality, timestamps, and calculated distances transient in memory. It MUST NOT persist or transmit those values, start a continuous subscription, store a first-location-processed marker, or add a persisted automatic/manual discovery mode or city preference for this feature. Reported accuracy is not part of discovery business state.

#### Scenario: A discovery event completes
- **WHEN** cold entry, refresh, or city-switch acquisition completes
- **THEN** no raw position, distance, processed flag, or discovery mode is written to local storage or sent to the API/admin service

#### Scenario: Discovery diagnostics are emitted
- **WHEN** discovery reports an outcome to runtime diagnostics
- **THEN** the report contains only a coarse outcome category and no raw or derived location value
