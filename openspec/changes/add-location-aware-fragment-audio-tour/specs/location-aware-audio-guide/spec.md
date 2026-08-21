## Purpose

Provide a safe, deterministic, headset-first walking mode that uses location to reveal and play route narration while the traveler keeps the phone pocketed or locked.

## ADDED Requirements

### Requirement: Explicit active-tour lifecycle
The client SHALL monitor continuous location for a route only after the traveler explicitly starts an active tour, and SHALL stop monitoring when the tour is stopped, completed, expired, or revoked by the traveler.

#### Scenario: Traveler starts an active tour
- **WHEN** the traveler starts a route and grants the required location and notification permissions
- **THEN** the client activates location monitoring, displays a persistent active-tour indicator, and makes a stop control available

#### Scenario: Traveler stops the tour
- **WHEN** the traveler selects stop tour
- **THEN** the client stops continuous location monitoring and automatic audio triggers without deleting collected fragments

#### Scenario: Permission is denied
- **WHEN** the traveler denies a required location permission
- **THEN** the client explains which hands-free behavior is unavailable and offers settings, foreground-only, or configured demo fallback actions without silently claiming that automatic triggering is active

### Requirement: Stable location trigger policy
The client SHALL trigger an eligible fragment only after location samples establish a stable entry into its configured region, SHALL account for reported accuracy, and SHALL apply hysteresis and cooldown rules to avoid boundary oscillation.

#### Scenario: Stable region entry
- **WHEN** at least two qualifying samples place the traveler inside an eligible fragment's entry radius with acceptable accuracy
- **THEN** the fragment is enqueued once and the trigger acknowledgement records the fragment and journey

#### Scenario: Inaccurate sample
- **WHEN** a location sample's accuracy exceeds the route's configured maximum
- **THEN** that sample does not independently trigger a fragment and the client continues waiting for a qualifying sample

#### Scenario: Traveler oscillates near a boundary
- **WHEN** samples alternate around a trigger boundary without first crossing the configured exit radius and cooldown
- **THEN** the already-triggered fragment is not enqueued again

#### Scenario: Traveler reaches a later region first
- **WHEN** the traveler enters a region whose fragment has an unmet ordering dependency
- **THEN** the client records the nearby region, does not spoil the locked fragment, and gives a short non-blocking instruction to continue or return to the prerequisite area

### Requirement: Background and locked-screen continuity
An active tour SHALL continue location trigger evaluation and audio playback while the app is backgrounded or the device is locked, subject to operating-system constraints that are clearly communicated to the traveler.

#### Scenario: Screen is locked during a walk
- **WHEN** the device is locked after an active tour starts
- **THEN** eligible location entries still enqueue narration and playback controls remain available on the lock screen

#### Scenario: Operating system suspends monitoring
- **WHEN** the operating system prevents or terminates background monitoring
- **THEN** the client preserves journey state and, on resume, explains that automatic triggering paused rather than fabricating missed triggers

### Requirement: Non-overlapping narration queue
The client SHALL play at most one route narration at a time and SHALL manage simultaneous location triggers through a visible, deterministic queue.

#### Scenario: A second region triggers during narration
- **WHEN** another eligible fragment triggers while narration is playing
- **THEN** the second fragment is queued without interrupting the current historical statement

#### Scenario: Traveler controls narration
- **WHEN** narration is available
- **THEN** the traveler can pause, resume, replay, seek, change supported speed, and open an equivalent transcript

#### Scenario: Queued fragment becomes contextually stale
- **WHEN** a queued fragment requires the traveler to still be near its field clue but playback begins after the traveler has left the region
- **THEN** the client asks whether to play it now or save it for later instead of presenting the field task as if the traveler were still present

### Requirement: Audio interruption and headset safety
The client SHALL coordinate route narration with system audio interruptions and SHALL avoid unexpectedly playing private narration through the device speaker after a headset disconnect.

#### Scenario: Phone call or navigation prompt interrupts
- **WHEN** the operating system interrupts narration for a call, alarm, or higher-priority navigation prompt
- **THEN** route narration pauses or ducks according to platform convention and exposes an understandable resume state afterward

#### Scenario: Headset disconnects
- **WHEN** a wired or wireless headset disconnects during narration
- **THEN** narration pauses before audio can continue through the speaker and waits for explicit user action or headset reconnection

### Requirement: Prepared-route resilience
The client SHALL allow a traveler to prepare a route by downloading its required narration, transcripts, fragment metadata, and mission prompts before departure.

#### Scenario: Network is lost after preparation
- **WHEN** a prepared active tour loses network connectivity
- **THEN** location triggers, cached narration, transcripts, and local fragment collection continue to work while server acknowledgements and evidence uploads wait for retry

#### Scenario: Required audio is unavailable
- **WHEN** a fragment triggers but neither a cached nor reachable audio asset is available
- **THEN** the client preserves the trigger, presents the transcript, and allows narration retry without marking playback as completed

### Requirement: Location minimization
The system SHALL use location for active-tour triggering and diagnostics without retaining a continuous travel trace as product history.

#### Scenario: Location sample is evaluated
- **WHEN** the client evaluates a location sample
- **THEN** it retains only the minimum state needed for trigger stability and does not upload a continuous coordinate history

#### Scenario: Trigger is acknowledged
- **WHEN** the client acknowledges a fragment trigger to the backend
- **THEN** the backend stores the fragment, journey, trigger time, method, and optional coarse verification result rather than a raw breadcrumb trail

### Requirement: Controlled demo triggering
The system SHALL permit manual or synthetic trigger events only when the deployment explicitly enables demo triggering and SHALL identify the trigger method in journey state.

#### Scenario: Demo triggering is enabled
- **WHEN** a configured evaluator manually triggers the current fragment
- **THEN** the fragment follows the normal queue and collection flow with its trigger method marked as demo

#### Scenario: Demo triggering is disabled
- **WHEN** a client requests a synthetic trigger in production configuration
- **THEN** the system rejects it with a structured error
