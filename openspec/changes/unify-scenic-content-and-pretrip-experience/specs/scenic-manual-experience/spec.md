## Purpose

让旅行者在打开景点城市手册时先获得简短、可听读的出发前背景，并在同一手册中看到后台配置的景点标签，同时保持全局音频连续性与现场旅程边界。

## ADDED Requirements

### Requirement: Pre-departure is the first scenic manual surface
For each published scenic area with published pre-departure content, the city manual SHALL present a concise city/scenic introduction as its first content surface before deeper route, fragment, map, task, or journey material. The introduction SHALL be available without arrival, location permission, or an active journey and SHALL contain reviewed text and its matching approved narration.

#### Scenario: Traveler opens a configured scenic manual
- **WHEN** a traveler opens the city manual for a scenic area with published pre-departure content
- **THEN** the first content surface presents the configured concise introduction and its audio action before deeper manual sections

#### Scenario: Traveler is away from the scenic area
- **WHEN** the traveler opens that manual without location permission or an active journey
- **THEN** the pre-departure text and audio remain available and no arrival gate is shown

#### Scenario: Scenic area has no published pre-departure content
- **WHEN** a manual has no eligible published pre-departure revision
- **THEN** the client opens the normal manual overview without inventing copy, exposing draft content, or blocking access

### Requirement: Pre-departure audio uses a compact control
The pre-departure surface SHALL expose one accessible play/pause/replay icon for its narration and MUST NOT render a large audio card, seek bar, progress indicator, elapsed time, remaining time, or duration control on that surface.

#### Scenario: Narration is ready
- **WHEN** the traveler views a pre-departure introduction with available narration
- **THEN** one clearly labelled icon starts playback and reflects play, pause, and ended/replay states without showing progress UI

#### Scenario: Narration cannot be prepared
- **WHEN** the approved narration is temporarily unavailable
- **THEN** the text remains readable and the icon exposes a recoverable error/retry state without a false playing state

### Requirement: Scenic narration batches include pre-departure
When a scenic area has pre-departure text, administration coverage and batch narration generation SHALL treat that introduction and all later story nodes as one scenic content set using the selected voice profile. Regenerate-all MUST refresh both the introduction and every node; missing-only generation MUST include a missing or stale introduction without a separate generation command.

#### Scenario: Regenerate all scenic narration
- **WHEN** an operator regenerates all narration for a scenic area with pre-departure text and story nodes
- **THEN** matching tracks are generated for the introduction and all nodes in one batch result

### Requirement: One global audio session includes pre-departure
Pre-departure narration, city-story narration, and on-site narration SHALL participate in one global active-audio session. Starting one source SHALL stop the previously active source atomically; leaving the source page SHALL preserve eligible playback, and the existing floating orb SHALL reflect and restore the active source.

#### Scenario: Traveler leaves while pre-departure audio plays
- **WHEN** pre-departure narration is playing and the traveler navigates away from the manual
- **THEN** playback continues, the floating orb represents that narration, and activating the orb returns to its source context

#### Scenario: Traveler starts on-site narration
- **WHEN** pre-departure narration is active and the traveler starts a fragment narration
- **THEN** pre-departure playback stops before the fragment becomes the single active audio source

#### Scenario: Traveler pauses from the source surface
- **WHEN** the traveler activates the compact icon while its narration is playing
- **THEN** the global session becomes paused and the orb and source icon show the same state

### Requirement: Scenic node tags are visible and server-driven
The city manual SHALL render the ordered published `experience_tags` of both legacy stops and managed story fragments as generic compact labels associated with their node. Unknown valid values SHALL render without a client allowlist, and tags MUST NOT create or reorder home scenic-area cards.

#### Scenario: Published fragment has configured tags
- **WHEN** a manual contains a published fragment tagged “老建筑” and “适合一个人”
- **THEN** both labels appear with that fragment in configured order

#### Scenario: Released client receives a new tag
- **WHEN** the backend publishes a valid tag value unknown to the installed client
- **THEN** the client renders it through the same tag component without changing journey behavior

#### Scenario: Node has no tags
- **WHEN** a published stop or fragment has an empty tag list
- **THEN** the client omits the tag region without placeholder copy or layout gap
