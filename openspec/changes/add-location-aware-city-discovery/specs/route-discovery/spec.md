## MODIFIED Requirements

### Requirement: Browse published routes by city
The system SHALL return only selectable cities with formally published content and, for a selected city, SHALL return its existing published route summaries as one home item per scenic area. Each route summary SHALL expose a nullable representative WGS-84 `center` calculated from that scenic area's eligible published story-node coordinates. The response MUST NOT flatten internal story nodes into independent home items. The client SHALL provide the existing backend-driven city selector and MUST NOT hard-code a city list, scenic-area list, coordinate, asset, or tag option.

#### Scenario: Featured route is discoverable
- **WHEN** a client requests routes for a city that has a featured published route
- **THEN** the response includes that route and all existing summary metadata

#### Scenario: Published scenic area is discoverable
- **WHEN** a client requests discovery content for a selectable city with an eligible published route
- **THEN** the response includes exactly one home summary for that scenic area with its derived center and does not add its internal story nodes as sibling home items

#### Scenario: Unknown city
- **WHEN** a client requests discovery content for an unknown or unpublished city slug
- **THEN** the system returns a structured not-found error

#### Scenario: Draft content is excluded
- **WHEN** a city contains non-published and published scenic areas
- **THEN** the public home collection includes only formally published route/scenic-area summaries

#### Scenario: Open city selection
- **WHEN** a traveler taps the selected city control
- **THEN** the existing selection sheet presents only backend-provided selectable cities and its existing accessible close path

#### Scenario: Select another city
- **WHEN** a traveler selects another backend city
- **THEN** the sheet closes, the selected city takes precedence, and discovery reloads only that city's content before attempting scenic-area-center sorting

### Requirement: Home scenic-area ordering is truthful and scoped
When a real position is successfully acquired for the current discovery event, the client SHALL calculate geodesic distance to each eligible scenic area's valid center and order scenic-area cards by ascending unrounded distance without checking reported accuracy. Exact ties SHALL retain server response order and then stable route ID. Scenic areas without a center SHALL follow centered areas in server order without distance copy. When acquisition fails, the client SHALL preserve server response order and MUST NOT display or imply a calculated distance. This ranking SHALL NOT flatten, reorder, or independently surface fragments or stops.

#### Scenario: Nearest scenic area is first on home
- **WHEN** a successfully acquired position exists and the active city has multiple published scenic areas with centers
- **THEN** the first home card represents the scenic area whose center has the smallest calculated distance

#### Scenario: Equal scenic-area distances
- **WHEN** two scenic-area centers have equal calculated distance
- **THEN** their relative order follows server response order and stable route ID

#### Scenario: No accepted location exists
- **WHEN** discovery does not obtain a position for the current event
- **THEN** scenic-area cards remain in server order and display no default, stale, estimated, or placeholder distance

#### Scenario: Scenic-area card opens its route
- **WHEN** the traveler opens a ranked home scenic-area card
- **THEN** that route opens without changing or independently surfacing its internal published nodes

### Requirement: Experience tags remain server-driven node data
The content system SHALL allow administrators and existing content-package flows to assign ordered, de-duplicated experience-tag strings to legacy stops and managed story fragments. Those tags SHALL remain available through existing published node/fragment content and downstream footprint workflows. Flutter MUST treat tags as generic display data rather than an enum or hard-coded allowlist. Tags MUST NOT cause a node to become an independent home card.

#### Scenario: Product example tags are configured
- **WHEN** an administrator configures “安静”, “适合约会”, “网红打卡”, “随便逛逛”, “适合一个人”, “适合朋友同行”, “老建筑”, “城市历史”, “社区生活”, or “海边或自然景观” on a point
- **THEN** published node surfaces render the configured values without a client code change and without changing homepage card granularity

#### Scenario: A new tag is introduced
- **WHEN** a published point receives a valid new tag value unknown to the released client
- **THEN** the client renders it through the same generic node tag presentation

#### Scenario: Unpublished tag edits remain private
- **WHEN** point tags are edited on content that has not completed formal publication
- **THEN** the changed tags do not appear in published node content
