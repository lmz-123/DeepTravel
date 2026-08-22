## Purpose

为每个已解锁的故事节点提供受账号权限保护的旅行者现场内容，让机位、经验、事实补充和现场观察能够被同地点的其他旅行者持续浏览与互动，同时守住私人足迹照片、官方叙事和防剧透边界。

## ADDED Requirements

### Requirement: Unlocked-node community access
The system SHALL expose community content only to an authenticated traveler who owns a journey in which the requested fragment is revealed or collected. Access SHALL be evaluated using both journey ownership and fragment state, SHALL work for active and completed journeys including archived routes owned by the traveler, and MUST NOT reveal post counts, authors, text, comments, reactions, or media for a locked fragment.

#### Scenario: Browse an unlocked active node
- **WHEN** an authenticated traveler requests community content for a revealed fragment in their active journey
- **THEN** the system returns the visible posts for that fragment

#### Scenario: Browse from a completed footprint
- **WHEN** an authenticated traveler requests community content for a collected fragment in their completed owned journey
- **THEN** the system returns the same fragment-scoped feed without changing journey progress or starting location monitoring

#### Scenario: Request a locked node
- **WHEN** a traveler requests community content for a fragment that is still locked in the supplied owned journey
- **THEN** the system rejects the request without revealing whether community content exists

#### Scenario: Request another traveler's journey context
- **WHEN** a traveler supplies a journey not owned by that traveler
- **THEN** the system returns the existing not-found authorization behavior without revealing journey, fragment, or community metadata

### Requirement: Fragment-scoped traveler posts
An authorized traveler SHALL be able to publish a post bound to one unlocked fragment with a required category from `viewpoint`, `experience`, `fact_supplement`, or `on_site`, an optional short title and body within their runtime content limits, and up to the runtime media limit. A post MUST contain a non-blank title, non-blank body, or at least one accepted image. Responses SHALL label fact supplements as traveler-contributed and MUST NOT present any community post as official narration or verified historical content.

#### Scenario: Publish a text observation
- **WHEN** an authorized traveler submits a valid title or body, category, and a new idempotency key for an unlocked fragment
- **THEN** the system creates one visible post bound to that fragment and returns its title, body, author display, category, timestamps, counts, and viewer state

#### Scenario: Publish a photography post
- **WHEN** an authorized traveler submits one or more valid images within the configured limits
- **THEN** the system normalizes the media for safe community display, removes private capture metadata, preserves a viewable image, and associates ordered square-preview representations with the post

#### Scenario: Repeat a create request
- **WHEN** the same author repeats a post request with the same idempotency key after a timeout or retry
- **THEN** the system returns the original post without creating duplicate text, media, or feed entries

#### Scenario: Submit invalid content
- **WHEN** a post is blank, exceeds configured text or media limits, uses an unsupported category or media type, or contains an invalid image
- **THEN** the system rejects the complete post without leaving a visible partial post or orphaned community media

### Requirement: Explicit private-photo sharing boundary
Private journey evidence MUST remain private by default. Sharing an existing evidence photograph SHALL require an explicit confirmation naming the destination as 见地现场, SHALL verify that the evidence belongs to the current user and requested fragment, and SHALL create a distinct sanitized community-media object whose access and lifecycle do not depend on the private evidence object.

#### Scenario: Share a footprint photograph explicitly
- **WHEN** the owner selects a private photograph for its matching unlocked fragment and confirms 分享到见地现场
- **THEN** the system creates a separate community-media copy and publishes only that copy with the post

#### Scenario: Cancel the share confirmation
- **WHEN** the traveler selects a private photograph but cancels before confirming public community sharing
- **THEN** no post or community-media object is created and the private photograph remains unchanged

#### Scenario: Share evidence owned by another user or fragment
- **WHEN** a traveler references evidence that is not owned by that traveler or does not belong to the requested fragment
- **THEN** the system rejects the request without revealing the evidence metadata or copying its bytes

#### Scenario: Private source expires after sharing
- **WHEN** a private evidence source expires or is deleted after a community copy was successfully published
- **THEN** the community post keeps its independent image while the private evidence lifecycle continues normally

#### Scenario: Community post is deleted
- **WHEN** an author deletes a post created from a private evidence photograph
- **THEN** the community copy is removed according to community cleanup policy while the private source is not deleted or modified

### Requirement: Stable node-feed pagination and filtering
The fragment feed SHALL order visible posts newest first using a stable opaque cursor, SHALL support the declared category filters, SHALL enforce a maximum page size, and SHALL return a next cursor only when more visible posts are available. Each feed item SHALL be a summary projection containing the title or body excerpt, cover-media metadata when present, author display, category, like count, comment count, viewer like state and author state, but SHALL NOT require the complete liker or comment collections. Concurrent inserts, soft deletion, held content, and repeated page requests MUST NOT cause a post to appear twice in one cursor traversal.

#### Scenario: Load the first feed page
- **WHEN** an authorized traveler requests a fragment feed without a cursor
- **THEN** the system returns the newest visible post summaries with their cover, author display and aggregate interaction state, plus a next cursor when applicable

