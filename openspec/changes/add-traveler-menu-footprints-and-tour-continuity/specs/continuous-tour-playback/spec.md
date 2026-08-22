## Purpose

让定位音频在页面切换、路线恢复和历史节点重听时保持单一、可见且可控制的播放会话，同时确保播放选择不会破坏服务端旅程进度。

## ADDED Requirements

### Requirement: Home-page rotating playback orb
While a tour narration is loaded and the tour has not been stopped, the discovery page SHALL show a vinyl-style circular playback orb whose default position is at the right safe edge. The traveler SHALL be able to drag it freely within the discovery page's safe movable region and leave it at the released position. The client SHALL persist normalized orb coordinates locally per account, restore and clamp them after relaunch or layout changes, and distinguish a drag from a tap so repositioning does not open the journey. The visible orb SHALL be 56–64 logical pixels in diameter with a touch target of at least 72 logical pixels, use server-provided route artwork or a neutral brand fallback at its center, and show playback progress in its outer ring. It SHALL rotate only while audio is playing, remain visually still while paused, and avoid continuous rotation when reduced motion is requested. Activating the orb SHALL navigate directly to the owning journey and selected clue. The client MUST NOT replace this orb with a horizontal mini-player bar or crowd it with route text and playback controls.

#### Scenario: Return home during playback
- **WHEN** the traveler leaves the journey page while narration is playing
- **THEN** playback continues and the discovery page shows the orb at the account's saved valid position, rotating with live progress

#### Scenario: Open the active journey from the playback orb
- **WHEN** the traveler taps the playback orb
- **THEN** the client opens the exact journey and currently selected clue without starting a new session

#### Scenario: Reposition the playback orb
- **WHEN** the traveler drags the orb to another valid point on the discovery page and releases it
- **THEN** the orb follows the pointer, remains at the released point without opening the journey, and the normalized position is restored for that account on the next discovery visit

#### Scenario: Layout bounds change
- **WHEN** orientation, window size, safe-area insets, or fixed navigation bounds change after a position was saved
- **THEN** the client clamps the restored orb fully inside the new movable region instead of leaving it clipped or unreachable

#### Scenario: Narration is paused on the home page
- **WHEN** the loaded narration becomes paused while the discovery page is visible
- **THEN** the orb stops rotating, preserves its progress ring, exposes a paused state to assistive technology, and remains tappable to return to the journey

#### Scenario: Reduced motion is requested
- **WHEN** the operating system or application requests reduced motion while narration is playing
- **THEN** the discovery page shows a static orb with progress and playing state without continuous rotation

#### Scenario: Home page has nearby primary controls
- **WHEN** the playback orb is visible on a supported phone layout
- **THEN** its default and restored positions respect the safe area, fixed header and navigation controls, and system gesture region while the traveler may move it across ordinary scrollable content

#### Scenario: Tour is explicitly stopped
- **WHEN** the traveler stops the tour or logs out
- **THEN** playback stops and the playback orb is removed from the discovery page

### Requirement: Single-owner cross-attraction audio handoff
The client SHALL maintain one global scenic narration player and one current playback owner identified by account, route, journey, and clue. Before audio belonging to a different route starts from any page, the client SHALL stop the current audio, cancel its pending autoplay and completion callbacks, stop the previous route's location monitoring, and then transfer ownership to the requested route. This handoff MUST preserve the previous journey's persisted server progress and MUST NOT allow audio or callbacks from both routes to overlap.

#### Scenario: Start another attraction from a different page
- **WHEN** audio for route B is requested while route A narration is playing or paused
- **THEN** route A audio and monitoring stop before route B is loaded, route B becomes the only playback owner, and the home-page orb subsequently represents route B

#### Scenario: Previous route callback arrives after replacement
- **WHEN** an audio completion, position, or queued-trigger callback from route A arrives after route B has taken ownership
- **THEN** the client rejects the stale callback and does not mutate either journey or interrupt route B

#### Scenario: Replacement audio fails to load
- **WHEN** route A has been stopped and route B cannot be loaded
- **THEN** route A remains stopped, its server progress remains recoverable, no overlapping playback resumes automatically, and the client presents a retryable route-B error

### Requirement: Direct active-route resume
The client SHALL identify user-owned active journeys when rendering route discovery. Selecting the same route SHALL open its current progress directly and MUST NOT show the first-time “戴上耳机，开始行走” gate.

#### Scenario: Select an active scenic route
- **WHEN** the traveler taps a discovery card whose route has an active journey
- **THEN** the client resumes that journey at its persisted ledger and playback selection

#### Scenario: Select a route without a journey
- **WHEN** the traveler taps a route with neither an active nor completed journey
- **THEN** the normal route detail and first-time start flow remains available

### Requirement: Replay collected clues
The client SHALL expose every revealed collected clue as an accessible, selectable node. Selecting one SHALL stop the currently loaded audio, load and optionally play the selected narration, and preserve the server-side collection count, dependency graph, active progression cursor, and evidence state.

#### Scenario: Select a green collected node
- **WHEN** the traveler taps a green node for a previously collected clue
- **THEN** current audio stops and the selected clue becomes the visible playable narration

#### Scenario: Replay finishes
- **WHEN** a replayed collected clue reaches its end
- **THEN** the client does not create a new collection event, unlock a duplicate clue, or overwrite the journey's active progression cursor

#### Scenario: Tap a locked node
- **WHEN** the traveler taps an undiscovered locked node
- **THEN** the client does not switch playback and communicates that the clue must first be found

### Requirement: Simulated next-clue audio handoff
In simulated location mode, activating 下一条线索 SHALL stop the current narration, idempotently acknowledge its completion when needed, refresh the ledger, and trigger the next eligible clue. Photo absence MUST NOT block this test progression. Real-location mode SHALL continue to require a valid location trigger for the next clue.

#### Scenario: Advance while current simulated narration is playing
- **WHEN** the tester taps 下一条线索 before the current narration naturally ends
- **THEN** the client stops that audio, records one completion acknowledgement, and begins the next eligible node flow

#### Scenario: Advance without taking the optional photo
- **WHEN** the current narration is complete, its optional photo has not been uploaded, and the tester taps 下一条线索
- **THEN** the next eligible clue is triggered without a photo-related conflict

#### Scenario: No next clue is eligible
- **WHEN** the tester taps 下一条线索 after all clues are collected or while a non-photo dependency remains unsatisfied
- **THEN** the client keeps the current progress and explains the actual blocking state without replaying an old narration

### Requirement: Completed replay mode avoids live monitoring
The client SHALL load a completed fragmented journey for replay without registering an active tour, starting location monitoring, or changing its completed status.

#### Scenario: Play audio from a completed footprint
- **WHEN** the traveler opens an unlocked clue from a completed footprint and presses play
- **THEN** the narration plays with normal seek, speed, transcript, background behavior, and the home-page playback orb while location monitoring remains off
