## ADDED Requirements

### Requirement: City manual and city story sections do not overlap
The discovery client SHALL lay out the city-manual scenic carousel, its page indicator, the following city-story section, and their spacing from measured content and viewport constraints rather than absolute vertical offsets or a single device-specific fixed height. The city-manual carousel and indicator SHALL precede the city-story cards in reading order.

#### Scenario: Existing scenic-card proportions are preserved
- **WHEN** discovery renders at the default text scale
- **THEN** each scenic card retains the established 505 logical-pixel carousel and 276 logical-pixel hero-image visual baseline, and responsive section spacing MUST NOT shrink either baseline

#### Scenario: Compact supported phone
- **WHEN** discovery renders on the minimum supported phone width and height
- **THEN** the complete carousel indicator remains visible and the city-story cards begin after it without overlap

#### Scenario: Large text is enabled
- **WHEN** platform text scaling reaches 200 percent
- **THEN** headings and cards reflow or grow upward from the established visual baseline within scrollable content while the manual indicator and story controls remain distinct and operable

#### Scenario: Content length changes
- **WHEN** backend-provided titles, tags, or summaries require additional lines within documented limits
- **THEN** downstream sections move relative to the measured content instead of being painted over it
