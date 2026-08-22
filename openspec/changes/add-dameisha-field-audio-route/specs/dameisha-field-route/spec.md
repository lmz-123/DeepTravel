## Purpose

为关闭模拟定位后的大梅沙实地导览及后续内容运营定义一条可由独立后台完整配置、校验和发布的碎片路线，使客户端无需写死景区数据或重新发版即可安全呈现新的城市、故事、定位任务和因果拼图。

## ADDED Requirements

### Requirement: Operators can configure a complete fragmented route
The management surface SHALL allow an authenticated operator to create or import a city and route together with its story arc, ordered fragments, dependencies, WGS-84 trigger regions, photo missions, historical sources, claims, claim links, reconstruction items and backend media references without changing application source code.

#### Scenario: Operator authors Dameisha from an empty draft
- **WHEN** an authenticated operator submits the complete Dameisha content package through the management API or admin UI
- **THEN** the system stores it as a private editable draft containing all route relationships and returns stable identifiers and validation state

#### Scenario: Operator adds a future destination
- **WHEN** an operator configures another city and valid route using the same fields and workflow
- **THEN** no route-specific backend or Flutter change is required to store, publish, discover and run that route

### Requirement: Publication is validated and atomic
The system MUST validate a fragmented route as one graph before publication. Validation SHALL cover required fields, contiguous fragment order, acyclic and satisfiable dependencies, one valid trigger per fragment, WGS-84 ranges, trigger hysteresis and separation, required media existence and MIME type, complete narration/transcript pairs, mission safety text, claim/source traceability, and unique reconstruction items matching the fragment count.

#### Scenario: Draft has validation errors
- **WHEN** an operator attempts to publish a draft with any validation error
- **THEN** publication is rejected with field-addressable errors, the draft remains editable, and no part of the route becomes visible through the public API

#### Scenario: Complete draft is published
- **WHEN** an authenticated operator publishes a draft whose full validation passes
- **THEN** route status, publication timestamp and all related content become public in one transaction and the previous public catalog never exposes a partial graph

#### Scenario: Published route already has journeys
- **WHEN** an operator attempts a structural overwrite of a published route referenced by any journey
- **THEN** the system rejects the overwrite and preserves the content seen by those journeys

### Requirement: Dameisha is published through the generic management path
The Dameisha route with slug `dameisha-remade-coast` SHALL be installed through the same management import and publish contract exposed for future content, not through a Dameisha-specific runtime seed branch.

#### Scenario: Production database receives Dameisha
- **WHEN** the versioned Dameisha content package and media have been imported and published
- **THEN** the public Shenzhen catalog contains Dameisha alongside Nantou without running a route-specific seed command

#### Scenario: Management import is repeated
- **WHEN** the same package identifier and version are imported more than once
- **THEN** the operation is idempotent and neither duplicates children nor damages existing routes and journeys

### Requirement: Dameisha route is discoverable without replacing existing routes
The system SHALL expose Dameisha under city `深圳` with five ordered stops, backend-hosted media, duration and distance metadata while preserving Nantou and all existing route records and journeys.

#### Scenario: Traveler discovers Dameisha in Shenzhen
- **WHEN** the client requests the Shenzhen route catalog after publication
- **THEN** the response contains both the existing Nantou route and Dameisha, and Dameisha is not silently substituted for another route

#### Scenario: Traveler opens Dameisha detail
- **WHEN** the client requests `/api/v1/routes/dameisha-remade-coast`
- **THEN** the response contains five ordered stops and only backend URLs for cover and stop media

### Requirement: Five fragments form one sourced causal story
The Dameisha route SHALL answer the central question “大梅沙是被城市发现的天然海滩，还是被交通、公共政策、人群与风暴反复重造的海岸？” through exactly five dependent fragments covering, in order, the old village and place name, transport access, the 1999 public beach, carrying-capacity tension, and post-typhoon reconstruction.

#### Scenario: Traveler collects all five fragments
- **WHEN** the fifth fragment is collected
- **THEN** the ledger reconstructs a coherent account connecting the pre-tourism village, transport change, public-service decision, crowd pressure and resilient reconstruction instead of presenting five unrelated facts

#### Scenario: Traveler sees a historical interpretation
- **WHEN** a fragment presents the Hakka fine-sand explanation for the name 梅沙 or a visible-site relationship not conclusively established by a primary record
- **THEN** the transcript labels it as an interpretation and does not state it as settled fact

### Requirement: Historical claims remain traceable and reviewable
Every substantive historical or quantitative claim SHALL have at least one named source record, and claims derived from official Shenzhen, Yantian, archival or transit material SHALL remain distinguishable from editorial interpretation and field observation.

#### Scenario: Reviewer inspects route provenance
- **WHEN** route content is inspected through its source and claim records
- **THEN** each dated event, visitor count, capacity figure and reconstruction figure is linked to its supporting source and carries a publication-review state

#### Scenario: Field review is incomplete
- **WHEN** location-dependent Dameisha interpretations are returned before the on-site checklist passes
- **THEN** those records remain visibly marked `in_review` even if the route is published for field testing

