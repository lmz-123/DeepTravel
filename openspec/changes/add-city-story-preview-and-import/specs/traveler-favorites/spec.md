## Purpose

为已认证用户提供跨设备保存感兴趣城市、景点和主题的轻量收藏能力，并保证收藏不会暗中改变定位排序或公开为社交排行。

## ADDED Requirements

### Requirement: Account-scoped favorites
The system SHALL allow an authenticated user to add, list, and remove favorites whose target is a published city, point, or theme, and SHALL isolate those records from every other account.

#### Scenario: User favorites a point
- **WHEN** an authenticated user favorites a published point
- **THEN** the point appears in that user's favorites and no other user's favorites

#### Scenario: Anonymous user attempts to persist a favorite
- **WHEN** an unauthenticated client requests a persistent favorite change
- **THEN** the system returns an authentication-required error without creating a shared or anonymous server record

### Requirement: Idempotent favorite changes
Favorite creation and removal SHALL be idempotent for the same user, target type, and stable target identifier.

#### Scenario: Favorite request is retried
- **WHEN** the same authenticated favorite request is submitted more than once
- **THEN** exactly one favorite exists and each successful response reports the same resulting state

### Requirement: Published target integrity
The public favorites response SHALL resolve only targets that remain publicly available and SHALL represent an unavailable saved target without leaking draft content.

#### Scenario: Favorited content is unpublished
- **WHEN** a previously favorited target is no longer published
- **THEN** the response does not expose its draft fields and lets the user remove the unavailable favorite

### Requirement: Favorites do not alter discovery order
The system SHALL NOT use favorites to reorder location-based point discovery or to claim personalized recommendations in this change.

#### Scenario: Nearby points are sorted
- **WHEN** a user with favorites refreshes current-city discovery with a valid position
- **THEN** the point order follows the location-discovery contract independently of favorite state
