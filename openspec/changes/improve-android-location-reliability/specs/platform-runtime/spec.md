## ADDED Requirements

### Requirement: Location diagnostics preserve privacy while identifying failure stage
The client SHALL emit coarse location diagnostics to the existing runtime-log channel when configured. Events SHALL identify operation, stage, provider strategy, elapsed-time bucket or milliseconds, permission/failure category, cached/fresh state, and accuracy bucket as applicable. They MUST NOT contain coordinates, locality/address text, calculated distance, a breadcrumb trail, or raw platform exception messages.

#### Scenario: Operator investigates Android acquisition failure
- **WHEN** a configured release encounters a location permission, provider, timeout, cache, geocoder, city-match, or stream failure
- **THEN** the CMS client-log source can distinguish the stage and provider strategy without exposing the traveler's location

#### Scenario: Runtime log ingestion is disabled
- **WHEN** the release has no runtime log endpoint or token
- **THEN** location behavior remains functional and no diagnostic network request is attempted
