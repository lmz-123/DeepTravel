## Purpose

让同一份经过审核的城市故事安全复用于首页、旅行前、现场讲解和旅行后内容，同时保留明确的事实来源、现实观察细节与发布边界。

## ADDED Requirements

### Requirement: Canonical story reuse
The system SHALL create each catalog story from a canonical published story fragment or complete story arc, SHALL keep every channel presentation in the same reviewed source lineage, and SHALL NOT copy its transcript or narration into a second independently editable body or media file. A catalog story SHALL support separately configured approved short-preview and on-site-complete presentation variants when both exist.

#### Scenario: One story appears in multiple channels
- **WHEN** a published catalog story is eligible for home, pre-trip, on-site, and post-trip channels
- **THEN** every channel resolves the same canonical story identity and reviewed source lineage using its configured approved short or complete presentation variant

#### Scenario: Short and complete audio are configured
- **WHEN** an editor publishes a short-preview track for home/pre-trip and a complete track for on-site use
- **THEN** each channel returns its configured track and both tracks retain reviewed links to the same canonical story lineage

#### Scenario: Canonical content changes
- **WHEN** the canonical transcript changes after a catalog distribution was approved
- **THEN** the system invalidates incompatible narration or distribution approval until the updated content is reviewed

### Requirement: Complete story metadata
The system SHALL associate each catalog story with a title, summary, cover, audio and transcript availability, city, optional district, one or more themes, related points, related stories, content type, place context, at least one observable real-world detail, optional on-site attention hint, sources, fact status, and editorial review status. Related-story order SHALL be editorial guidance and MUST NOT force completion.

#### Scenario: Required metadata is missing
- **WHEN** an editor attempts to publish a catalog story without required context, observable detail, source, fact status, or approved canonical media
- **THEN** publication is rejected with field-specific reasons

#### Scenario: Uncertain historical claim is published
- **WHEN** a story contains a disputed or uncertain historical claim
- **THEN** the public wording includes the approved natural-language qualification and exposes no unsupported certainty

#### Scenario: Related stories are configured
- **WHEN** an editor relates two reviewed stories and assigns an advisory order
- **THEN** public eligible channels can expose the relation without requiring either story to be completed first

### Requirement: Backend-driven content classification
The system SHALL support at least street-corner stories, city small things, overlooked details, city people or community stories, roaming theme introductions, and complete story reconstructions, while allowing published content values and tags to be added without a client release.

#### Scenario: New tag is published
- **WHEN** an editor adds a new approved theme or experience tag to a catalog story
- **THEN** clients receive and display it as backend data without requiring a hardcoded client enum

### Requirement: Editorial duration guidance
The system SHALL calculate story duration from the approved audio or transcript estimate and SHALL warn editors when it falls outside three to eight minutes without using that guidance as the sole publication blocker.

#### Scenario: Story is longer than eight minutes
- **WHEN** an otherwise valid story has an estimated duration over eight minutes
- **THEN** the editor receives a duration warning and can continue through the normal review process

### Requirement: City home modules
The system SHALL return published catalog placements for the current city in the five modules “今天听一段城市故事”, “3 分钟了解一个街角”, “一座城市的一件小事”, “你路过但没注意的细节”, and “今天适合去哪儿”, subject to channel eligibility and editorial order. “今天听一段城市故事” SHALL be identified as the primary home entry and the other modules SHALL remain independently accessible.

#### Scenario: Current city has published placements
- **WHEN** the client requests home content for a city with eligible published placements
- **THEN** the response contains the configured modules and only published catalog stories for that city

#### Scenario: Primary story entry is configured
- **WHEN** the current city has an eligible “今天听一段城市故事” placement
- **THEN** the response identifies that module as the primary home story entry

#### Scenario: Current city has no module content
- **WHEN** the client requests home content for a city with no eligible placement
- **THEN** the response includes an explicit empty reason, a city-switch action, and published fallback city recommendations when configured

### Requirement: No quiz obligations
The catalog story contract SHALL allow one canonical story lineage to be placed in home short-story, pre-trip preview, on-site narration, post-trip text recap, and footprint channels, and SHALL NOT require an answer, correctness result, examination, or forced completion task at its conclusion.

#### Scenario: Story playback completes
- **WHEN** a user finishes listening to or reading a catalog story
- **THEN** the user can leave or continue voluntarily without answering a question

#### Scenario: Story is reused after travel
- **WHEN** an eligible story is included in a text recap or footprint view
- **THEN** it resolves the same canonical story identity and reviewed lineage used before and during the trip
