## MODIFIED Requirements

### Requirement: Arrival confirmation
The system SHALL accept a production fragment trigger when submitted location evidence satisfies the current trigger-region policy, and SHALL permit explicit demo triggering only when demo triggering is enabled.

#### Scenario: Location is near the stop
- **WHEN** the guest submits qualifying location evidence within the current eligible fragment's trigger region
- **THEN** the current fragment becomes triggered without duplicating an existing trigger

#### Scenario: Location is too far away
- **WHEN** the guest submits location evidence outside the current eligible fragment's trigger region
- **THEN** the system rejects the trigger and returns a structured proximity conflict

#### Scenario: Demo arrival is disabled
- **WHEN** the guest requests demo triggering while demo triggering is disabled
- **THEN** the system rejects the request

#### Scenario: Stable location is inside the region
- **WHEN** an active guest journey submits qualifying location-trigger evidence for an eligible fragment
- **THEN** the system records the fragment as triggered and returns its current interaction state

#### Scenario: Location is outside the region
- **WHEN** submitted production trigger evidence is outside the eligible fragment radius
- **THEN** the system rejects the trigger and returns a structured proximity conflict without collecting the fragment

#### Scenario: Fragment was already triggered
- **WHEN** the same guest journey acknowledges an already-triggered fragment
- **THEN** the system returns the existing trigger state without enqueuing or collecting a duplicate

#### Scenario: Demo triggering is disabled
- **WHEN** the guest requests demo triggering while demo triggering is disabled
- **THEN** the system rejects the request

## ADDED Requirements

### Requirement: Fragment interaction progression
The system SHALL progress each fragment according to its declared passive, photo-mission, or reconstruction interaction rule rather than requiring a multiple-choice answer for every stop.

#### Scenario: Passive completion is acknowledged
- **WHEN** the current passive fragment reaches its authored playback or transcript completion rule
- **THEN** the system records it as collected and exposes newly eligible dependent fragments

#### Scenario: Required photo is missing
- **WHEN** a photo-mission fragment has triggered but accepted evidence is absent
- **THEN** the system keeps that fragment mission-pending without erasing later geographically triggered state

#### Scenario: Required photo is accepted
- **WHEN** accepted journey-scoped evidence is linked to the current photo mission
- **THEN** the system collects the fragment exactly once and updates route progress

### Requirement: Fragment-complete recap gating
The system SHALL unlock final reconstruction only after all required route fragments are collected and SHALL mark the journey completed only after reconstruction succeeds.

#### Scenario: Reconstruction requested too early
- **WHEN** the guest requests reconstruction before all required fragments are collected
- **THEN** the system returns a state-conflict error with non-spoiling progress details

#### Scenario: Final reconstruction succeeds
- **WHEN** the guest submits a correct authored relationship set after collecting all required fragments
- **THEN** the journey becomes completed and a sourced complete-story recap is available

## REMOVED Requirements

### Requirement: Observation answer feedback
**Reason**: Universal correctness-scored multiple-choice interaction conflicts with the new hands-free fragmented-history loop and made every stop feel mechanically identical.

**Migration**: Existing challenge records may remain readable for legacy/demo routes, but new fragmented routes declare passive, photo-mission, or reconstruction interactions and do not require answer submission.

### Requirement: Ordered progression and recap
**Reason**: Strict answer-before-advance progression is replaced by location-triggered collection with authored dependencies and final causal reconstruction.

**Migration**: Journey progression is derived from fragment trigger, mission, collection, and reconstruction state. Legacy completed journeys retain their existing recap representation.
