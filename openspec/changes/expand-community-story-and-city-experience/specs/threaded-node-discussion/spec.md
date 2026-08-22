## Purpose

让旅行者在具体节点动态下形成清晰、可持续的两层对话，同时保持节点访问权限、隐私、审核与稳定分页边界。

## ADDED Requirements

### Requirement: Two-level comment threads
An authorized traveler SHALL be able to publish a top-level comment, reply to a top-level comment, or reply to another visible reply in the same thread. Every reply MUST identify the top-level thread and the exact visible comment being answered, and the presentation MUST remain at no more than two visual levels regardless of reply target.

#### Scenario: Reply to a top-level comment
- **WHEN** an authorized traveler replies to a visible top-level comment on an accessible node post
- **THEN** the reply is created under that top-level thread and identifies the top-level author as its reply target

#### Scenario: Reply to an existing reply
- **WHEN** an authorized traveler replies to a visible second-level reply
- **THEN** the new reply remains at the second visual level under the same root and identifies the selected reply author as its target

#### Scenario: Cross-post reply target
- **WHEN** a traveler submits a reply target belonging to another post or an inaccessible comment
- **THEN** the system rejects the request without revealing target content or creating a comment

#### Scenario: Repeated reply request
- **WHEN** the same author repeats a reply request with the same idempotency key
- **THEN** the system returns the original reply without increasing thread or post counts twice

### Requirement: Thread pagination and visible counts
The system SHALL paginate top-level comments independently from replies, SHALL return a bounded reply preview and authoritative visible reply count for each root, and SHALL provide stable pagination for the remaining replies. The post comment count MUST include every visible top-level comment and reply that the viewer is authorized to see.

#### Scenario: Load comment detail
- **WHEN** a traveler opens a post with more comments and replies than one page can contain
- **THEN** the client shows a stable page of roots, bounded reply previews, visible reply counts, and explicit controls for loading remaining roots or replies

#### Scenario: Concurrent reply insert
- **WHEN** another traveler adds a reply while the viewer traverses a reply cursor
- **THEN** the cursor traversal does not show an existing reply twice and a refresh converges to the new authoritative count

#### Scenario: Hidden reply
- **WHEN** a reply is deleted, held, or hidden from the current reporter
- **THEN** it is excluded from that viewer's visible reply and post counts without changing journey progress

### Requirement: Reply composer clarity
The client SHALL make reply mode explicit by naming the selected recipient beside the composer, SHALL let the traveler cancel reply mode without losing typed text, and SHALL return to ordinary top-level commenting after a successful reply or an explicit cancel.

#### Scenario: Enter reply mode
- **WHEN** a traveler taps Reply on a visible comment
- **THEN** the composer is focused with a clear “回复 <昵称>” context and the submitted comment is associated with that selected target

#### Scenario: Cancel reply mode
- **WHEN** a traveler cancels reply mode after typing text
- **THEN** the draft remains available as a top-level comment draft and no reply is submitted

### Requirement: Thread-aware deletion and moderation
Comment author deletion and reporting SHALL apply to the selected comment only. When a root comment becomes unavailable while visible replies remain, the thread SHALL retain a non-interactive tombstone in place of the root content so that replies do not lose their conversational grouping; unavailable replies SHALL not expose their previous text or author details.

#### Scenario: Delete a root with replies
- **WHEN** a root author deletes their comment after visible replies exist
- **THEN** the root content becomes a neutral deleted tombstone and the remaining visible replies stay grouped beneath it

#### Scenario: Delete a reply
- **WHEN** a reply author deletes their own reply
- **THEN** only that reply disappears or becomes the minimum required tombstone and other comments remain readable

#### Scenario: Report a reply
- **WHEN** a traveler reports a visible reply with a supported reason
- **THEN** existing per-reporter hiding and hold-threshold rules apply to that reply without hiding unrelated replies
