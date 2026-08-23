## Purpose

让用户在尚未到达现场或开始旅程前即可理解漫游主题、听读相关故事、查看出发参考并主动准备所需内容，而不引入考试或强制任务。

## ADDED Requirements

### Requirement: Pre-trip knowledge preview
The system SHALL let users listen to or read a published theme story before arrival and view the route theme, estimated duration, distance, and the major story directions involved in the roam.

#### Scenario: User previews a roam away from the route
- **WHEN** a user opens a published route without being at its location or starting a journey
- **THEN** the complete pre-trip knowledge preview remains available

### Requirement: Advisory story directions
The system SHALL present story directions and recommended roaming order as editorial guidance rather than a mandatory progression sequence.

#### Scenario: User reads stories out of order
- **WHEN** a user selects a different available story direction
- **THEN** the system opens it without requiring previous items to be completed

### Requirement: Companion and departure guidance
The pre-trip response SHALL expose backend-configured companion tags and editorial safety, rest, accessibility, and weather-adaptation tips, and SHALL NOT depend on a preference questionnaire or live weather service.

#### Scenario: New companion tag is configured
- **WHEN** an editor publishes a previously unknown companion tag
- **THEN** the client displays the backend value without a code change

#### Scenario: No guidance is configured
- **WHEN** optional departure guidance is absent
- **THEN** the client omits the corresponding section without inventing advice

### Requirement: Offline preparation
The system SHALL allow users to explicitly prepare eligible published audio and transcript resources before departure and SHALL report preparation progress, completion, and recoverable failures.

#### Scenario: Preparation succeeds
- **WHEN** the user requests preparation for a published roam while online
- **THEN** eligible audio and text resources become available for offline pre-trip use

#### Scenario: One resource fails
- **WHEN** an eligible resource cannot be downloaded or verified
- **THEN** the client identifies the failed resource and offers retry without falsely marking the roam fully prepared

### Requirement: No pre-trip examination
The pre-trip experience SHALL NOT present answer submission, correctness, examinations, or location-gated comprehension tasks.

#### Scenario: User completes a preview story
- **WHEN** a pre-trip story ends
- **THEN** the user returns to optional preview choices without an examination gate
