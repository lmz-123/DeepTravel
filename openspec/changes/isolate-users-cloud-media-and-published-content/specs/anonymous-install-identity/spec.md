## Purpose

Provide a conventional account-backed ownership boundary while keeping MVP testing fast through explicitly gated test accounts and preserving compatible legacy guest progress.

## ADDED Requirements

### Requirement: User accounts are the ownership identity
The system SHALL allow a traveler to register and log in with a unique username and password. It MUST store only a secure one-way password hash, issue an expiring bearer token identifying the user, and MUST NOT use an installation identifier, hardware serial, advertising identifier or device fingerprint as the ownership principal.

#### Scenario: Traveler registers
- **WHEN** a traveler submits an available valid username and password
- **THEN** the server creates one user, stores a password hash, and returns authorization for that user without storing the plaintext password

#### Scenario: Traveler logs in again
- **WHEN** the traveler submits the same valid credentials after logout, token expiry, or application reinstall
- **THEN** the new token identifies the same user and exposes that user's existing progress

#### Scenario: Invalid credentials are submitted
- **WHEN** a traveler submits an unknown username or incorrect password
- **THEN** the server returns one generic authentication failure without revealing which field was incorrect

### Requirement: Test login is simple and deployment-gated
The system SHALL support one-tap login to a small configured allowlist of isolated test users only when test authentication is explicitly enabled. The endpoint MUST be unavailable when disabled and MUST NOT silently create arbitrary production users.

#### Scenario: Test build logs in as tester A
- **WHEN** the test-authenticated client selects configured alias `tester-a`
- **THEN** the server issues authorization for tester A and returns only tester A's progress

#### Scenario: Production disables test login
- **WHEN** test authentication is disabled and any client calls the test-login endpoint
- **THEN** the server returns not found and issues no token

### Requirement: Every private operation enforces user ownership
Journey, fragment, playback, evidence, reconstruction, recap and active-tour operations MUST resolve the requested journey through the authenticated `user_id`. A non-owner MUST receive the same not-found response as an unknown resource and MUST learn no owner or progress metadata.

#### Scenario: Another user guesses a journey identifier
- **WHEN** user B requests user A's journey, ledger, reconstruction or recap identifier
- **THEN** the operation returns not found and discloses no route progress

#### Scenario: Another user guesses an evidence identifier
- **WHEN** user B requests, replaces or deletes user A's private evidence
- **THEN** the operation returns not found and no object URL or metadata is disclosed

#### Scenario: Owner resumes progress
- **WHEN** the owning user logs in and presents a valid token
- **THEN** it can resume the same journey and sees only its own fragment, playback and evidence state

### Requirement: Legacy guest progress remains upgradeable
Each existing guest principal SHALL map to a temporary user during migration. A valid legacy authorization SHALL continue to resolve that user during the compatibility window, and the traveler SHALL be able to set username/password credentials on that same user without reassigning journey ownership.

#### Scenario: Legacy traveler sets credentials
- **WHEN** a valid legacy principal chooses an available username and valid password
- **THEN** the temporary user becomes a normal account and all existing journey and evidence ownership remains on the same user ID
