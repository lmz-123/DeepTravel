## MODIFIED Requirements

### Requirement: Browse published routes by city
The system SHALL return published cities and their published routes with city name, subtitle, cover image and stable slug plus route title, theme, duration, distance, difficulty, cover image, and featured state. The client SHALL provide a visually rich, backend-driven city selection sheet with an explicit current selection, immediate selection feedback, and local name/subtitle search when the published city collection is large enough to require it; it MUST NOT hard-code city options or assets.

#### Scenario: Featured route is discoverable
- **WHEN** a client requests routes for a city that has a featured published route
- **THEN** the response includes that route and all summary metadata

#### Scenario: Unknown city
- **WHEN** a client requests routes for an unknown city slug
- **THEN** the system returns a structured not-found error

#### Scenario: Open city selection
- **WHEN** a traveler taps the selected city control
- **THEN** a scoped selection sheet presents backend-provided city imagery, names, subtitles, current selection state, and an accessible close path

#### Scenario: Select another city
- **WHEN** a traveler selects a different published city
- **THEN** the sheet closes, the header reflects the selected city, and discovery reloads that city's routes without retaining the previous city's cards

#### Scenario: Search a large city catalog
- **WHEN** the backend returns enough published cities to make scanning inefficient and the traveler enters a name or subtitle query
- **THEN** the sheet filters immediately, provides a clear empty result, and preserves the current selection until another city is chosen

#### Scenario: City catalog refresh fails
- **WHEN** refreshing the backend city catalog fails after a city was previously selected
- **THEN** the client retains the known selection, exposes retry, and does not replace it with a hard-coded fallback city
