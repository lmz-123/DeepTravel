## Purpose

为每个已认证旅行者提供统一、私密且可恢复的账号导航与旅程资料库，使进行中和已完成路线在换页、重启及重新登录后仍可继续或回顾。

## ADDED Requirements

### Requirement: Account drawer navigation
The client SHALL open a left-side account drawer when the traveler activates the home-page 见地 brand mark. The drawer MUST show the existing default avatar, current username, and entries for 足迹, 设置, and 退出登录, and the home header MUST NOT retain a separate account avatar beside the city selector.

#### Scenario: Open the account drawer
- **WHEN** an authenticated traveler taps the 见地 brand mark on the discovery page
- **THEN** a left-side drawer opens with the traveler identity and all required menu entries

#### Scenario: Log out from the drawer
- **WHEN** the traveler confirms 退出登录
- **THEN** active playback and location monitoring stop, user-scoped local private state is cleared, server-owned journeys and evidence remain intact, and the client returns to authentication

#### Scenario: Switch a configured test account
- **WHEN** a test-auth-enabled build switches accounts from the drawer
- **THEN** the client clears the previous account's private presentation state and loads only the new account's journeys, settings, and evidence

### Requirement: User-owned journey library
The system SHALL provide an authenticated journey collection for the current user that includes active and completed journeys with route summary, status, progress, start/update/completion timestamps, and evidence count. The collection MUST remain readable for the owner when a route is later archived and MUST reveal no journey metadata to another user.

#### Scenario: Read active and completed journeys
- **WHEN** an authenticated user requests their journey collection
- **THEN** the response contains only journeys owned by that user, ordered by most recent activity with stable route and progress metadata

#### Scenario: View an archived completed footprint
- **WHEN** a completed journey's route is archived after completion
- **THEN** its owner can still see the route snapshot and open the footprint from the library

#### Scenario: Another user requests private journey data
- **WHEN** a different authenticated user requests a journey, ledger, recap, or evidence from the collection
- **THEN** the system returns the existing not-found authorization behavior without revealing metadata

### Requirement: Footprint history and detail
The client SHALL present completed journeys under 足迹 as route cards with cover, title, completion time, route metrics, collected clue count, and private photo count, and SHALL provide a detail view that can open the completed recap, unlocked clues, and available photographs.

#### Scenario: Completed history is shown after a new login
- **WHEN** the same user completes a route, restarts the client, and logs in again
- **THEN** the completed route appears in 足迹 with its persisted server progress and available private media

#### Scenario: No completed journeys exist
- **WHEN** the user opens 足迹 without a completed journey
- **THEN** the client shows a neutral empty state with an action back to route discovery

#### Scenario: One footprint fails to load
- **WHEN** route or evidence metadata for a footprint is temporarily unavailable
- **THEN** the client preserves the rest of the list and shows a retryable error for the affected content

### Requirement: Completed route revisit
When a user starts a route with no active journey but an existing completed journey, the system SHALL return the most recently completed owned journey for revisit instead of creating a new locked journey. Revisit MUST preserve all collected or answered content as unlocked and MUST NOT start location monitoring automatically.

#### Scenario: Reopen a completed fragmented route
- **WHEN** a user selects a route they previously completed
- **THEN** the client opens the completed journey in revisit mode with every collected clue available for replay and with no first-time headphone start gate

#### Scenario: Reopen a completed legacy route
- **WHEN** a user selects a completed legacy answer route
- **THEN** the client opens its completed recap without resetting answers or creating a new journey

#### Scenario: Active and completed records both exist
- **WHEN** a user selects a route with both an active journey and an older completed journey
- **THEN** the active journey is resumed and the completed record remains accessible from 足迹

### Requirement: Useful user-scoped settings
The client SHALL provide user-scoped local settings for default playback speed, real or simulated location mode, offline audio download policy, audio cache clearing, photo privacy and retention information, and app version information. Clearing local audio cache MUST NOT delete server journey progress or evidence.

#### Scenario: Settings remain isolated by account
- **WHEN** two configured test users choose different playback, location, or download preferences on the same device
- **THEN** each user sees only their own saved preference values after switching accounts

#### Scenario: Clear downloaded audio
- **WHEN** the traveler clears the offline audio cache from 设置
- **THEN** prepared audio files and their cache index are removed while journeys, footprints, photos, and login state remain intact

#### Scenario: Open privacy information
- **WHEN** the traveler opens the photo privacy setting
- **THEN** the client explains private access, metadata removal, configured retention, and the effect of expiry without implying public sharing
