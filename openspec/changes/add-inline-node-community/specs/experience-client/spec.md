## ADDED Requirements

### Requirement: Inline node community placement
The client SHALL render 见地现场 as the final inline section of the currently selected revealed or collected fragment after official narration, transcript, photo guidance and keepsakes, journey progression or reconstruction controls, and recoverable journey messages. The section MUST remain on the same scrollable page, MUST NOT require a separate community route, and SHALL update using the selected fragment rather than an unrelated live-progress fragment.

#### Scenario: Open community beneath the current node
- **WHEN** the traveler selects a revealed or collected node and scrolls past all official node and progression content
- **THEN** the page ends with the 见地现场 composer, filters, fragment-scoped summary cards, and pagination controls for that selected node

#### Scenario: Switch to another collected node
- **WHEN** the traveler selects a different collected green node
- **THEN** the official node content and bottom community region both switch to that fragment, stale responses from the previous fragment are ignored, and no post from the previous fragment is shown under the new selection

#### Scenario: Community is loading or unavailable
- **WHEN** the bottom community region is loading, empty, disabled, or fails to load
- **THEN** it displays an appropriate compact inline state without covering or disabling official node controls

#### Scenario: Read community while narration plays
- **WHEN** the traveler scrolls, filters posts, opens a post detail, publishes content, or views a community image while narration is playing
- **THEN** the existing narration continues and its global playback ownership and progress remain unchanged

### Requirement: Community access from completed footprints
The footprint detail SHALL allow the traveler to select any collected fragment in the completed journey, inspect their available private photographs, and browse or contribute to that fragment's same 见地现场 feed at the bottom of the detail content. Opening community content from a footprint MUST NOT start location monitoring, mutate completed progress, or create a new journey.

#### Scenario: Select a node in a footprint
- **WHEN** the traveler opens a completed footprint and selects one of its collected nodes
- **THEN** the detail shows that node's recap and available private keepsakes followed by the matching 见地现场 section

#### Scenario: Share a footprint photo
- **WHEN** the traveler chooses one of their private footprint photographs from the selected node for a new post
- **THEN** the client explains that a separate copy will be visible to other eligible travelers and requires explicit confirmation before publishing

#### Scenario: Revisit an archived route footprint
- **WHEN** the route has been archived but the traveler retains a completed owned journey
- **THEN** collected-node community remains accessible under the same ownership and unlock rules while the route remains absent from normal discovery

### Requirement: No global community entry
The client MUST NOT add a 动态 or 见地现场 destination to the discovery page, home-page brand drawer, city selector, primary route cards, or global navigation. The required first-version discovery path SHALL be selecting a node in an active journey or completed footprint and scrolling to that node's final inline section.

#### Scenario: Inspect the home drawer
- **WHEN** the traveler opens the 见地 drawer from discovery
- **THEN** the drawer continues to contain identity, 足迹, 设置, and 退出登录 without a community destination

#### Scenario: Inspect route discovery
- **WHEN** the traveler browses cities and route cards without opening a journey or footprint node
- **THEN** no community badge, feed, tab, floating control, or independent community route is presented

### Requirement: Beautiful community summary cards and contextual detail
The node feed SHALL present every post as a polished tappable card. A post with media SHALL use a prominent near-square cover or compact near-square grid with its optional title and body excerpt; a text-only post SHALL use a restrained paper-like typographic surface with its title or excerpt as the visual focus. Every card SHALL show author display, category, relative time, like count and comment count in a consistent footer. Activating the card SHALL open a near-full-height contextual detail surface containing the complete title, text and media, the privacy-safe travelers who liked it, the complete paginated one-level comments and relevant author/report actions, without creating a global community destination.

#### Scenario: Render an image post card
- **WHEN** a visible post contains one or more images
- **THEN** the feed card presents a consistent near-square image composition, title or concise excerpt, and a footer with like and comment counts without expanding the full discussion in the feed

#### Scenario: Render a text-only post card
- **WHEN** a visible post contains no image
- **THEN** the feed card uses a readable text-led paper treatment with a bounded excerpt and the same author, category, time, like and comment footer hierarchy

