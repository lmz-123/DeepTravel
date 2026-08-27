## Purpose

为运营和部署提供可验证的城市、景点与媒体归属视图，并保证所有运行环境只把持久媒体存入同一套 OSS 资源体系：公共对象通过 CDN，私有对象通过授权访问。

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

### Requirement: OSS is the only runtime persistent media store
The API, administration service, development runtime, test runtime, and production runtime SHALL require valid OSS configuration before becoming ready. All persistent editorial media, narration, pre-departure audio, user photos, footprint evidence, community media, and temporary narration previews SHALL be stored in the configured public or private OSS bucket. A local filesystem media provider or persistent media mount MUST NOT be an available runtime fallback. Unit tests MAY use an in-memory fake that does not persist or touch shared OSS objects.

#### Scenario: Runtime starts without complete OSS configuration
- **WHEN** any non-unit-test runtime lacks its required OSS region, buckets, credentials, or public CDN base
- **THEN** startup/readiness fails with non-secret configuration diagnostics before accepting media or publication operations

#### Scenario: Any media category is uploaded
- **WHEN** the system accepts public content, narration, user evidence, community media, or a temporary preview
- **THEN** it writes an immutable or versioned object to the appropriate OSS scope and commits only OSS metadata/object references to MySQL

### Requirement: Production and test share the complete canonical OSS resource set
Production and test runtimes SHALL use the same public bucket, private bucket, object keys, media references, CDN base, and private-access behavior. Business media MUST NOT be copied, renamed, prefixed, or isolated by runtime environment. Test credentials SHALL resolve the same public and private canonical objects as production. A real-OSS integration test that creates disposable fixtures SHALL use a reserved temporary prefix with bounded lifecycle and MUST NOT overwrite or delete canonical objects; default automated tests SHALL use an in-memory fake.

#### Scenario: Test reads published content
- **WHEN** test and production request the same approved media identity
- **THEN** both resolve the same canonical OSS object and checksum rather than environment-specific copies

#### Scenario: Test reads private evidence through the application
- **WHEN** test and production request the same authorized private media identity
- **THEN** both resolve the same private OSS object key through the same ownership and authorization rules rather than environment-specific copies

#### Scenario: Integration test writes media
- **WHEN** an authorized real-OSS integration test creates or replaces a fixture
- **THEN** the object is confined to the reserved temporary prefix and the test cannot overwrite or delete any shared canonical key

### Requirement: Public CDN and private authorization boundaries
Public editorial images and audio SHALL resolve only to the configured CDN base backed by the public OSS bucket. Private photos, evidence, private community resources, and temporary previews SHALL remain in the private OSS bucket and SHALL be retrievable only through owner/operator authorization, an authenticated proxy, or a short-lived signed URL. No API or CMS response SHALL expose OSS credentials, private permanent URLs, or filesystem paths.

#### Scenario: Public narration is serialized
- **WHEN** a published story or scenic route returns its approved public narration
- **THEN** the URL uses the configured CDN base and supports the required MIME and byte-range behavior

#### Scenario: Private evidence is requested
- **WHEN** the authenticated owner requests private evidence
- **THEN** the service authorizes ownership and streams from OSS or returns a short-lived signed reference without exposing it through the public CDN

#### Scenario: Legacy public asset URL is requested during compatibility
- **WHEN** a supported old client requests `/api/v1/assets/<key>` after that key has been migrated
- **THEN** the endpoint redirects to the canonical CDN URL and does not read a local media file

### Requirement: Public editorial photographs use normalized JPEG objects
Accepted public editorial images SHALL be decoded and stored as JPEG quality 85 before their checksum, immutable object key, MIME, and canonical URL are committed. Existing PNG city, scenic, stop, and city-story cover references SHALL be migrated to new JPEG objects and reconciled without deleting the prior OSS objects during rollback observation. Audio and private evidence bytes SHALL not be transformed by this rule.

#### Scenario: Existing cover PNG is migrated
- **WHEN** the reviewed migration processes an existing referenced public PNG cover
- **THEN** it uploads one JPEG quality-85 object, updates the media row and every known content reference transactionally, and public APIs resolve the new `image/jpeg` URL

### Requirement: Full local-to-OSS migration is idempotent and terminal
The system SHALL provide dry-run-capable checksum migration for every existing public and private persistent media category, SHALL update canonical references without changing content or ownership identity, and SHALL reconcile database rows, object counts, checksums, MIME, authorization scope, and orphan/missing reports. After the verified cutover, services MUST run without media host mounts or local media reads.

#### Scenario: Dry-run finds legacy public and private assets
- **WHEN** the operator runs migration in dry-run mode
- **THEN** it reports planned uploads by public/private category, matching objects, missing files, orphaned assets, ownership/scope errors, and reference updates without writing media or database changes

#### Scenario: Migration fails before reference commit
- **WHEN** an OSS upload or database update fails
- **THEN** no content reference points to an incomplete object and a retry can continue without duplicate objects

#### Scenario: Cutover verification passes
- **WHEN** every persistent media row and content reference resolves to a verified OSS object with the expected scope and checksum
- **THEN** local media serving and host mounts are disabled and the runtime remains healthy using OSS only
