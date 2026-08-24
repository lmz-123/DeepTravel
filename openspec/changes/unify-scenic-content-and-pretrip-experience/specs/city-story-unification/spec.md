## Purpose

将既有首页听故事与城市故事收敛到同一份经过审核的城市故事身份、正文和音轨，使旅行者只面对一个入口，运营迁移也不会复制或分叉内容版本。

## ADDED Requirements

### Requirement: One public city-story collection and entry
The system SHALL expose one traveler-facing “城市故事” collection at the current city-story location. Existing eligible home-listening stories SHALL appear through that collection, and the client MUST NOT present a separate “首页听故事” collection or competing entry.

#### Scenario: Existing home story is eligible
- **WHEN** a city has an approved and published legacy home-listening story
- **THEN** it appears in the city-story collection with its existing title, cover, introduction, and approved audio

#### Scenario: Traveler opens a city story
- **WHEN** the traveler activates a card in the city-story collection
- **THEN** the shared city-story listening/reading surface opens without routing through a second product entry

### Requirement: Canonical content is reused without duplication
Unified city stories SHALL reference the existing canonical story arc or fragment, reviewed transcript lineage, and approved narration track. Migration MUST NOT copy story bodies or media bytes, and a later canonical revision SHALL invalidate stale presentation approval according to existing lifecycle rules.

#### Scenario: Legacy home publication is migrated
- **WHEN** migration encounters a published home story backed by a story arc and approved track
- **THEN** it creates or reuses one city-story catalog identity and placement that reference the same arc and track without uploading another media object

#### Scenario: Migration is repeated
- **WHEN** the same migration runs again after a partial retry or deployment
- **THEN** stable source identity produces the same catalog/placement records without duplicate stories or objects

### Requirement: Compatibility reads delegate to the unified catalog
Legacy public home-story read endpoints MAY remain during a measured compatibility window, but they SHALL resolve eligible data from the unified city-story projection and MUST NOT remain an independently editable or publishable source.

#### Scenario: Older client requests a random home story
- **WHEN** a supported older client calls the legacy random-story endpoint during the compatibility window
- **THEN** the endpoint selects from eligible unified city stories and returns its compatible response shape

#### Scenario: Unified story becomes ineligible
- **WHEN** its canonical story or approved track is withdrawn or becomes stale
- **THEN** both the unified entry and compatibility read exclude it consistently
