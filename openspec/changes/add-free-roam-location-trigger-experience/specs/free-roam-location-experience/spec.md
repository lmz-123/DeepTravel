## Purpose

让正式现场音频旅程以每个已发布故事点的独立定位区域驱动自由漫游，并把空间触发顺序、故事因果顺序和可恢复进度明确分离。

## ADDED Requirements

### Requirement: Real-location free roaming is the default field experience
For a fragmented audio tour, the system SHALL treat real-location free roaming as the formal field experience. Every published and untriggered story point in the active tour SHALL be evaluated independently against its own trigger-region policy, and authored position or story dependency MUST NOT gate a qualifying real-location trigger. A recommended order MAY be displayed as editorial reference but MUST NOT be a journey completion condition.

#### Scenario: Reach a later story point first
- **WHEN** the traveler reaches the valid trigger region for a published later-position story point before visiting earlier points
- **THEN** that point triggers exactly once and all skipped points remain independently available

#### Scenario: Skip and return
- **WHEN** the traveler passes over one untriggered point, visits another point, and later enters the skipped point's valid trigger region
- **THEN** the skipped point can trigger without requiring the traveler to repeat or undo the intervening visit

#### Scenario: Authored dependency is unmet
- **WHEN** a real-location trigger qualifies for a point whose story dependency has not yet been collected
- **THEN** the point triggers and the dependency remains available for later collection rather than blocking the field event

#### Scenario: Point is no longer published
- **WHEN** a point is no longer eligible for public field triggering before the traveler first triggers it
- **THEN** the system does not create a new trigger, while previously saved owner progress remains readable

### Requirement: Independent trigger-region policy
Each field story point SHALL carry its own server-configured coordinates and trigger-region policy. Trigger eligibility SHALL be based on the point's publication eligibility and its region policy, including any configured accuracy, stable-sample, hysteresis, cooldown, journey ownership, and idempotency safeguards; route position, recommended order, quiz state, photo evidence, observation response, and narrative dependency MUST NOT be trigger prerequisites.

#### Scenario: Two points have different radii
- **WHEN** the traveler is inside point A's configured entry radius but outside point B's configured entry radius
- **THEN** point A may qualify and point B remains untriggered even if point B appears earlier in the authored order

#### Scenario: Multiple points qualify together
- **WHEN** the same real sample completes the configured policy for multiple untriggered points
- **THEN** the client selects the nearest fully qualified point with a deterministic tie break, triggers at most one point for that evaluation, and leaves the others eligible for later samples

#### Scenario: Photo was not taken
- **WHEN** the traveler enters a point's valid region without capturing optional evidence
- **THEN** photo absence does not affect triggering, narration collection, or later reconstruction eligibility

### Requirement: Story-point awareness without replacing the existing node rail
During a formal journey, the client SHALL preserve the existing node rail and node pages rather than replacing them with a new nearby-point list or reducing the experience to a next-stop instruction. Every published node SHALL remain visible and selectable regardless of authored position. Selecting a node SHALL expose its backend story-point preview copy, backend-derived theme, expected listening duration, heard or unheard state, and transient proximity/trigger state in a detail region placed immediately below the node rail and before the audio playback card, without requiring a map. The rail SHALL use the actual backend node count, SHALL NOT assume five nodes, and SHALL adapt node visual size and spacing to density while keeping controls safely usable and scrollable when needed. Selection of an untriggered node MUST NOT create a trigger, reveal narration, start playback, or mark progress. Without a current position the client SHALL preserve backend reference order and MUST NOT display a calculated distance.

#### Scenario: Current position is available
- **WHEN** the client receives a usable real-location sample during an active tour
- **THEN** the selected-node status updates its transient distance and proximity without reordering or replacing the original node rail and without changing the authored story order

#### Scenario: Position is unavailable
- **WHEN** permission, service, timeout, or acquisition failure leaves no current position
- **THEN** the client keeps all known story points visible and selectable in the original backend reference order, keeps previously triggered points usable, explains that automatic triggering is paused, and shows no false distance

#### Scenario: Backend adds a new theme
- **WHEN** a published story point carries a previously unknown safe theme or experience label
- **THEN** the client displays the backend value without requiring a client release

#### Scenario: Backend changes node density
- **WHEN** a route publishes an arbitrary number of story nodes rather than exactly five
- **THEN** the client renders the exact count and adapts the rail's spacing or visual node size without dropping, clipping, or inventing nodes

### Requirement: Triggered points remain reviewable in the formal journey
Every triggered or collected story point SHALL remain selectable from the active journey so the traveler can reopen its node page, read its transcript, and listen again. Reviewing or replaying a point MUST NOT create another trigger, change the spatial progress order, reduce collected progress, or satisfy an unvisited point.

Untriggered published points SHALL also remain selectable from the node rail for informational status only. Their narration, transcript and collection state SHALL remain unavailable until the independent location policy triggers that point.

#### Scenario: Select an untriggered point
- **WHEN** the traveler selects an untriggered published point from the original node rail
- **THEN** the client highlights that point and shows its safe backend preview copy, theme, duration and location status below the rail and above the audio card without triggering, revealing, playing or collecting it

#### Scenario: Reopen a heard point
- **WHEN** the traveler selects a previously collected point while the formal journey remains active
- **THEN** its story and replay controls open without starting another trigger or changing the next location candidate

#### Scenario: Reopen a triggered but unfinished point
- **WHEN** the traveler selects an already triggered point whose narration was interrupted
- **THEN** the saved point page opens at its recoverable playback/progress state and other locations remain independently triggerable

### Requirement: Free roaming retains location privacy
The system SHALL keep continuous real-location samples and calculated nearby distances transient to the client. It MUST NOT persist a breadcrumb trail, transmit non-trigger samples, or include raw coordinates and calculated distances in routine logs. A qualifying trigger request MAY transmit the single evidence sample required by the existing server validation and SHALL continue to discard raw coordinates after evaluation.

#### Scenario: Traveler walks between points
- **WHEN** location monitoring produces samples that do not trigger a story point
- **THEN** those samples update transient nearby state only and are not uploaded or stored as a route trace
