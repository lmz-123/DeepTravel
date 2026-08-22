## Purpose

让用户从首页随手发现并完整收听经过后台编辑审核的城市故事，同时与行走导览共享可靠、互斥且可恢复的音频体验。

## ADDED Requirements

### Requirement: Curated home story publication
The admin system SHALL let an editor configure a story title, introduction, cover, city, selection weight, complete transcript, narration profile, audio metadata, review state, and home-listening publication state. A story MUST enter the home random pool only when its editorial fields and complete audio are present, its transcript and audio provenance match, and it has been explicitly approved and published for home listening.

#### Scenario: Publish a complete story
- **WHEN** an editor approves a story whose required metadata, transcript, reviewed narration track, and public media are complete
- **THEN** the story becomes eligible for home random selection with no provider voice identifier or storage credential exposed to clients

#### Scenario: Transcript changes after audio approval
- **WHEN** an editor changes a published story transcript
- **THEN** the existing audio becomes stale and the story leaves the random pool until matching audio is reviewed and republished

#### Scenario: Route story is not opted in
- **WHEN** a route has a complete reconstruction story but is not explicitly published for home listening
- **THEN** the complete story and its audio do not appear in the home random pool

### Requirement: Random story discovery
The public API SHALL return one weighted-random published story for the requested published city and MAY accept the previously returned story as an exclusion hint. The response SHALL include stable story, city and route identities, title, introduction, cover, duration, complete transcript, public audio reference, and narration-profile display metadata.

#### Scenario: Request a random story for the selected city
- **WHEN** the home client requests a random story for a city with eligible published stories
- **THEN** the API returns one complete playable story from that city's configured pool

#### Scenario: Avoid immediate repetition
- **WHEN** at least two eligible stories exist and the client supplies the previously played story as an exclusion hint
- **THEN** the API selects from the remaining eligible stories

#### Scenario: Empty city pool
- **WHEN** no eligible published story exists for the requested city
- **THEN** the API returns a structured empty-pool result and the client shows a gentle unavailable state without substituting unpublished content

### Requirement: Complete story listening page
Tapping “听一个短故事” SHALL request a story for the currently selected city and open a dedicated listening page that presents its title, introduction, cover, city and route context, complete transcript alternative, duration, elapsed time, progress, play/pause, seek, replay, loading, ended, and recoverable error states.

#### Scenario: Start from home
- **WHEN** a traveler taps the home story action and a story is available
- **THEN** the client opens the listening page and makes the complete story ready to play without creating or changing a journey

#### Scenario: Playback finishes
- **WHEN** the story audio reaches its end
- **THEN** the player shows an ended state with replay and request-another-story actions rather than pretending audio is still playing

#### Scenario: Story media fails
- **WHEN** story metadata loads but audio preparation or streaming fails
- **THEN** the page preserves the title and introduction, exposes retry, and does not alter route or journey progress

### Requirement: Single active audio ownership
The client SHALL permit only one active audio owner across home stories and route narration. Starting one source MUST stop and release the other source, update its visible state, and make the draggable home overlay navigate to the currently active audio context.

#### Scenario: Start a home story during route narration
- **WHEN** a traveler explicitly starts a home story while route narration is playing
- **THEN** route narration stops before story audio begins and the overlay opens the story listening page

#### Scenario: Start route narration during a home story
- **WHEN** route narration starts while a home story is playing
- **THEN** the home story stops before route audio begins and the overlay opens the active journey progress page

#### Scenario: Leave the story page
- **WHEN** a traveler leaves the story listening page while its audio continues
- **THEN** the existing draggable rotating audio overlay represents that story and returns to its listening page when tapped
