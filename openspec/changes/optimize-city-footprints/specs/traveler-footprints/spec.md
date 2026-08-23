## Purpose

让旅行者把每个已触发故事沉淀为长期私密、可轻量整理和主动分享的城市理解与个人记忆，同时使历史足迹完全独立于路线播放、声音版本和供应商变化。

## ADDED Requirements

### Requirement: One private footprint per triggered story point
The system SHALL maintain at most one user-owned footprint entry for each triggered story point in a journey and SHALL make that entry available before the whole journey is completed. Creating or editing a footprint MUST NOT require all points, a photograph, long text, an answer, or journey completion.

#### Scenario: First story point is triggered
- **WHEN** the owning user triggers a published story point for the first time
- **THEN** a private draft footprint for that journey and story point becomes available with no duplicate entry

#### Scenario: Trigger request is retried
- **WHEN** the same story point trigger is retried or reconciled from an offline outbox
- **THEN** the system returns or repairs the same footprint entry instead of creating another one

#### Scenario: User leaves after one point
- **WHEN** the user exits an otherwise incomplete journey after triggering one story point
- **THEN** that point's footprint remains available for browsing and later editing

### Requirement: Voice-independent editorial snapshot
Each footprint SHALL preserve the city, scene or story-point identity, story title, reviewed editorial summary, available short-summary choices, related arbitrary themes and creation time as a semantic snapshot. The footprint contract MUST NOT contain an audio URL, transcript playback position, narration profile, voice version, provider identifier or other field needed only for playback.

#### Scenario: Narration is regenerated
- **WHEN** administrators replace an audio file, voice profile, provider or narration-track version after a footprint was created
- **THEN** the historical footprint renders the same semantic snapshot without loading the old or new narration configuration

#### Scenario: Old API content lacks footprint-specific copy
- **WHEN** an eligible older story has no dedicated footprint summary configuration
- **THEN** the backend creates a non-empty reviewed fallback from existing server content and the client does not invent city, story, summary or theme text

#### Scenario: Route is archived after travel
- **WHEN** the source route or story is no longer publicly discoverable
- **THEN** the owner can still read the saved footprint snapshot while other users gain no access

### Requirement: Lightweight optional organization
The user SHALL be able to select zero or one server-provided summary choice, add a short “我看到的” observation, add a short “我留下的” personal sentence, remove either user field, or choose “稍后再整理”. The interface MUST bound these inputs as short-form fields and MUST NOT require a long-form document.

#### Scenario: Save a short personal footprint
- **WHEN** the user selects a provided summary and enters an observation and personal sentence within the advertised limits
- **THEN** the system saves those values to the same footprint and marks it organized

#### Scenario: Defer organization
- **WHEN** the user chooses “稍后再整理” without choosing a summary or entering text
- **THEN** the draft remains readable from its reviewed editorial snapshot and becomes eligible for the continue-footprint entry

#### Scenario: Clear a previous sentence
- **WHEN** the owner explicitly removes a previously saved observation or sentence
- **THEN** the field becomes empty without deleting the editorial snapshot, themes, photograph or journey progress

### Requirement: Durable private footprint photograph
The user SHALL be able to attach at most one long-lived private photograph to a footprint, replace it, or remove it. Footprint photographs SHALL use authenticated owner access, SHALL NOT have a public asset URL, SHALL NOT expire according to temporary field-evidence retention, and SHALL remain optional.

#### Scenario: Upload one keepsake
- **WHEN** the owner uploads a valid supported photograph with an idempotency key
- **THEN** the system privately stores it under the footprint and a retry does not create a second photograph

#### Scenario: Another account requests the photograph
- **WHEN** a different authenticated account requests footprint metadata or photograph bytes
- **THEN** the system returns the privacy-safe not-found response and exposes no storage reference

#### Scenario: Photo service is unavailable
- **WHEN** a photograph upload or read fails while text content remains available
- **THEN** the footprint and journey remain usable, the client preserves any safe retry state, and no false successful upload is shown

### Requirement: Three-part footprint presentation without playback
Footprint list and detail surfaces SHALL make the record, rather than route statistics, the primary content and SHALL clearly separate “见地讲述”, “我看到的” and “我留下的”. These surfaces MUST NOT instantiate or control narration, display playback progress or voice metadata, offer a replay action, or embed the node community feed.

#### Scenario: Open an organized footprint
- **WHEN** the owner opens a footprint with editorial copy, an observation, photograph and personal sentence
- **THEN** the page presents each item under its corresponding three-part label with story, city, scene, themes and time context

#### Scenario: Open a minimal draft
- **WHEN** the owner opens a footprint without user text or a photograph
- **THEN** the reviewed “见地讲述” remains readable and compact invitations allow later organization without empty decorative sections

#### Scenario: Audio is playing elsewhere
- **WHEN** route or city-story audio is active while the user browses footprints
- **THEN** footprint rendering neither depends on nor mutates that player and exposes no footprint playback control