#### Scenario: Open a post detail
- **WHEN** the traveler activates a summary card or its comment count
- **THEN** a near-full-height detail surface opens in the selected node context and shows full media/text, liker presentations and comments while preserving underlying node state, feed scroll position and narration

#### Scenario: Close a post detail
- **WHEN** the traveler closes or dismisses the detail surface
- **THEN** the client returns to the same node feed position and refreshed authoritative card counts without navigating to a separate community page

### Requirement: Voice selection inside the narration card
The client SHALL remove standalone narration-voice cards from route detail and journey content and SHALL expose the server-driven route voice profiles through a compact voice icon inside the active narration playback card. The icon SHALL communicate the current voice and selection action accessibly. When more than one published profile is available, activating it SHALL open a lightweight voice picker; when only one profile exists, the client MUST NOT present a misleading selection action. A successful change SHALL keep the selected fragment and preserve the previous playing or paused intent while replacing the narration with the selected profile at the nearest valid proportional position, without acknowledging fragment completion merely because of the switch.

#### Scenario: Open the voice picker from playback
- **WHEN** the current route has multiple published narration profiles and the traveler activates the voice icon in the narration card
- **THEN** the client presents the available server-provided profiles, marks the current choice and does not show a separate voice card elsewhere on route detail or the journey page

#### Scenario: Change voice while playing
- **WHEN** the traveler selects another available profile while narration is playing
- **THEN** the current track stops, the same fragment loads in the selected profile near the same proportional progress, playback resumes, and no duplicate completion or cross-route audio is produced

#### Scenario: Change voice while paused
- **WHEN** the traveler selects another available profile while narration is paused
- **THEN** the same fragment loads in the selected profile near the same proportional progress and remains paused until the traveler resumes

#### Scenario: Voice replacement fails
- **WHEN** preparation or loading of the selected profile fails
- **THEN** the client keeps or restores the last playable profile and state, reports a recoverable inline error, and does not reset journey progress

### Requirement: Settings is the single location-mode control
The client SHALL keep the user-scoped real/simulated location switch in 设置 as the single editable location-mode control and MUST remove duplicate switches from route detail and the journey status card. Route detail and journey status MAY describe the active mode, and simulated mode SHALL retain its test-only 下一条线索 action, but those surfaces MUST NOT mutate the mode. A settings change SHALL synchronize with an existing active tour when the traveler returns to it, stopping obsolete location monitoring before applying the new mode.

#### Scenario: Inspect route and journey surfaces
- **WHEN** the traveler opens route detail or an active journey
- **THEN** the client shows no simulated-location switch there while still communicating the current real or simulated behavior

#### Scenario: Enable simulation from settings
- **WHEN** the traveler enables simulated location in 设置 and returns to an active journey
- **THEN** real location monitoring is stopped, the journey enters simulated mode, and the test-only next-clue control is available

#### Scenario: Restore real location from settings
- **WHEN** the traveler selects real location in 设置 and returns to an active non-revisit journey
- **THEN** simulated behavior stops and the client requests or resumes valid real-location monitoring according to the existing permission rules

#### Scenario: Revisit a completed footprint
- **WHEN** a completed journey is opened for replay after the setting changes
- **THEN** replay remains free of location monitoring and exposes no mode switch regardless of the stored setting

### Requirement: Accessible community presentation
Community controls, category filters, summary cards, post details, post media, like state, liker lists, comments, author actions, report confirmation, pagination, and publishing state SHALL expose semantic labels, selected states, minimum touch targets, readable contrast, text alternatives, and reduced motion behavior. Media previews SHALL use a consistent near-square crop without destroying the viewable source and SHALL open an accessible full-image viewer.

#### Scenario: Navigate a post with assistive technology
- **WHEN** a screen-reader traveler focuses a community post
- **THEN** the client announces the category, author display, relative publication time, title or excerpt, media count, like state, comment count, and the action to open full details without relying on color alone

#### Scenario: View differently shaped photographs
- **WHEN** posts contain portrait, landscape, or square images
- **THEN** their grid uses consistent near-square cover previews and opening a preview reveals the complete available image with zoom and a close action

#### Scenario: Reduced motion is enabled
- **WHEN** the operating system requests reduced motion
- **THEN** community insertion, like, filter, composer, and image-viewer transitions avoid decorative motion while keeping state changes understandable
