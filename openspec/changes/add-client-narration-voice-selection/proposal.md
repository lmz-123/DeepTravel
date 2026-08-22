## Why

Travelers currently receive one editor-selected narration track even though listening preference is personal, and the registration username field can restore deleted suffix text on the next keystroke. Both behaviors remove user control at the first and most frequently heard parts of the product.

## What Changes

- Publish multiple approved narration voice tracks for one unchanged fragment transcript while retaining one backward-compatible default track.
- Return only voice profiles that have a complete published track set for the selected route, so a route never changes voice unexpectedly halfway through.
- Add a client-facing narration voice selector, preview metadata, per-account local preference, and deterministic fallback when a preferred voice is unavailable.
- Make playback, download preparation, cache identity, background audio, transcript display, and resume state use the selected published track without invoking runtime TTS.
- Extend the independent admin approval workflow so approved previews are associated with a stable public voice profile instead of replacing the only fragment audio.
- Correct registration username editing so deletion is authoritative; the sequence `liser → lis → listt` must never restore `er`.
- Deliver only a production-profile APK with normal registration/login and no test-account UI.

## Capabilities

### New Capabilities

- `user-selectable-narration`: Published voice profiles, complete per-route voice coverage, client selection, persistence, playback resolution, and fallback behavior.

### Modified Capabilities

- `experience-client`: Registration text editing must preserve the exact user edit sequence and the travel UI must expose the active narration voice without disrupting audio-first use.
- `route-discovery`: Complete route payloads expose backend-configured published voice profiles and per-fragment tracks rather than client constants.

## Impact

- Flask public serializers and journey ledger payloads gain backward-compatible narration profile/track fields.
- Shared MySQL content schema gains public voice-profile and approved fragment-track records; existing `audio_path` remains the default for older clients.
- `DeepTravel-admin` gains voice-profile-aware preview generation, approval, completeness validation, and publication controls.
- Flutter gains a voice preference repository/provider, selection UI, selected-track playback/cache behavior, and a deterministic username edit fix with regression coverage.
- Existing published routes require an idempotent backfill that registers their current narration as the default profile.

## Non-goals

- Generating TTS on the phone or calling a paid TTS provider during a journey.
- Letting a traveler create arbitrary voice IDs, clone a real person, or publish editorial audio.
- Changing transcript wording, historical claims, trigger progression, photo missions, or reconstruction rules by voice.
- Synchronizing the voice preference across devices in this MVP; it is retained locally per authenticated account.

## MVP Validation Goals

- A traveler can choose a backend-returned voice before or during a route, restart the app, and continue with that voice for the same account.
- Every selectable route voice has one approved current-transcript track for every narrated fragment; incomplete profiles remain hidden from travelers.
- Old clients continue to play the route's default `audio_url`, while the new client selects matching profile URLs and falls back visibly to the default when needed.
- Admin approval of one voice does not overwrite another voice's object, metadata, or default track.
- A widget/integration regression reproduces deleting `er` from `liser` and then typing `tt`, asserting the submitted username is exactly `listt`.
- Flutter, backend, admin, migration, and production APK checks run without paid TTS credentials.
