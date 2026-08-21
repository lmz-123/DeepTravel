## Why

The current stop flow asks travelers to look at a place, read explanatory copy, and answer a quiz while holding the phone. It neither supports a natural hands-free walk nor gives the historical content enough narrative tension. The next MVP should behave like a location-aware audio guide: travelers can keep the phone in a pocket, hear rigorously sourced story fragments as they enter meaningful places, and occasionally take a photograph that becomes evidence in a final reconstructed story.

## What Changes

- Add an active-tour mode that explicitly requests location permission, monitors route geofences while the app is foregrounded, backgrounded, or the screen is locked, and automatically triggers each eligible story fragment once.
- Add a headset-first audio experience with automatic playback, lock-screen controls, pause/resume, replay, transcript, speed control, interruption handling, and a non-overlapping fragment queue.
- Replace isolated observation quizzes in the Shenzhen MVP route with a connected fragmented-history arc. Each fragment must contain a real historical claim, a field-visible clue, a source record, and a question that is answered or reframed by a later fragment.
- Add photo missions for selected fragments. A user photographs a specified field clue, uploads or safely retries the evidence, and unlocks the corresponding fragment without requiring computer-vision scoring in this MVP.
- Add a story ledger that shows collected and missing fragments and, after all required fragments are collected, asks the user to order or connect them into the route's causal historical chain before revealing the sourced complete story.
- Add historical-content governance so dates, claims, original/relocated/reconstructed status, fiction boundaries, citations, and editorial review state are stored and exposed by the backend. Unreviewed material remains visibly marked and cannot be treated as publication-ready history.
- Restore real location support for production tours while retaining explicit developer/demo triggering behind configuration for automated tests and non-production evaluation.
- **BREAKING**: Completing a stop is no longer universally gated by answering a multiple-choice question. Route content declares whether a fragment is passively heard, requires a photo mission, or participates in final reconstruction.

## Capabilities

### New Capabilities

- `location-aware-audio-guide`: Active-tour location monitoring, geofence trigger policy, background/locked-screen behavior, audio queueing, interruptions, and permission fallbacks.
- `fragmented-storytelling`: Sourced story fragments, cross-fragment dependencies, collection state, story ledger, and final causal reconstruction.
- `photo-missions`: Camera-led field tasks, evidence upload and retry, privacy controls, and fragment unlock behavior without mandatory visual recognition.
- `historical-content-integrity`: Source records, claim-level review state, original-versus-reconstructed labeling, fiction boundaries, and publication rules.

### Modified Capabilities

- `experience-client`: Change the guided loop from screen-first quiz interaction to a headset-first active tour with background audio, brief photo moments, and a resumable story ledger.
- `guided-journey`: Replace answer-gated progression with fragment trigger, evidence, collection, and reconstruction states while preserving guest journey resume semantics.
- `route-discovery`: Extend route detail with audio-tour readiness, trigger regions, fragment previews, mission metadata, and editorial/source status.
- `platform-runtime`: Add durable user-evidence storage, media limits, lifecycle configuration, and automated verification for location/audio state machines and uploads.

## Impact

- **Flutter client**: location permissions and background execution, audio session/player and lock-screen controls, camera/image handling, local journey persistence, trigger queue, active-tour UI, story ledger, reconstruction UI, and accessibility behavior.
- **Flask API**: fragment/catalog endpoints, location-trigger acknowledgement, multipart evidence upload, collection/reconstruction endpoints, idempotency, structured errors, and source metadata serialization.
- **Database**: new source, claim, fragment, trigger-region, mission, fragment-collection, evidence, and reconstruction records plus migration and seed reconciliation.
- **Media storage**: backend-hosted narration files and user-uploaded photographs with size/type validation and configurable retention. Local filesystem storage is acceptable for the MVP behind a storage interface that can later move to object storage.
- **Mobile platforms**: Android foreground-service notification and background-location declarations; iOS background-location/audio modes and clear purpose strings. Monitoring runs only during an explicitly started tour.
- **Content**: the Shenzhen Nantou route is rewritten around the documented historical arc of administrative establishment, center migration, Ming garrison construction, Xin'an county restoration, coastal evacuation, county-seat relocation, and contemporary reinterpretation. Every production claim requires a cited source and review status.

## Non-goals

- Turn-by-turn navigation, live route optimization, or continuous spoken directions between every trigger.
- Computer-vision judging of whether a photograph is objectively correct.
- Runtime generative-AI narration or unsourced generation of historical facts.
- Social feeds, competitive leaderboards, multiplayer play, or public display of traveler photographs.
- Full-city content coverage; this change proves the experience with one reviewed five-fragment Shenzhen route.
- App-store production signing, cloud object-storage migration, or a full editorial CMS in this iteration.

## MVP Validation Goals

- A traveler can start the Shenzhen tour, lock the screen, walk into five configured trigger regions, and hear each fragment once in deterministic order without audio overlap.
- Calls, navigation prompts, headphone disconnects, permission denial, inaccurate GPS, and app restart produce understandable pause/retry behavior without losing collected fragments.
- Required photo missions can be captured, retried after network failure, resumed after restart, and removed from the user's journey record.
- Collecting all required fragments unlocks an interactive reconstruction and a complete story that explains causal history rather than presenting five unrelated facts.
- Every production fragment exposes at least one source and an editorial state; reconstructed exhibits and fictional framing are explicitly labeled.
- Automated tests cover trigger hysteresis/deduplication, audio queue transitions, evidence idempotency, journey resume, final reconstruction gating, and source-publication rules without paid services.
