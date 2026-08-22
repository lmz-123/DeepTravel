## Purpose

Make editorial approval and online visibility separate, explicit states so incomplete or merely verified content cannot appear in the public catalog accidentally.

## ADDED Requirements

### Requirement: Route lifecycle states have distinct meanings
Routes SHALL use `draft`, `in_review`, `verified`, `published` and `archived`. `verified` SHALL mean editorial checks passed but the route remains offline; only the explicit publish transition may set `published` and `published_at`.

#### Scenario: Ordinary save marks a route verified
- **WHEN** an operator saves a route with status `verified`
- **THEN** `published_at` remains null and the route remains absent from public APIs

#### Scenario: Explicit publish succeeds
- **WHEN** an authenticated operator publishes a verified complete graph whose validation passes
- **THEN** status becomes `published` and publication time is written atomically

#### Scenario: Publish validation fails
- **WHEN** the graph has blocking content, media or dependency errors
- **THEN** status and publication time remain unchanged and no partial content becomes public

### Requirement: Only published content is publicly discoverable
Public city lists, route lists, route details and journey-start operations MUST expose or accept only routes with status `published` and a non-null publication time. A city without any published route SHALL not be returned as an available destination.

#### Scenario: Route is waiting for review
- **WHEN** a route status is `draft`, `in_review` or `verified`
- **THEN** it is absent from city route lists and direct public detail requests return not found

#### Scenario: Route is archived
- **WHEN** a published route is transitioned to `archived`
- **THEN** it disappears from discovery and new journeys cannot start on it

### Requirement: Existing owned journeys survive archival
Archiving SHALL stop new discovery and starts without invalidating the content snapshot needed by a journey that already references the route.

#### Scenario: Owner resumes an archived route
- **WHEN** the owning user who started before archival resumes the journey
- **THEN** the pinned route, fragment state, media and recap remain available to that owner

### Requirement: Admin surfaces visibility truthfully
The independent admin SHALL label all lifecycle states distinctly, count published routes using the full public predicate, show whether a route is currently visible, and require dedicated review/publish/archive actions rather than publishing through an edit dropdown.

#### Scenario: Operator views a verified route
- **WHEN** a route is verified but not published
- **THEN** the admin displays “已审核·未发布” and indicates that travelers cannot see it

#### Scenario: Legacy rows are migrated
- **WHEN** the lifecycle migration sees a row with an existing publication time
- **THEN** it deterministically maps the row to `published`, while rows without a publication time remain non-public
