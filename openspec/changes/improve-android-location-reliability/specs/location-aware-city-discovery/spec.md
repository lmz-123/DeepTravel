## MODIFIED Requirements

### Requirement: Cold discovery entry selects a supported backend city without making geocoding a location gate
On cold entry, the client SHALL perform a bounded real current-position attempt. A fresh coordinate SHALL count as successful location independently of reverse-geocoder availability. The client SHALL attempt to identify a selectable backend city from all available platform administrative-name candidates and backend city names/slugs, then from existing published route centers inside the supported-city recognition limit. If no supported city matches, it SHALL retain Shenzhen/default content while preserving the successful coordinate for truthful distance work where applicable.

#### Scenario: Geocoder fails after coordinate acquisition
- **WHEN** Android returns a fresh coordinate but reverse geocoding fails, times out, or returns no address
- **THEN** discovery treats location acquisition as successful, attempts route-center city recognition, and does not present a GPS acquisition failure

#### Scenario: Platform returns a district or English city
- **WHEN** any returned administrative candidate or backend slug unambiguously identifies a selectable city
- **THEN** discovery selects that city without requiring an exact Chinese display-name match

#### Scenario: Coordinate is outside supported cities
- **WHEN** no locality candidate matches and no published route center is inside the supported-city recognition limit
- **THEN** discovery retains Shenzhen/default browsing without fabricating a distance or claiming that location services are disabled

### Requirement: Android discovery acquisition uses bounded LocationManager directly
Android discovery SHALL force Android LocationManager rather than Google FusedLocationProviderClient and SHALL place its timeout in platform location settings so native work is cancelled. After the fresh attempt fails, it MAY use a last-known LocationManager position only when the sample is at most 30 seconds old. Permission denial and disabled services SHALL remain distinct failures.

#### Scenario: Domestic Android requests location
- **WHEN** discovery requests a position on Android
- **THEN** the client starts one bounded forced-LocationManager request without first waiting for Google FusedLocationProviderClient

#### Scenario: Fresh LocationManager request fails but cache is eligible
- **WHEN** the fresh Android request fails and a last-known LocationManager sample is no more than 30 seconds old
- **THEN** discovery may use the cached coordinate and marks the strategy as cached for diagnostics

#### Scenario: Cache is stale
- **WHEN** the only cached position is older than 30 seconds
- **THEN** discovery rejects it and preserves normal failure fallback without a distance label

### Requirement: Successful discovery coordinates remain transient and diagnosable
Discovery coordinates, locality text, and calculated distances MUST remain transient and MUST NOT be written to runtime diagnostics. Diagnostics MAY contain provider strategy, stage, elapsed time, cached/fresh status, accuracy bucket, city-match strategy, and failure category.

#### Scenario: Discovery emits success diagnostics
- **WHEN** location and city resolution complete
- **THEN** the event identifies coarse strategy and timing without coordinates, locality/address text, or calculated distance

#### Scenario: Discovery emits failure diagnostics
- **WHEN** permission, service, provider, geocoder, cache, or city resolution fails
- **THEN** the event identifies the failed stage and category without a raw platform message or location value
