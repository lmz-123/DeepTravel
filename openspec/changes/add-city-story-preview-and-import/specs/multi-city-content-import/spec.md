## Purpose

定义可验证、可预览、幂等且事务安全的多城市 JSON 内容包导入契约，使批量导入与后台手动编辑共享数据模型和正式发布生命周期。

## ADDED Requirements

### Requirement: Versioned multi-city package
The system SHALL accept a versioned JSON package that can describe cities, routes, points, canonical story references or story content, media descriptors, WGS-84 coordinates, location ranges, tags, relations, advisory order, and requested publication placements using stable identifiers.

#### Scenario: Package contains several cities
- **WHEN** a structurally valid package contains related content for multiple cities
- **THEN** all records are resolved in one package graph without requiring one upload per city

#### Scenario: Package embeds media binary
- **WHEN** a package contains embedded image or audio binary instead of an allowed existing media reference and checksum descriptor
- **THEN** validation rejects the field with its precise JSON path

### Requirement: Zero-write validation and preview
The system SHALL provide a dry-run that performs schema, relation, media, fact, lifecycle, and conflict validation without persistent content writes and classifies each record as new, updated, unchanged, conflicted, or invalid.

#### Scenario: Dry-run succeeds
- **WHEN** an authorized editor submits a valid package for preview
- **THEN** the response reports record-level diffs and a confirmation token bound to the package checksum and validated state without changing content

#### Scenario: Field validation fails
- **WHEN** a story references an unknown point or omits a required fact field
- **THEN** the preview identifies the affected record, stable ID, exact JSON path, and actionable reason

### Requirement: Bound confirmation
The system SHALL import only a package that matches an unexpired successful dry-run token and SHALL reject confirmation if the package or relevant target state changed after preview.

#### Scenario: Package changes after preview
- **WHEN** confirmation uses a token for a different package checksum
- **THEN** the system rejects the import and requires a new dry-run

#### Scenario: Existing record changes after preview
- **WHEN** a target record revision no longer matches the dry-run baseline
- **THEN** the system reports a conflict and writes none of the package content

### Requirement: Atomic idempotent draft import
The system SHALL apply a confirmed package in one transaction, reuse stable identifiers, leave imported content in draft or the applicable pre-publication state, and make replay of the same package version idempotent.

#### Scenario: Import succeeds
- **WHEN** an authorized editor confirms a valid unchanged preview
- **THEN** all package records are created or updated together and remain subject to validation, review, approval, and explicit publication

#### Scenario: One record fails during import
- **WHEN** any record cannot be written or related during confirmation
- **THEN** the transaction rolls back all package content changes and returns the failing record and field path

#### Scenario: Same version is imported again
- **WHEN** an already imported package ID and version with the same checksum is confirmed again
- **THEN** no duplicate content is created and the result reports unchanged records

### Requirement: Shared editable content model
Imported records SHALL be immediately available through the same manual city, route, point, story, media, relation, tag, and lifecycle operations used for non-imported records.

#### Scenario: Editor modifies imported content
- **WHEN** a package import completes and an editor opens an imported story
- **THEN** the existing editor can modify and submit it through the normal review lifecycle

### Requirement: Backward-compatible import entry points
Existing supported single-route packages SHALL continue to work while sharing normalization and validation rules with the multi-city importer.

#### Scenario: Legacy single-route package is imported
- **WHEN** an editor uses the supported single-route import endpoint
- **THEN** its observable behavior remains compatible and its resulting records use the same canonical model and lifecycle
