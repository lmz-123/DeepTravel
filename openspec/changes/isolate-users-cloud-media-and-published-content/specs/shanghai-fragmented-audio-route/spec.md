## Purpose

Replace Shanghai's public quiz-first experience with the same sourced, location-triggered fragmented audio loop used in Shenzhen while keeping all destination content backend-configured.

## ADDED Requirements

### Requirement: Shanghai publishes a five-fragment audio route
Shanghai SHALL expose one management-published route with exactly five ordered, sourced story fragments, location triggers, complete transcripts, cloud-hosted narration, safe photo observations and a route-configured reconstruction.

#### Scenario: Traveler discovers Shanghai
- **WHEN** the client requests Shanghai after the new route is published
- **THEN** the public catalog returns the fragmented audio route and does not return the archived legacy quiz route for new starts

#### Scenario: Traveler opens route detail
- **WHEN** the route detail is requested
- **THEN** all preview copy, cover, fragment metadata and media URLs come from the backend without Shanghai constants in Flutter

### Requirement: Shanghai progression does not require quiz answers
The new Shanghai route SHALL progress through trigger eligibility, narration acknowledgement and any configured photo mission. It MUST NOT require multiple-choice answers or expose answer submission UI.

#### Scenario: Passive fragment finishes playback
- **WHEN** its configured completion threshold is acknowledged
- **THEN** the fragment is collected and the next dependency may become eligible without an answer

#### Scenario: Photo fragment finishes playback
- **WHEN** playback is acknowledged and accepted evidence exists or the safe postponement policy permits continuation
- **THEN** progression follows configured mission rules without a quiz answer

### Requirement: Shanghai content forms one factual causal story
The five fragments SHALL answer one central question about how Shanghai's former concession-era residential streets, architecture, changing uses, preservation choices and contemporary city-walk attention became layered in the present place. Substantive claims MUST link to named sources and interpretations MUST be labeled.

#### Scenario: Traveler collects all fragments
- **WHEN** all five fragments are collected
- **THEN** reconstruction uses route-supplied causal items and unlocks one coherent sourced story rather than five isolated architecture facts

#### Scenario: Claim review is incomplete
- **WHEN** a source, claim or field relationship remains under review
- **THEN** publication validation reports its state and the narration does not present interpretation as settled fact

### Requirement: Legacy Shanghai journeys remain compatible
The old quiz route SHALL be archived for discovery only after the new route is published. Existing owners SHALL retain their route detail, answer history and completion path.

#### Scenario: Existing quiz journey resumes
- **WHEN** its owner resumes after the old route is archived
- **THEN** the legacy answer loop continues unchanged and no progress is migrated into the new route

