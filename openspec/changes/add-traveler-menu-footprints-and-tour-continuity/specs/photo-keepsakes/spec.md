## Purpose

把现场拍照从强制通关证明改为可稍后完成的私密旅行留念，并通过内容驱动的经典机位指导和可恢复的大图查看提升照片的纪念价值。

## ADDED Requirements

### Requirement: Photo missions do not gate progression
A fragmented route SHALL collect a clue when its narration completion threshold is acknowledged regardless of whether an associated photo has been captured or uploaded. Optional evidence submission or deletion MUST NOT reduce collected progress, lock downstream dependencies, or revoke reconstruction eligibility.

#### Scenario: Complete narration without a photo
- **WHEN** a photo-capable clue reaches its narration completion threshold without evidence
- **THEN** the clue becomes collected, the photo invitation remains available, and downstream dependencies are reevaluated as satisfied

#### Scenario: Upload a photo after collection
- **WHEN** the traveler later uploads valid evidence for a collected clue
- **THEN** the photo is attached privately without changing the already collected count

#### Scenario: Delete an optional photo
- **WHEN** the traveler deletes evidence before or after route completion while deletion is permitted by retention rules
- **THEN** the evidence is removed without rolling the clue back to mission-pending or changing journey completion

### Requirement: Content-driven classic viewpoint guidance
Each authored photo mission SHALL provide a concrete field subject, safe standing position or vantage point, shooting direction, and concise composition guidance. The admin editor and content validation SHALL support these fields, and the client SHALL present them before opening the camera without embedding route-specific instructions in Flutter.

#### Scenario: Open a photo invitation
- **WHEN** a traveler opens an available photo mission
- **THEN** the client shows the subject, safe position, direction, composition tip, and safety copy in a scannable shooting guide

#### Scenario: Published mission lacks guidance
- **WHEN** content validation finds a photo mission without required shooting guidance
- **THEN** publication validation fails with a field-specific error

#### Scenario: Subject cannot be reached safely
- **WHEN** the suggested position is closed, obstructed, or unsafe
- **THEN** the traveler can dismiss or postpone the photo without losing clue progress

### Requirement: Private photo review and authenticated viewing
After capture, the client SHALL show a reviewable thumbnail and SHALL treat the thumbnail as a labeled image button that opens a dedicated large-photo viewer. After local file loss or app restart, the client SHALL retrieve available evidence through the owner-authorized API and SHALL provide loading, expired, deleted, offline, and retry states.

#### Scenario: View a just-captured photo
- **WHEN** the traveler taps the captured photo area after capture
- **THEN** the client opens the photo in a dedicated viewer with fit-to-screen presentation and a clear close action

#### Scenario: View after restarting the app
- **WHEN** the local camera file is no longer available but unexpired server evidence exists
- **THEN** the client authenticates the evidence request and displays the server copy without requiring re-upload

#### Scenario: Evidence expires
- **WHEN** the configured retention period removes an evidence object
- **THEN** the client shows a neutral expiry explanation and keeps the historical clue and journey progress visible

#### Scenario: Another user opens an evidence URL
- **WHEN** a different user attempts to retrieve the photo resource
- **THEN** the API returns the existing owner-scoped not-found response and no image bytes or metadata

### Requirement: Footprint photo gallery
Completed footprint detail SHALL group available evidence by clue and SHALL allow each thumbnail to open the same authenticated large-photo viewer used during the active journey.

#### Scenario: Open photos from a footprint
- **WHEN** a completed journey contains one or more unexpired photos
- **THEN** its footprint detail shows each photo with the related clue title and capture or upload time

#### Scenario: Completed journey has no photos
- **WHEN** a route was completed without optional evidence
- **THEN** the footprint remains complete and shows a tasteful no-photo state rather than a missing-task warning

### Requirement: Restrained nostalgic frame treatment
Photo thumbnails and footprint photo cards SHALL use a consistent warm paper frame with a subtle irregular or worn edge, restrained shadow, and optional small rotation while preserving image aspect ratio, legibility, minimum touch targets, and reduced-motion behavior. Decorative treatment MUST NOT obscure the photograph or imply that the original evidence bytes were modified.

#### Scenario: Render a framed photo card
- **WHEN** a private photo thumbnail is available
- **THEN** the client renders the photo inside the nostalgic frame while keeping the full card identifiable and tappable

#### Scenario: Reduced motion is enabled
- **WHEN** the platform requests reduced motion
- **THEN** the frame remains static and any decorative entrance or tilt animation is removed
