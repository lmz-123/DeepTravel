## Purpose

Turn a walking route into a coherent historical investigation whose individually useful fragments accumulate into a sourced causal story the traveler reconstructs.

## ADDED Requirements

### Requirement: Coherent story arc
A published fragmented route SHALL define one central historical question, an ordered causal arc, and a finite set of fragments that each contribute a distinct claim or relationship to that arc.

#### Scenario: Route exposes its mystery
- **WHEN** a traveler views or starts a fragmented route
- **THEN** the client communicates the central question without revealing the final causal explanation

#### Scenario: Fragment is independently meaningful
- **WHEN** a fragment is revealed
- **THEN** it states at least one substantive historical fact or interpretive relationship and does not consist solely of atmospheric or motivational language

#### Scenario: Fragment advances the arc
- **WHEN** editorial validation evaluates a fragment
- **THEN** the fragment identifies which earlier question it answers and which later question, contradiction, or missing cause it introduces

### Requirement: Fragment reveal and collection
The system SHALL distinguish trigger, narration, mission, and collection states and SHALL collect a fragment only after its declared completion rule is satisfied.

#### Scenario: Passive fragment completes
- **WHEN** a passive fragment is triggered and its narration reaches the configured completion threshold or its transcript is explicitly completed
- **THEN** the fragment becomes collected exactly once

#### Scenario: Mission fragment awaits evidence
- **WHEN** a fragment with a required photo mission finishes narration without accepted evidence
- **THEN** the fragment remains mission-pending while the traveler may continue hearing eligible narration

#### Scenario: Repeated acknowledgement
- **WHEN** trigger, playback, evidence, or collection acknowledgement is retried with the same idempotency identity
- **THEN** the system returns the existing state without duplicating progress

### Requirement: Dependency-safe fragmented order
The system SHALL support editorially declared prerequisites so that travel order can remain flexible without revealing a fragment that would spoil an unmet causal step.

#### Scenario: All prerequisites are met
- **WHEN** an eligible trigger occurs and the fragment's prerequisites are collected
- **THEN** the fragment may enter the narration queue

#### Scenario: Prerequisite is missing
- **WHEN** an eligible trigger occurs before a required earlier fragment is collected
- **THEN** the fragment remains locked and the client offers a spoiler-free route hint

### Requirement: Story ledger
The client SHALL present a story ledger that can be understood without replaying every screen and that distinguishes collected, mission-pending, nearby-locked, and undiscovered fragments.

#### Scenario: Traveler opens the ledger
- **WHEN** the traveler opens the active route's ledger
- **THEN** collected fragments show their title, key claim, photo evidence when present, transcript, source summary, and relation to the central question

#### Scenario: Fragment is undiscovered
- **WHEN** a fragment has not been geographically encountered
- **THEN** the ledger conceals spoiler content while communicating remaining progress

### Requirement: Final causal reconstruction
The system SHALL unlock a reconstruction only after all required fragments are collected and SHALL ask the traveler to connect or order the fragments by causal or chronological relationships.

#### Scenario: Required fragment is missing
- **WHEN** the traveler attempts final reconstruction before all required fragments are collected
- **THEN** the system identifies incomplete fragment positions without revealing their content

#### Scenario: Reconstruction is submitted
- **WHEN** the traveler submits an ordering or relationship set
- **THEN** the system evaluates it against the route's authored causal model and returns targeted explanations for misplaced relationships

#### Scenario: Reconstruction succeeds
- **WHEN** the required causal model is correctly reconstructed
- **THEN** the journey unlocks the complete sourced story and a recap combining the traveler's evidence with the historical timeline

### Requirement: Durable story progress
Fragment triggers, playback completion, evidence state, collection, and reconstruction SHALL survive app restart and guest journey resume.

#### Scenario: App restarts during a mission
- **WHEN** the app restarts after narration but before evidence upload completes
- **THEN** the same journey resumes with the fragment mission pending and any safe local upload retry state retained

#### Scenario: Client and server progress differ
- **WHEN** the client reconnects with local events not yet acknowledged by the server
- **THEN** progress is reconciled idempotently without erasing a server-collected fragment or replaying it automatically
