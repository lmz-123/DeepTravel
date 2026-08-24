## MODIFIED Requirements

### Requirement: Formal journey location uses fresh high-accuracy Android LocationManager samples
The formal journey SHALL request continuous high-accuracy platform samples suitable for pedestrian trigger regions. On Android it SHALL force one LocationManager stream and MUST NOT first wait for Google FusedLocationProviderClient. Stopping or replacing a journey SHALL cancel the location subscription.

#### Scenario: Android journey starts
- **WHEN** a formal journey starts real location on Android
- **THEN** the tracker starts one bounded forced-LocationManager stream with the configured pedestrian sampling policy

#### Scenario: LocationManager stream fails
- **WHEN** the Android LocationManager stream reaches its update limit or reports an acquisition failure
- **THEN** the journey reports a recoverable location interruption without starting a Google provider

#### Scenario: Journey stops during acquisition
- **WHEN** the journey stops, route/account changes, or the controller is disposed
- **THEN** the active LocationManager subscription is cancelled

### Requirement: Trigger evaluation rejects stale samples before region policy
The trigger engine SHALL reject a location sample older than 15 seconds or more than five seconds in the future before evaluating any point. Fresh samples SHALL continue to use each point's configured maximum accuracy, entry radius, stable-sample count, sample window, exit radius, and deterministic nearest-point selection.

#### Scenario: Stale coordinate is otherwise inside a point
- **WHEN** a sample is geometrically inside a point but older than 15 seconds
- **THEN** it does not advance stable presence or trigger the point

#### Scenario: Fresh stable samples qualify
- **WHEN** the configured number of fresh samples satisfy accuracy and entry-radius rules inside the sample window
- **THEN** the point qualifies using the existing deterministic trigger behavior
