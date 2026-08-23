## ADDED Requirements

### Requirement: Fragmented journey progress is independent of walking order
For fragmented audio tours, the system SHALL persist trigger, playback, collection, optional evidence, and reconstruction state by stable story-point identity rather than by a single current-stop cursor. Collecting or skipping one point MUST NOT erase, lock, auto-complete, or renumber another point, and leaving the tour MUST NOT discard partial progress.

#### Scenario: Collect points out of order
- **WHEN** a traveler collects points 4 and 2 before points 1 and 3
- **THEN** the ledger records exactly points 4 and 2 as collected and leaves every other point independently unfinished

#### Scenario: Leave after partial roaming
- **WHEN** a traveler exits after triggering or collecting only part of the published points
- **THEN** the journey remains owner-scoped and recoverable with its saved node states and optional field records

#### Scenario: Open a partial footprint
- **WHEN** the owner opens the journey library or footprint surface before completing the entire tour
- **THEN** the partial journey is represented as in progress and can resume rather than being omitted or described as completed

### Requirement: Causal reconstruction is independent of field order
Final story reconstruction SHALL be built from the backend-authored causal model and stable story identities, not from trigger timestamps, collection timestamps, physical walking order, nearby-distance order, or recommended route position. Reconstruction MAY require all configured required story content to be collected, but it MUST NOT require that collection to have occurred in authored order.

#### Scenario: Unlock reconstruction after unordered collection
- **WHEN** all required story points are collected in an arbitrary spatial order
- **THEN** reconstruction unlocks under the same completeness rule as authored-order collection

#### Scenario: Submit the walked order
- **WHEN** the traveler submits relationships matching their walking order but not the authored causal model
- **THEN** reconstruction evaluates against the causal model rather than treating walking order as correct

#### Scenario: Submit the causal order after free roaming
- **WHEN** the traveler collects points in arbitrary order and later submits the correct authored causal relationships
- **THEN** the system accepts the reconstruction and preserves the actual field history without rewriting it into the causal order

### Requirement: Observation and photography remain non-blocking
For fragmented free-roam tours, field observation guidance SHALL be optional explanatory content and MUST NOT require an answer, correctness score, or forced task. Photograph capture and upload SHALL remain optional records and MUST NOT gate point collection, partial-footprint persistence, reconstruction eligibility, or journey completion.

#### Scenario: Ignore an observation hint
- **WHEN** the traveler listens to a point but does not respond to its observation guidance
- **THEN** the point follows its configured narration completion rule without an answer request

#### Scenario: Complete without photographs
- **WHEN** the traveler collects all required points and takes no photographs
- **THEN** reconstruction and completion remain available and the footprint shows a valid no-photo state
