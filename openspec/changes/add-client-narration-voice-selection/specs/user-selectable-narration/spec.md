## Purpose

Let each traveler choose a consistent published narration voice for an entire route while preserving exact transcripts, reliable background playback, and backward-compatible default audio.

## ADDED Requirements

### Requirement: Published voice profiles are editorial content
The system SHALL expose only active published voice profiles with stable identifiers, traveler-facing names, concise style descriptions, display order, and optional preview media. Provider voice IDs and credentials MUST remain server-side editorial metadata.

#### Scenario: Traveler opens the voice selector
- **WHEN** a published route has more than one complete voice profile
- **THEN** the client displays the backend-provided profile names and descriptions in configured order without exposing provider credentials

#### Scenario: Draft profile exists
- **WHEN** an editor has created or generated a voice profile that is not published
- **THEN** public APIs and the client do not expose it

### Requirement: A selectable route voice has complete current-script coverage
A voice profile SHALL be selectable for a route only when every narrated fragment has one approved public track for that profile whose transcript hash and script version match the fragment. Voice choice MUST NOT change transcript text or progression rules.

#### Scenario: One fragment track is missing
- **WHEN** a profile lacks an approved current-script track for any narrated fragment in the route
- **THEN** that profile is absent from the route's selectable voice list

#### Scenario: Transcript changes after voice generation
- **WHEN** one fragment transcript changes after its profile track was approved
- **THEN** that profile becomes incomplete for the route until a matching replacement track is approved

### Requirement: Traveler selection is stable and account-scoped
The client SHALL let the traveler select one available route voice, SHALL retain the preference locally under the authenticated user identity, and SHALL reuse it on later launches when that profile remains available.

#### Scenario: User returns to a route
- **WHEN** the same authenticated account previously selected a profile that remains complete and published
- **THEN** route detail and journey playback show and use that profile

#### Scenario: Accounts switch on one device
- **WHEN** account B logs in after account A selected a voice
- **THEN** account B receives its own saved preference or the route default and does not inherit account A's selection

### Requirement: Playback resolves the selected track consistently
Foreground playback, background audio, prepared downloads, resume, and replay SHALL resolve the selected profile's track for the current fragment. Cache identity MUST distinguish profile and transcript version.

#### Scenario: Selected fragment begins
- **WHEN** the traveler plays a fragment with a matching selected-profile track
- **THEN** the selected public audio URL plays while the unchanged route transcript remains visible

#### Scenario: Traveler changes voice during playback
- **WHEN** a different profile is selected while narration is already playing
- **THEN** the current playback is not silently replaced and the client clearly applies the new profile to the next playback or explicit replay

### Requirement: Fallback is deterministic and visible
Each route SHALL retain one default narration track for backward compatibility. If a saved profile is absent, withdrawn, or invalid, the client SHALL use the backend-declared default, update its local effective selection, and communicate the fallback without blocking the journey.

#### Scenario: Saved profile was unpublished
- **WHEN** route data no longer includes the saved profile
- **THEN** the client uses the declared default profile and shows a non-blocking message that the previous voice is unavailable

#### Scenario: Old client requests the route
- **WHEN** a client does not understand voice profiles
- **THEN** the existing singular audio field still resolves to the route's default approved track

### Requirement: Voice approval never overwrites another profile
Approving a generated track SHALL create or update only the targeted fragment/profile/script version and SHALL use a distinct immutable public object. The admin SHALL report route coverage before a profile can be published.

#### Scenario: Editor approves a second voice
- **WHEN** the same fragment transcript already has an approved default track and the editor approves another profile
- **THEN** both tracks remain independently addressable and the default track remains unchanged unless a dedicated default action is performed

#### Scenario: Editor attempts to publish incomplete coverage
- **WHEN** any narrated fragment lacks a matching approved track for the profile
- **THEN** publication is rejected with the missing fragments listed

### Requirement: Admin generates one voice for a complete route
The admin SHALL make route-wide generation the primary workflow. One action for a selected voice profile SHALL generate and permanently store a current-script track for every narrated fragment in the selected route. The existing default profile SHALL be selected initially so an editor can create one usable route voice without configuring every node separately. Per-fragment generation SHALL remain available only as a retry or replacement tool.

#### Scenario: Editor generates the default route voice
- **WHEN** an editor opens a route and starts route-wide generation without creating another profile
- **THEN** the system generates the default profile for every narrated fragment, stores each successful result as the formal profile track, and reports complete route coverage

#### Scenario: Editor adds another selectable voice
- **WHEN** an editor selects a second profile and starts route-wide generation
- **THEN** the system generates the same unchanged scripts for every route fragment under that profile without overwriting the default profile tracks

#### Scenario: One node fails during route generation
- **WHEN** the provider or storage fails for one fragment while other fragments succeed
- **THEN** the admin reports the failed fragment by name, keeps every prior formal track intact, keeps the profile unavailable to travelers, and offers retrying only missing or stale nodes

#### Scenario: Editor corrects one generated node
- **WHEN** one formal track has a pronunciation or delivery problem
- **THEN** the editor can regenerate and replace that fragment/profile track without regenerating other route nodes
