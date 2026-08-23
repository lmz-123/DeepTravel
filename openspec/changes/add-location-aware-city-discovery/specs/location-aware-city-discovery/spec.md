## Purpose

Use bounded high-accuracy location events to choose a useful initial city and sort only home scenic points, without city geometry, persistent discovery modes, or location tracking.

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
An explicit home refresh SHALL keep the current city and perform one fresh bounded location attempt. A manual city switch SHALL apply the backend-provided selected city first and then perform one fresh bounded location attempt. In both cases, an accepted position SHALL be used only to sort the active city's home scenic/story points; location MUST NOT replace the active city or reorder content inside a route.

#### Scenario: Refresh succeeds
- **WHEN** the traveler refreshes home and an accepted position is returned
- **THEN** the current city remains selected and its home scenic/story point cards are reordered by distance

#### Scenario: Traveler switches cities
- **WHEN** the traveler selects another backend city and location acquisition completes
- **THEN** the chosen city remains active regardless of locality and only that city's home point cards are distance-sorted

#### Scenario: Route is opened after ranking
- **WHEN** a traveler opens a distance-ranked point card
- **THEN** the parent route retains its existing fragment/stop order and journey behavior

### Requirement: Discovery location quality is no worse than 25 metres
The client SHALL use a fresh real platform sample for discovery distance calculations only when its reported horizontal accuracy is at most 25 metres. A sample with worse or missing accuracy SHALL be treated as unavailable and MUST NOT produce distance ordering or a distance label.

#### Scenario: Accurate sample is returned
- **WHEN** a discovery event returns a fresh sample reporting accuracy of 25 metres or better
- **THEN** the client may calculate and display point distances from that sample

#### Scenario: Inaccurate sample is returned
- **WHEN** a discovery event returns a sample reporting accuracy worse than 25 metres
- **THEN** the client preserves backend point order and shows no distance derived from that sample

### Requirement: Location failure keeps discovery usable
Declined purpose copy, denied permission, disabled services, timeout, geocoding failure, or an unusable sample MUST NOT block discovery. Cold-entry failure SHALL retain Shenzhen; refresh or switch failure SHALL retain the active city. All failures SHALL preserve backend point order, omit distance copy, and keep the backend-driven city selector usable.

#### Scenario: Permission is declined or denied on cold entry
- **WHEN** the traveler declines the explanation or the operating system denies location permission
- **THEN** discovery remains usable in Shenzhen and exposes normal manual city selection

#### Scenario: Refresh or switch acquisition fails
- **WHEN** a refresh or city-switch location attempt fails or is unusable
- **THEN** the selected city remains active, cards use backend order, and no old or fabricated distance is shown

### Requirement: Discovery does not persist mode or location history
The system MUST keep discovery coordinates, accuracy, locality, timestamps, and calculated distances transient in memory. It MUST NOT persist or transmit those values, start a continuous subscription, store a first-location-processed marker, or add a persisted automatic/manual discovery mode or city preference for this feature.

#### Scenario: A discovery event completes
- **WHEN** cold entry, refresh, or city-switch acquisition completes
- **THEN** no raw position, distance, processed flag, or discovery mode is written to local storage or sent to the API/admin service

#### Scenario: Discovery diagnostics are emitted
- **WHEN** discovery reports an outcome to runtime diagnostics
- **THEN** the report contains only a coarse outcome category and no raw or derived location value
