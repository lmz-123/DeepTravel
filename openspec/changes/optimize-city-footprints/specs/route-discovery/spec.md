## ADDED Requirements

### Requirement: Continue the latest private footprint from home
For an authenticated user with at least one deferred or incomplete footprint, the discovery home SHALL provide a “继续我的足迹” entry based on the server's most recent eligible owned footprint. The entry SHALL identify its city and story context without exposing route progress, audio state or another user's data.

#### Scenario: A draft footprint needs organization
- **WHEN** the user opens discovery with an eligible recent draft footprint
- **THEN** the home entry opens that footprint's lightweight organization surface rather than starting or resetting its journey

#### Scenario: No footprint needs organization
- **WHEN** the user has no eligible deferred or incomplete footprint
- **THEN** discovery omits the continue-footprint entry without leaving a blank primary module

#### Scenario: Resume candidate fails to load
- **WHEN** the home request for a footprint candidate fails while discovery content is otherwise available
- **THEN** route and city-story discovery remain usable and the footprint entry exposes no stale record belonging to a previous user
