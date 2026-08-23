## MODIFIED Requirements

### Requirement: Browse published routes by city
The system SHALL return only selectable cities with formally published content and, for a selected city, SHALL return its existing published route summaries plus a compact flat collection of published scenic/story points for home discovery. Each point SHALL expose a stable identifier, display title, valid WGS-84 coordinate, ordered backend-configured experience tags, and the minimal parent-route identity required by the existing opening flow. The client SHALL provide the existing backend-driven city selector and MUST NOT hard-code a city list, point list, coordinate, asset, or tag option.

#### Scenario: Featured route is discoverable
- **WHEN** a client requests routes for a city that has a featured published route
- **THEN** the response includes that route and all existing summary metadata

#### Scenario: Published scenic point is discoverable
- **WHEN** a client requests discovery content for a selectable city with an eligible published story fragment or legacy stop
- **THEN** the response includes the point's home-card metadata and parent-route identity without adding a route recommendation score

#### Scenario: Unknown city
- **WHEN** a client requests discovery content for an unknown or unpublished city slug
- **THEN** the system returns a structured not-found error

#### Scenario: Draft content is excluded
- **WHEN** a city contains non-published and published routes or points
- **THEN** the public point collection includes only points whose content and parent route are eligible for formal publication

#### Scenario: Open city selection
- **WHEN** a traveler taps the selected city control
- **THEN** the existing selection sheet presents only backend-provided selectable cities and its existing accessible close path

#### Scenario: Select another city
- **WHEN** a traveler selects another backend city
- **THEN** the sheet closes, the selected city takes precedence, and discovery reloads only that city's content before attempting point-distance sorting

### Requirement: Home scenic-point ordering is truthful and scoped
When a real position is successfully acquired for the current discovery event, the client SHALL calculate geodesic distance to every eligible home point in the active city and order point cards by ascending unrounded distance without checking reported accuracy. Exact ties SHALL retain server response order and then stable point ID. When acquisition fails, the client SHALL preserve server response order and MUST NOT display or imply a calculated distance. This ranking SHALL NOT reorder routes, fragments, or stops after a card is opened.

#### Scenario: Nearest point is first on home
- **WHEN** a successfully acquired position exists and the active city has multiple published home points
- **THEN** the first home card represents the point with the smallest calculated distance

#### Scenario: Equal point distances
- **WHEN** two points have equal calculated distance
- **THEN** their relative order follows server response order and stable point ID

#### Scenario: No accepted location exists
- **WHEN** discovery does not obtain a position for the current event
- **THEN** point cards remain in server order and display no default, stale, estimated, or placeholder distance

#### Scenario: Point card opens its route
- **WHEN** the traveler opens a ranked home point card
- **THEN** the existing parent route opens without changing its internal published order

### Requirement: Experience tags are server-driven point data
The content system SHALL allow administrators and existing content-package flows to assign ordered, de-duplicated experience-tag strings to legacy stops and managed story fragments. Public home point summaries SHALL preserve those values for direct client presentation. Flutter MUST treat tags as generic display data rather than an enum or hard-coded allowlist. Routes SHALL NOT gain tags as part of this requirement.

#### Scenario: Product example tags are configured
- **WHEN** an administrator configures “安静”, “适合约会”, “网红打卡”, “随便逛逛”, “适合一个人”, “适合朋友同行”, “老建筑”, “城市历史”, “社区生活”, or “海边或自然景观” on a point
- **THEN** the published point card renders the configured values without a client code change

#### Scenario: A new tag is introduced
- **WHEN** a published point receives a valid new tag value unknown to the released client
- **THEN** the client renders it through the same generic tag presentation

#### Scenario: Unpublished tag edits remain private
- **WHEN** point tags are edited on content that has not completed formal publication
- **THEN** the changed tags do not appear in public home discovery
