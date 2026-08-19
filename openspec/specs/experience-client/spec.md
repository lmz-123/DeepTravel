# experience-client Specification

## Purpose
Provide a refined Flutter experience that keeps attention on the physical place, remains usable without production credentials, and communicates progress and failure clearly.

## Requirements

### Requirement: Three-tap route start
The client SHALL allow a first-time user to begin the featured route in no more than three primary taps from launch.

#### Scenario: First launch in demo mode
- **WHEN** the client launches with demo mode enabled
- **THEN** the featured route is visible and can be started without registration or an API key

### Requirement: Complete guided loop
The client SHALL present arrival, story, audio controls, observation, answer feedback, and continuation for each stop.

#### Scenario: Complete one stop
- **WHEN** the user arrives and answers a stop
- **THEN** the client reveals the explanation and enables progression to the next stop

### Requirement: Resilient presentation states
The client SHALL provide loading, empty, offline/demo, and recoverable error states without losing known journey progress.

#### Scenario: API is unavailable
- **WHEN** a network request fails in API mode
- **THEN** the client presents a retry action and retains locally known state

### Requirement: Accessible and restrained motion
The client SHALL use readable contrast, semantic labels, minimum touch targets, text alternatives for audio, and reduced motion when requested by the platform.

#### Scenario: Reduced motion is enabled
- **WHEN** the operating system requests reduced motion
- **THEN** decorative transitions are shortened or removed while state changes remain understandable