### Requirement: Trigger regions use field-safe WGS-84 geometry
Each fragment SHALL have one WGS-84 circular trigger region centered on a dry, public, pedestrian-accessible surface with coordinate provenance. No center SHALL be placed in the surf, on the tide line, inside a traffic lane, on stairs, or in a paid or private area, and adjacent entry circles SHALL not overlap.

#### Scenario: Publish coordinate validation runs
- **WHEN** the Dameisha draft is validated for publication
- **THEN** all coordinates are valid WGS-84 values, adjacent center distance exceeds the sum of entry radii plus a safety margin, exit radius exceeds entry radius, and each point records source datum and audit state

#### Scenario: Imported map coordinate uses another datum
- **WHEN** an authored point originates from a GCJ-02 map provider
- **THEN** the stored trigger center is the explicitly converted WGS-84 candidate and its original datum and source remain available for field verification

### Requirement: Real-location entry resists ordinary coastal GPS drift
With simulated location disabled, a fragment SHALL become eligible only after two fresh qualifying samples inside its entry radius within 15 seconds, each with accuracy no worse than 35 metres. A rejected or stale sample SHALL not advance the journey.

#### Scenario: Two accurate samples arrive inside the next region
- **WHEN** the device reports two fresh WGS-84 samples inside the next eligible region within 15 seconds and both have accuracy at or below 35 metres
- **THEN** the next fragment is collected exactly once and its narration becomes available

#### Scenario: One inaccurate or stale sample arrives
- **WHEN** a sample reports accuracy worse than 35 metres or is older than 20 seconds
- **THEN** it is excluded from entry confirmation and the traveler receives a useful positioning state without losing progress

#### Scenario: Device is near a later region before prerequisites
- **WHEN** valid samples are inside a later fragment's region but the preceding fragment is incomplete
- **THEN** the later fragment remains locked and the journey does not skip story order

### Requirement: Narration and transcript remain available after collection
Every Dameisha fragment SHALL provide a versioned Mandarin preview narration and matching full transcript from backend-hosted assets. Once triggered or collected, its audio controls and transcript SHALL remain visible after leaving the region, navigating away or reopening the journey.

#### Scenario: Traveler returns to collected content
- **WHEN** the app reconstructs a Dameisha journey from its ledger
- **THEN** all collected fragments still expose their titles, complete transcripts and playable audio URLs without another location trigger

#### Scenario: Audio download is unavailable
- **WHEN** a narration asset cannot be downloaded or played
- **THEN** the complete transcript remains readable and the failure does not erase the fragment or block location monitoring

### Requirement: Photo missions distinguish observation from historical proof
The route SHALL include exactly three postponable photo missions at safe stops. Each SHALL describe an observable subject, avoid treating a contemporary photo as proof of a historical claim, and permit deferral when weather, crowding, access or device conditions make photography unsafe.

#### Scenario: Traveler completes a mission
- **WHEN** the traveler uploads a photo for an eligible mission and the backend accepts the evidence
- **THEN** the journey records the private evidence and permits progression once all other completion conditions are satisfied

#### Scenario: Traveler cannot photograph safely
- **WHEN** the traveler defers a mission because the site is crowded, wet, restricted or otherwise unsafe
- **THEN** the fragment remains collected, the mission remains available for later completion, and the app does not direct the traveler into a hazard

### Requirement: Reconstruction is route-configured and feedback stays above the puzzle
The ledger SHALL provide stable reconstruction item identifiers and display text configured for the active route. Flutter MUST NOT contain route-specific reconstruction statements. An incorrect submission SHALL return mismatch positions and display a root-level top overlay above any bottom sheet stating the number of mismatches, while the puzzle marks those positions without revealing the correct order.

#### Scenario: Dameisha puzzle opens
- **WHEN** all Dameisha fragments are collected and the traveler starts reconstruction
- **THEN** the draggable items come from the Dameisha ledger and contain no Nantou-specific statement

#### Scenario: Wrong order is submitted from a bottom sheet
- **WHEN** the backend returns three mismatched positions
- **THEN** a visible top-layer message says “还有 3 处关系没有接上”, remains above the bottom sheet, and the three affected rows are visually marked

#### Scenario: Correct order is submitted
- **WHEN** all submitted item identifiers match the configured causal order
- **THEN** no mismatch overlay appears, the puzzle closes and the route-specific complete story opens

### Requirement: Field audit produces actionable coordinate evidence
The change SHALL include an Android field checklist with simulated location disabled. At each stop it SHALL capture repeated WGS-84 readings, reported accuracy, trigger timing, surface/access safety and whether audio and transcript survive backgrounding and re-entry.

#### Scenario: Tester audits one stop
- **WHEN** the tester stands on the authored public surface for 60 to 90 seconds and records at least eight samples
- **THEN** the checklist can compare median and worst practical readings with the authored center and state whether the radius needs adjustment

#### Scenario: Route passes field acceptance
- **WHEN** all five stops trigger once in order without a false trigger from the preceding stop, road or shoreline and collected narration survives re-entry
- **THEN** the recorded observations can be applied through the admin draft/validation path before the field-audit label is cleared
