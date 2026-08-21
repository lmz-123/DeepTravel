## Purpose

Use deliberate photography to make travelers inspect historically meaningful field evidence while keeping personal media private, recoverable, and optional outside declared missions.

## ADDED Requirements

### Requirement: Field-specific photo prompt
Each photo mission SHALL identify a concrete, publicly observable subject and SHALL explain how noticing that subject relates to the fragment's historical claim.

#### Scenario: Mission is presented
- **WHEN** narration reaches a photo mission prompt
- **THEN** the client gives a concise audible prompt, a visual equivalent, safety guidance, and an example description without supplying a deceptive stock answer photo

#### Scenario: Subject is unavailable
- **WHEN** the subject is inaccessible, closed, unsafe, or obscured
- **THEN** the traveler can postpone the mission and continue the audio tour without losing the fragment trigger

### Requirement: Camera evidence capture
The client SHALL let the traveler capture evidence for the current mission and review it before submission.

#### Scenario: Photo is captured
- **WHEN** the traveler opens a mission and grants camera permission
- **THEN** the client captures a photo, shows a preview, and lets the traveler retake, submit, or cancel it

#### Scenario: Camera permission is denied
- **WHEN** camera permission is denied
- **THEN** the client preserves the mission as pending and explains how to grant permission or use an authored accessibility alternative when one exists

### Requirement: Evidence upload resilience
Evidence submission SHALL support idempotent retry and SHALL not require the traveler to keep the mission screen open during upload.

#### Scenario: Upload succeeds
- **WHEN** a valid photo upload is accepted
- **THEN** the evidence is linked privately to the guest journey and mission and the fragment collection rule is reevaluated

#### Scenario: Network fails during upload
- **WHEN** upload fails after capture
- **THEN** the client retains a pending local record, communicates its state, and retries only under configured network and user-consent conditions

#### Scenario: Upload is retried
- **WHEN** the same evidence submission is retried
- **THEN** the backend returns the original evidence resource without creating duplicates

### Requirement: Evidence validation without truth scoring
The backend SHALL validate evidence format and safety limits but SHALL NOT claim that a photo proves a historical interpretation in this MVP.

#### Scenario: Valid evidence is submitted
- **WHEN** an authenticated guest submits a supported image within configured dimensions and size
- **THEN** the backend accepts it as completion evidence without assigning semantic correctness

#### Scenario: Invalid media is submitted
- **WHEN** a file has an unsupported type, exceeds limits, or fails image decoding
- **THEN** the backend rejects it with a structured error and does not collect the mission fragment

### Requirement: Private-by-default evidence
Traveler photographs SHALL remain private to the guest journey, SHALL not appear in public media endpoints or social surfaces, and SHALL have unnecessary metadata removed.

#### Scenario: Evidence is stored
- **WHEN** the backend accepts a photograph
- **THEN** it strips embedded location metadata when technically possible and exposes the photo only through an authorized journey-scoped resource

#### Scenario: Another guest requests evidence
- **WHEN** a different guest token requests the photograph
- **THEN** the backend returns an authorization error without revealing metadata

### Requirement: Traveler evidence control
The traveler SHALL be able to remove submitted evidence and understand the resulting journey state.

#### Scenario: Evidence is removed before completion
- **WHEN** the traveler deletes evidence required by a collected fragment before final reconstruction
- **THEN** the evidence is removed and that mission returns to pending without deleting unrelated fragments

#### Scenario: Retention expires
- **WHEN** configured guest-evidence retention expires
- **THEN** stored photographs are deleted while non-identifying historical progress may remain according to the published retention policy
