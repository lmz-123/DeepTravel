# offline-route-package Specification

## ADDED Requirements

### Requirement: Published scenic areas expose a versioned offline package

The system SHALL expose a canonical offline-package manifest only for a published scenic route. The manifest SHALL contain route metadata, all story text required during the route, selected narration asset identities, one package version, a package SHA-256 checksum, and per-asset byte size and SHA-256 checksum.

#### Scenario: Published package is requested

- **WHEN** a client requests the offline package for a published scenic route
- **THEN** the server returns complete route metadata, story text, and narration asset identities
- **AND** the package version matches the route script version
- **AND** the canonical package checksum and each asset checksum are present

#### Scenario: Unpublished package is requested

- **WHEN** a client requests an offline package for a draft, archived, or unknown route
- **THEN** the server does not expose an offline package for that route

### Requirement: Package installation is atomic and integrity checked

The client SHALL mark a package complete only after the manifest checksum and every selected narration asset's size, checksum, and version pass validation. Package audio SHALL use the same local file and prepared-asset index consumed by the narration player.

#### Scenario: All resources validate

- **WHEN** every required resource has been downloaded or reused and passes validation
- **THEN** the client atomically records the package as complete
- **AND** the completion state exposes its version and integrity confirmation

#### Scenario: One resource fails validation

- **WHEN** a required resource is missing, truncated, has the wrong checksum, or belongs to another version
- **THEN** the package remains unavailable for offline start
- **AND** the control shows a retryable failure without deleting a previously complete version

### Requirement: Verified packages support offline route use

The client SHALL load route metadata, story text, selected narration audio, and locally known playback state from a complete verified package when the network is unavailable.

#### Scenario: Traveler starts while offline

- **WHEN** a traveler opens and starts a complete verified scenic package without network access
- **THEN** the route begins from packaged metadata and local cached audio
- **AND** text and playback progress remain available without a server response

#### Scenario: Package is stale or incomplete

- **WHEN** the only local package is stale, failed, or incomplete
- **THEN** the client does not present it as offline-ready
- **AND** the traveler receives a recoverable retry state

### Requirement: Offline mutations synchronize idempotently

The client SHALL enqueue offline journey creation, trigger, playback, and evidence state locally and SHALL automatically reconcile the ordered queue when connectivity returns. Repeated reconciliation MUST NOT duplicate accepted server mutations.

#### Scenario: Connectivity returns

- **WHEN** a local journey has pending ordered mutations and the device regains connectivity
- **THEN** the client resolves the local journey alias, submits each mutation with its stable idempotency key, and acknowledges accepted queue items

#### Scenario: Reconciliation is interrupted

- **WHEN** connectivity fails after only part of the queue is accepted
- **THEN** accepted items remain acknowledged and later retries resume at the first pending item without duplicating accepted state
