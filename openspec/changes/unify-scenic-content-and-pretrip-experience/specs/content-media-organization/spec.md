## Purpose

为运营和部署提供可验证的城市、景点与媒体归属视图，真实区分本地兼容资源和 OSS 对象，并确保生产已发布公共媒体最终从 OSS/CDN 提供。

## ADDED Requirements

### Requirement: Media is attributable by city and scenic area
The administration projection SHALL organize media references under city and scenic-area scopes and SHALL identify each resource's referencing content and role. A resource referenced by several scenic areas SHALL remain one shared asset with multiple references; an unreferenced asset SHALL appear in an explicit unassigned group.

#### Scenario: Scenic area references cover and narration
- **WHEN** an operator opens that scenic area's media group
- **THEN** the group lists its cover and narration with their route/stop/fragment/story roles

#### Scenario: One asset is shared
- **WHEN** the same media asset is referenced by two scenic areas
- **THEN** both groups expose the reference while the asset retains one identity and is marked shared

#### Scenario: Upload is not yet referenced
- **WHEN** a valid uploaded asset has no content reference
- **THEN** it appears under unassigned resources rather than being attributed to an arbitrary city or scenic area

### Requirement: Storage provider is truthful and inspectable
Every managed media item SHALL expose its `storage_provider`, object key or safe legacy path, MIME type, canonical public URL when applicable, and available checksum/size metadata. The system MUST NOT label a local upload as OSS or expose object-storage credentials.

#### Scenario: Local development upload succeeds
- **WHEN** the configured provider is `local`
- **THEN** the media record and administration surface identify it as local development storage and provide its safe local-compatible reference

#### Scenario: OSS upload succeeds
- **WHEN** the configured provider is `oss`
- **THEN** the media record identifies OSS, stores the immutable object key, and exposes the configured public OSS/CDN URL without credentials

### Requirement: Production published media uses OSS
In the production profile, publication readiness SHALL fail when a newly published public image or narration would resolve through a local backend asset URL. Production verification SHALL require the API and administration service to use matching OSS configuration and published public media to resolve through configured OSS/CDN URLs.

#### Scenario: Production still serves a local asset
- **WHEN** a publication or release check finds an eligible resource resolving under `/api/v1/assets/`
- **THEN** the check reports the city, scenic area, content reference, and asset as an OSS migration blocker

#### Scenario: Production OSS sample passes
- **WHEN** representative published covers and narration resolve through the configured OSS/CDN base with correct MIME, readable bytes or range support, and matching metadata
- **THEN** the media portion of production readiness passes

### Requirement: Existing local media migration is idempotent and recoverable
The system SHALL preserve the existing dry-run-capable checksum migration from local public media to OSS, SHALL update canonical media references without changing story identity, and SHALL retain the safe local read path until the migration report and compatibility window allow removal.

#### Scenario: Dry-run finds legacy assets
- **WHEN** the operator runs migration in dry-run mode
- **THEN** it reports planned uploads, matching objects, missing files, orphaned assets, and reference updates without writing media or database changes

#### Scenario: Migration fails before reference commit
- **WHEN** an OSS upload or database update fails
- **THEN** no content reference points to an incomplete object and a retry can continue without duplicate objects