#### Scenario: Load a filtered next page
- **WHEN** the traveler supplies a valid cursor and one supported category
- **THEN** the system returns the next stable page for the same fragment and category without entries from other categories or fragments

#### Scenario: Supply an invalid cursor
- **WHEN** the traveler supplies a malformed, expired, or filter-incompatible cursor
- **THEN** the system returns a validation error and does not silently restart at the first page

### Requirement: Post detail, reactions, and one-level comments
An authorized traveler SHALL be able to load a visible post detail, like or unlike it, inspect a stable paginated list of travelers who liked it, load its stable paginated single-level comments, publish a single-level comment, and delete a comment they authored. The detail SHALL contain the complete available title, body and ordered media plus authoritative counts and viewer state. Like membership SHALL be unique per traveler and post; comment creation SHALL be idempotent per author and key; nested replies beyond one level SHALL be rejected. Liker and comment author projections MUST expose only the display name and default-avatar presentation required by the client, never raw user IDs, account kinds, login identifiers or other private account fields.

#### Scenario: Load a post detail
- **WHEN** an authorized traveler opens a visible post from an unlocked fragment feed
- **THEN** the system returns the complete post content, ordered media, authoritative counts, viewer state, and access to the scoped liker and comment collections

#### Scenario: Like and unlike a post
- **WHEN** an authorized traveler likes a visible post and later removes that like
- **THEN** the server records at most one membership, returns authoritative viewer state and count after each action, and leaves the post content unchanged

#### Scenario: Inspect travelers who liked a post
- **WHEN** an authorized traveler requests the liker collection with a valid cursor
- **THEN** the system returns one stable page of privacy-safe traveler presentations and a next cursor when more visible likers exist

#### Scenario: Add a comment
- **WHEN** an authorized traveler submits a valid one-level comment with a new idempotency key
- **THEN** the system creates one visible comment, updates the authoritative comment count, and returns the comment with its author display

#### Scenario: Repeat a comment request
- **WHEN** the same author repeats a comment request with the same idempotency key
- **THEN** the system returns the original comment without incrementing the count twice

#### Scenario: Attempt a nested reply
- **WHEN** a traveler submits a parent comment or nesting level beyond the supported single level
- **THEN** the system rejects the request without creating a comment

#### Scenario: Open detail after the post becomes unavailable
- **WHEN** a post is deleted, held, or hidden from the requesting reporter before its detail loads
- **THEN** the system returns the existing not-found behavior without exposing its previous content, likers, or comments

### Requirement: Author control, soft deletion, and reporting
Authors SHALL be able to delete their own posts and comments, and no traveler SHALL be able to delete another author's content. An authorized traveler SHALL be able to report a visible post or comment once per target using a supported reason. Reported content SHALL be hidden immediately from the reporter; when distinct reports reach the runtime hold threshold the content SHALL be excluded from all ordinary feeds while retained for operational review and audit.

#### Scenario: Author deletes a post
- **WHEN** the post author deletes their visible post
- **THEN** the post and its comments stop appearing in ordinary reads, counts converge without the post, and the deletion does not affect journey progress or private evidence

#### Scenario: Another traveler attempts deletion
- **WHEN** a traveler attempts to delete a post or comment authored by another user
- **THEN** the system rejects the action without changing the target

#### Scenario: Report visible content
- **WHEN** an authorized traveler reports a visible post or comment with a supported reason
- **THEN** one report is recorded, the target disappears for that reporter, and the author's journey or account data is not exposed

#### Scenario: Report threshold is reached
- **WHEN** a visible target receives the configured number of distinct valid reports
- **THEN** the system marks it held and excludes it from ordinary feeds and comment reads without physically deleting its audit record

### Requirement: Community failure isolation and runtime policy
The system SHALL expose authenticated runtime community policy including enabled state, supported categories, title/body/comment and media limits, report reasons, and user-facing retention notes. Community unavailability, policy disablement, upload failure, detail failure, or interaction failure MUST NOT stop narration, change a fragment state, discard journey progress, or prevent the traveler from using the official node experience.

#### Scenario: Community is disabled
- **WHEN** the runtime community policy is disabled
- **THEN** the client omits the composer and feed while official narration, photos, progression, and footprints continue to function

#### Scenario: Feed request fails during narration
- **WHEN** the community feed cannot load while node audio is playing
- **THEN** audio and journey progress continue and the community region offers an inline retry without replacing the node page

#### Scenario: Post detail fails during narration
- **WHEN** a selected post detail, liker page, or comment page cannot load while node audio is playing
- **THEN** the contextual detail presents a retry or unavailable state while audio, selected node and underlying feed scroll position remain unchanged

#### Scenario: Optimistic interaction fails
- **WHEN** a like, delete, or comment action is shown optimistically and the server rejects it
- **THEN** the client restores the last authoritative state and presents a localized retryable error without refreshing or stopping the audio experience
