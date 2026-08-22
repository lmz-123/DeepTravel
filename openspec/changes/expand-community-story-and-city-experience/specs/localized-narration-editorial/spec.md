## Purpose

建立按城市限定、可审核且不会削弱史实边界的旁白编辑规则，使深圳导览像温柔同行者自然讲述，而不是机械宣读说明材料。

## ADDED Requirements

### Requirement: Shenzhen-scoped conversational rewrite
Every currently maintained Shenzhen route SHALL receive an editorial rewrite of its route title and introduction, node narration, photo guidance, and complete story. The rewrite SHALL use natural second-person Mandarin, observation-first transitions, gentle and lightly playful phrasing, concrete spatial guidance, and varied sentence rhythm, and MUST preserve every reviewed historical claim, uncertainty label, safety boundary, accessibility alternative, and source relationship.

#### Scenario: Arrive at a Shenzhen node
- **WHEN** a traveler opens a rewritten Shenzhen node
- **THEN** its narration welcomes the traveler into the current place, directs attention to a concrete visible feature, tells the story conversationally, and offers useful observation or photo guidance without repeatedly framing the experience as collecting clues

#### Scenario: Uncertain field object
- **WHEN** a Shenzhen script refers to an object whose age, function, or authenticity is not fully verified
- **THEN** the conversational wording still distinguishes observation from documented fact and does not turn interpretation into certainty

#### Scenario: Shanghai regression boundary
- **WHEN** the Shenzhen content revision is prepared and published
- **THEN** Shanghai content fields, script versions, transcript hashes, narration profiles, tracks, and publication state remain unchanged

### Requirement: Gentle playful female narration profile
The admin system SHALL support a Shenzhen narration profile whose client-facing identity describes a warm, playful female Mandarin storyteller without exposing the provider voice identifier. Every Shenzhen track published under this profile MUST pass human listening review for natural pronunciation, comfortable pace, restrained emotional expression, clean audio, and consistency with the approved transcript.

#### Scenario: Review the Shenzhen voice
- **WHEN** an editor auditions candidate tracks for the Shenzhen profile
- **THEN** the chosen track sounds like a nearby human companion rather than a broadcast announcer, retains intelligibility outdoors, and records the reviewed settings and transcript provenance

#### Scenario: Publish incomplete Shenzhen coverage
- **WHEN** one or more required Shenzhen node or home-story tracks are missing, stale, failed, or unapproved for the selected profile
- **THEN** the system refuses to publish that profile for the affected route or home story

#### Scenario: Client selects the profile
- **WHEN** a published Shenzhen route exposes the approved profile
- **THEN** the client displays only server-provided profile name and description and does not contain city-specific voice constants

### Requirement: Editorial quality gate
Shenzhen content publication SHALL require automated graph validation plus a recorded human editorial review covering factual equivalence, conversational flow, pronunciation, location usefulness, photo feasibility, safety, and avoidance of repetitive system vocabulary.

#### Scenario: Official phrasing remains after rewrite
- **WHEN** a review finds repeated bureaucratic phrasing, unexplained data dumps, or formulaic “第几条线索” transitions in a Shenzhen script
- **THEN** the affected script remains unpublished until revised without weakening its factual boundary

#### Scenario: Photo guidance is impractical
- **WHEN** a reviewer finds that a suggested viewpoint blocks passage, crosses a boundary, depends on an unverified object, or cannot produce the described framing
- **THEN** the mission remains unpublished until the viewpoint, safety wording, and composition guidance are corrected
