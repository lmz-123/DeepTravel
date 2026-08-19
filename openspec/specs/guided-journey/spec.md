# guided-journey Specification

## Purpose
Guide a guest through a durable sequence of place-based stories and observation challenges while preserving freedom to pause, resume, and explore at their own pace.

## Requirements

### Requirement: Guest journey lifecycle
The system SHALL allow an authenticated guest session to start, retrieve, resume, advance, and complete one journey for a published route.

#### Scenario: Start a new journey
- **WHEN** a guest starts a route without an unfinished journey
- **THEN** the system creates an active journey at the first stop

#### Scenario: Resume an existing journey
- **WHEN** a guest starts a route with an unfinished journey
- **THEN** the system returns that journey without resetting progress

### Requirement: Arrival confirmation
The system SHALL accept arrival when the submitted location is within the stop radius, and SHALL permit explicit demo arrival only when demo arrival is enabled.

#### Scenario: Location is near the stop
- **WHEN** the guest submits coordinates within the current stop arrival radius
- **THEN** the current stop becomes arrived

#### Scenario: Location is too far away
- **WHEN** the guest submits coordinates outside the current stop arrival radius
- **THEN** the system rejects arrival and returns the calculated distance

#### Scenario: Demo arrival is disabled
- **WHEN** the guest requests demo arrival while demo arrival is disabled
- **THEN** the system rejects the request

### Requirement: Observation answer feedback
The system SHALL accept one answer for the current arrived stop and return correctness, explanation, and the stop insight without exposing the correct answer beforehand.

#### Scenario: Correct answer
- **WHEN** the guest submits the correct option for the current stop
- **THEN** the system records the answer and returns positive feedback and explanation

#### Scenario: Repeated answer
- **WHEN** the guest repeats an answer for a previously answered stop
- **THEN** the system returns the existing result without creating a duplicate

### Requirement: Ordered progression and recap
The system SHALL advance only after the current stop is answered and SHALL provide a recap after the final stop is completed.

#### Scenario: Advance before answering
- **WHEN** the guest tries to advance an unanswered stop
- **THEN** the system returns a state-conflict error

#### Scenario: Complete final stop
- **WHEN** the guest advances after answering the final stop
- **THEN** the journey becomes completed and a recap is available
