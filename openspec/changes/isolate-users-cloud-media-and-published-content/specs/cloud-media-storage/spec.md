## Purpose

Move editorial and traveler media away from container-local disks into configurable object storage while preserving private evidence access and credential-free local development.

## ADDED Requirements

### Requirement: Media storage is provider-neutral
The backend and independent admin SHALL store media through one object-storage contract supporting at least local development storage and Alibaba Cloud OSS. Storage provider selection and credentials SHALL come from deployment configuration, and tests MUST run without cloud credentials.

#### Scenario: Local development profile uploads media
- **WHEN** object storage is configured as local
- **THEN** existing filesystem-backed upload and retrieval behavior remains available through the same application contract

#### Scenario: OSS production profile uploads media
- **WHEN** object storage is configured as OSS with valid credentials
- **THEN** validated media bytes are stored under a collision-resistant object key and MySQL records metadata and a canonical object reference rather than binary data

### Requirement: Published editorial media resolves from cloud URLs
Published city covers, route covers, stop images and narration SHALL resolve to absolute OSS/CDN URLs. Public serializers MUST preserve absolute URLs and SHALL use the legacy backend asset route only for unmigrated local references.

#### Scenario: Client requests a published route
- **WHEN** all route assets have been migrated to OSS
- **THEN** every image and narration URL in the response is an absolute configured cloud URL and no container filesystem path is exposed

#### Scenario: Legacy local asset remains during migration
- **WHEN** a media record still uses a safe relative local path
- **THEN** it remains readable through the backend asset endpoint until the idempotent migration updates it

### Requirement: Traveler evidence remains private
Traveler photos MUST be validated, stripped of metadata and normalized before OSS storage. Evidence objects SHALL be private, SHALL use user- and journey-scoped object keys, and SHALL be retrievable only by the authenticated owner through a short-lived authorized response.

#### Scenario: Owner uploads a photo
- **WHEN** the owning user submits an eligible photo
- **THEN** the backend validates and normalizes it, uploads the resulting bytes to a private object and records its canonical object reference and retention metadata

#### Scenario: Owner opens a photo
- **WHEN** the owner requests accepted evidence
- **THEN** the backend either streams the object or returns a short-lived signed URL without exposing OSS credentials

#### Scenario: Signed URL expires
- **WHEN** a previously issued private evidence URL has expired
- **THEN** it no longer grants access and the owner must request a new authorized URL

### Requirement: Media mutation is safe and traceable
Media records SHALL retain provider, object key, canonical URL, MIME type, byte size, checksum and timestamps. A referenced published asset MUST NOT be deleted, and failed database/object operations SHALL not leave a public graph pointing at a missing object.

#### Scenario: Referenced asset deletion is attempted
- **WHEN** an operator deletes media referenced by published content
- **THEN** the operation is rejected and the object and database record remain intact

#### Scenario: Existing media migration is repeated
- **WHEN** the same local-to-OSS migration runs more than once
- **THEN** already matching objects are not duplicated and all references remain stable
