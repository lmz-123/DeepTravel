## ADDED Requirements

### Requirement: Story progress creates a non-blocking footprint draft
For every user-owned fragmented story point first revealed by a formal trigger, the system SHALL establish the stable source identity needed for one private footprint draft. Footprint creation, deferred organization, user text and optional photographs MUST NOT become prerequisites for triggering, playback, collection, free-roam continuation, reconstruction or journey completion.

#### Scenario: Trigger a later point first
- **WHEN** free-roam location reveals a later authored story point before an earlier point
- **THEN** that later point receives its own footprint draft without creating, completing or blocking any other point's footprint

#### Scenario: Footprint enrichment is skipped
- **WHEN** the traveler chooses “稍后再整理” or dismisses footprint editing after a trigger
- **THEN** the journey continues under its existing trigger and narration rules and the draft remains available outside the journey

#### Scenario: Draft reconciliation is delayed
- **WHEN** journey progress succeeds but footprint projection is temporarily unavailable
- **THEN** the authoritative story ledger remains valid and a later idempotent reconciliation creates the missing draft without replaying or re-triggering the story

#### Scenario: Optional records are edited
- **WHEN** the user adds, replaces or removes footprint text or a photograph
- **THEN** story trigger, playback, collected state, reconstruction eligibility and causal ordering remain unchanged