### Requirement: Browse by city, theme and time
The owner SHALL be able to browse and paginate footprints by server-provided city, arbitrary theme and time, combine supported filters, clear them, and use newest-first time ordering by default. Filter choices MUST be derived from the owner's footprint data and MUST NOT be hard-coded in the client.

#### Scenario: Filter by city and theme
- **WHEN** the user selects one available city and one arbitrary theme
- **THEN** the list contains only owned footprints matching both values and retains a clear-filter action

#### Scenario: Browse by time
- **WHEN** the user chooses a supported time period or newest/oldest order
- **THEN** records are returned in stable chronological order with creation dates visible

#### Scenario: No footprints match
- **WHEN** valid filters produce no records
- **THEN** the page explains the empty result and offers to clear filters without suggesting that the user's other records were deleted

### Requirement: Incomplete journey context remains separate and resumable
A footprint MAY identify that its owning journey is incomplete and provide an explicit action to continue that formal journey, but journey status SHALL be secondary context and route progress statistics SHALL NOT replace the footprint's semantic content.

#### Scenario: Browse a partial journey footprint
- **WHEN** a footprint belongs to an active incomplete journey
- **THEN** the user can read or organize the footprint and separately choose to resume the existing owner journey without resetting it

#### Scenario: Journey cannot currently resume
- **WHEN** the associated journey is unavailable or cannot be loaded
- **THEN** the footprint remains readable and editable while only the resume action reports a recoverable failure

### Requirement: Related published city reading
The footprint detail SHALL offer relevant published city text selected from backend city and theme relationships. Recommendations MUST remain server-driven, exclude unavailable content, and MUST NOT expose private records belonging to other users.

#### Scenario: Related content exists
- **WHEN** published city stories share the footprint city or related themes
- **THEN** the detail shows concise links to those text-reading experiences after the private footprint content

#### Scenario: Related content is absent
- **WHEN** no eligible published city text is related
- **THEN** the footprint detail remains complete without an empty or broken recommendation rail

### Requirement: Explicit private-to-share-card boundary
The client SHALL generate a shareable footprint card only after the owner invokes a share action. The default card SHALL use privacy-safe editorial and selected personal text without a private photograph; including a photograph SHALL require a separate explicit choice and confirmation for that export. Creating a card MUST NOT publish a community post or change server-side privacy.

#### Scenario: Share a text card
- **WHEN** the owner chooses to generate a card and does not enable photograph inclusion
- **THEN** the client creates a local image containing the selected summary context and no private photo bytes, then opens the platform share sheet

#### Scenario: Include a private photograph
- **WHEN** the owner enables photograph inclusion and confirms that the exported copy may leave the private footprint
- **THEN** only that generated local card includes the photograph and the server source remains private

#### Scenario: Cancel sharing
- **WHEN** the user cancels before or inside the platform share sheet
- **THEN** no community content or public server object is created and temporary export files are eligible for cleanup

### Requirement: Historical footprint migration and ownership
Existing user-owned journeys with revealed fragmented stories or completed legacy stops SHALL be represented as idempotently backfilled footprint entries. Backfill SHALL preserve available private keepsakes, SHALL avoid audio/playback fields, SHALL not modify journey progress, and SHALL remain isolated by the original owner.

#### Scenario: Backfill an existing fragmented journey
- **WHEN** migration encounters two revealed story points in an incomplete or completed owned journey
- **THEN** it creates at most two owner footprints from semantic server content and leaves trigger, collection and reconstruction state unchanged

#### Scenario: Backfill a legacy completed route
- **WHEN** migration encounters completed legacy stops without fragmented-story metadata
- **THEN** it creates readable legacy semantic summaries from existing stop insight content without fabricating audio-independent user observations

#### Scenario: Backfill is rerun
- **WHEN** the migration or lazy reconciliation runs more than once
- **THEN** unique stable source keys prevent duplicate footprints and photographs

### Requirement: Accessible and resilient footprint experience
Footprint entry, editing, filters, photographs and share controls SHALL expose semantic labels, selected/private states, minimum touch targets, readable contrast and reduced-motion behavior. Known footprint snapshots SHALL remain readable through recoverable network, photo and recommendation failures.

#### Scenario: Screen reader reads a footprint
- **WHEN** assistive technology focuses a footprint card
- **THEN** it announces city, story, time, organization state, private-photo state and available action without relying on color or route-completion statistics

#### Scenario: Reduced motion is enabled
- **WHEN** the platform requests reduced motion while filters, editing or share-card previews change
- **THEN** decorative transitions are removed or shortened while state changes remain understandable

#### Scenario: Refresh fails
- **WHEN** a refresh fails after footprints were already loaded
- **THEN** the client retains the known private entries, explains the recoverable failure and provides retry without replacing them with a false empty state
