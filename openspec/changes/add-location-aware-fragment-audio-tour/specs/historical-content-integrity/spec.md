## Purpose

Ensure that game-like narration remains a trustworthy way to learn local history by linking substantive claims to sources, review decisions, and explicit interpretation boundaries.

## ADDED Requirements

### Requirement: Claim-level source traceability
Every substantive date, event, identity, material claim, and causal historical assertion in publication-ready narration SHALL be linked to at least one source record.

#### Scenario: Traveler inspects a fragment
- **WHEN** a fragment is collected
- **THEN** its ledger entry exposes a concise source summary and a path to the source citation without interrupting audio playback

#### Scenario: Claim lacks a source
- **WHEN** a substantive claim has no source record
- **THEN** the claim cannot enter publication-ready state

### Requirement: Editorial review states
Historical sources, claims, fragments, narration scripts, transcripts, and complete stories SHALL expose draft, in-review, reviewed, disputed, or retired state as applicable.

#### Scenario: Published route is requested
- **WHEN** a normal traveler requests a production route
- **THEN** only fragments whose required claims and narration are reviewed are presented as verified historical content

#### Scenario: Unreviewed demo content is enabled
- **WHEN** an evaluator runs a deployment that explicitly permits demo content
- **THEN** the client and API visibly identify the route and affected fragments as unverified demonstration material

### Requirement: Physical authenticity labeling
Content referring to a field object SHALL distinguish original fabric, archaeological remains, relocation, reconstruction, restoration, exhibition interpretation, and inferred former location when those distinctions affect meaning.

#### Scenario: Mission uses a reconstructed structure
- **WHEN** a photo mission points to a reconstructed or interpretive display
- **THEN** narration states that status and does not describe the visible structure as an untouched object from the claimed period

#### Scenario: Exact field relationship is uncertain
- **WHEN** sources support a historical event but not a direct relationship to the visible object
- **THEN** narration labels the field connection as interpretation rather than evidence

### Requirement: Fact, inference, and fiction boundaries
Narrative text SHALL distinguish documented fact, editorial inference, and fictional framing, and SHALL never place invented quotations or actions in a historical person's voice as fact.

#### Scenario: Fictional framing is used
- **WHEN** a route uses a fictional narrator, document, or dramatic device
- **THEN** the route identifies the device as fictional and keeps its factual claims independently cited

#### Scenario: Sources disagree
- **WHEN** credible sources disagree on a material point
- **THEN** the fragment communicates the uncertainty or competing interpretations instead of presenting one as uncontested fact

### Requirement: Complete historical arc review
Before publication, the route's complete story SHALL be reviewed as a whole for chronology, causality, missing context, misleading simplification, and consistency with fragment text.

#### Scenario: Individual fragments are accurate but causal chain is misleading
- **WHEN** whole-story review finds that accurate facts have been arranged to imply an unsupported cause
- **THEN** the route remains unpublished until the causal model and affected narration are corrected

#### Scenario: Route passes review
- **WHEN** source, claim, physical-authenticity, fragment, audio, and whole-arc reviews are complete
- **THEN** the route records reviewer identity, review time, source version, and publication decision

### Requirement: Correctable historical record
The backend SHALL support retiring or correcting a published claim without rewriting a traveler's private evidence.

#### Scenario: Published claim is corrected
- **WHEN** editorial review supersedes a claim or source interpretation
- **THEN** new route requests receive the corrected version and existing recaps identify that updated historical context is available

#### Scenario: Source link becomes unavailable
- **WHEN** a citation URL becomes unavailable
- **THEN** the source record retains its title, publisher, publication date when known, access date, and review status while editors can attach a replacement location
