## MODIFIED Requirements

### Requirement: Complete guided loop
The client SHALL present route preparation, active-tour status, automatic fragment narration, audio controls, photo missions, story-ledger progress, final reconstruction, and completion recap without requiring continuous screen attention.

#### Scenario: Complete one stop
- **WHEN** the current stop's declared passive or photo-fragment completion rule is satisfied
- **THEN** the client collects its fragment, updates progress, and enables any newly eligible route interaction

#### Scenario: Complete one passive fragment
- **WHEN** a location-triggered passive narration reaches its completion rule
- **THEN** the client collects the fragment, confirms it audibly and visually, and returns to hands-free monitoring

#### Scenario: Complete one photo fragment
- **WHEN** a location-triggered mission narration finishes and the traveler later submits accepted photo evidence
- **THEN** the client collects the fragment, updates the ledger, and returns to active-tour or paused state as appropriate

#### Scenario: Complete the route
- **WHEN** all required fragments are collected and the traveler completes the final reconstruction
- **THEN** the client presents the sourced complete story and a recap containing the traveler's evidence

### Requirement: Resilient presentation states
The client SHALL provide loading, empty, permission-limited, inaccurate-location, offline, queued-upload, demo, and recoverable error states without losing known journey or fragment progress.

#### Scenario: API is unavailable
- **WHEN** a network request fails in API mode
- **THEN** the client presents retry or queued-offline behavior appropriate to the operation and retains locally known journey and fragment state

#### Scenario: API is unavailable during a prepared tour
- **WHEN** a network request fails after route assets were prepared
- **THEN** the client continues eligible local trigger and playback behavior, queues safe acknowledgements, and presents retry state without discarding progress

#### Scenario: Location is persistently inaccurate
- **WHEN** the client cannot obtain location accuracy sufficient for an automatic trigger
- **THEN** it explains the limitation and offers safe retry, foreground guidance, or configured fallback without automatically collecting a production fragment

## ADDED Requirements

### Requirement: Headset-first interaction
The client SHALL communicate essential tour state through concise audio cues and system media controls so the traveler can keep the phone pocketed between explicit visual missions.

#### Scenario: Fragment is collected hands-free
- **WHEN** a passive fragment becomes collected while the screen is locked
- **THEN** an optional short audio cue confirms collection and monitoring continues without requiring an unlock

#### Scenario: Photo mission becomes available
- **WHEN** narration introduces a photo mission
- **THEN** the client announces that a visual action is available, preserves it as pending, and does not demand immediate unsafe phone use

### Requirement: Active-tour safety state
The client SHALL make it clear when location monitoring and automatic narration are active and SHALL provide one-tap pause and stop controls from the app and supported system surfaces.

#### Scenario: Traveler pauses active tour
- **WHEN** the traveler pauses from the notification, lock screen, or app
- **THEN** new automatic narration is suspended while current progress and queued missions remain available

#### Scenario: Evaluator chooses a location mode
- **WHEN** demo triggering is configured for the client
- **THEN** route setup and active-tour status expose an accessible real-or-simulated location switch with concise consequences for permission, automatic arrival, and manual arrival

#### Scenario: Simulated mode is active
- **WHEN** the active tour runs in simulated location mode
- **THEN** the client visibly distinguishes simulation from live monitoring and presents a deliberate “simulate arrival at next clue” action without implying that GPS is active
