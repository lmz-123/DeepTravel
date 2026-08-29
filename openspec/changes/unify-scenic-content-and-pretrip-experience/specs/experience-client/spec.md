## ADDED Requirements

### Requirement: City manual and city story sections do not overlap
The discovery client SHALL lay out the city-manual scenic carousel, its page indicator, the following city-story section, and their spacing from measured content and viewport constraints rather than absolute vertical offsets or a single device-specific fixed height. The city-manual carousel and indicator SHALL precede the city-story cards in reading order.

#### Scenario: Scenic card follows the approved design proportion
- **WHEN** discovery renders at the default text scale
- **THEN** each scenic card uses the approved reference proportion of a 220-pixel photographic hero at a 368-pixel card width, with intrinsic body height, 18-pixel page gutters, and the design's typography and compact-label metrics instead of the former 505/276 baseline

#### Scenario: Compact supported phone
- **WHEN** discovery renders on the minimum supported phone width and height
- **THEN** the complete carousel indicator remains visible and the city-story cards begin after it without overlap

#### Scenario: Large text is enabled
- **WHEN** platform text scaling reaches 200 percent
- **THEN** headings and cards reflow or grow upward from the established visual baseline within scrollable content while the manual indicator and story controls remain distinct and operable

#### Scenario: Content length changes
- **WHEN** backend-provided titles, tags, or summaries require additional lines within documented limits
- **THEN** downstream sections move relative to the measured content instead of being painted over it

### Requirement: Journey node selection has one visual and interaction source
The journey client SHALL make the connected small route points in the upper journey map/header the sole node selector. Each point SHALL expose its position and heard, nearby, selected, or unavailable state through semantics and styling, and activating it SHALL update the one node-introduction card below. The journey body MUST NOT render a second 1–5 node rail, numbered circles, or another competing selector. The current narration SHALL use the designed dark playback card, and real-walk/simulated-preview selection SHALL remain a distinct two-column mode surface after journey content.

#### Scenario: Traveler switches a revealed node
- **WHEN** the traveler activates another route point in the upper connected map path
- **THEN** that point becomes selected and the node introduction, narration context, optional mission, and community content update for the same node without showing any body-level numbered selector

#### Scenario: Current narration is active
- **WHEN** a revealed node is playing
- **THEN** one dark playback card shows its primary play/pause control, title and status copy, progress, and compact speed, voice, and transcript controls

#### Scenario: Traveler changes preview mode
- **WHEN** real walking and simulated preview are available
- **THEN** both choices appear together in the designed two-column mode surface with exactly one active state
