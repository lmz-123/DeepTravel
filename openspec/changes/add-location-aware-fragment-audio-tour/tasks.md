## 1. Historical content and publication data

- [x] 1.1 Convert the Nantou source dossier and timeline into claim-level reviewed seed records, recording certainty, source support, fact/inference boundaries, and whole-arc validation tests.
- [x] 1.2 Audit or explicitly leave in-review every trigger coordinate, quiet listening point, photo subject, and original/reconstructed/interpretive field label; prevent publication while required audit data is missing.
- [x] 1.3 Finalize the five fragment scripts, dependencies, central question, causal reconstruction model, complete story, pronunciation notes, and concise source summaries; verify that each fragment answers and raises a substantive historical question.
- [x] 1.4 Produce versioned preview narration and transcripts from the same reviewed script manifest, register all audio/media metadata, and add validation that missing or mismatched assets block production-ready state.

## 2. Backend schema and domain rules

- [x] 2.1 Add additive migrations and persistence models for historical sources/claims, story arcs/fragments/dependencies, trigger regions, photo missions, journey fragments, private evidence, reconstructions, and idempotency records; verify migration on fresh and existing MySQL data.
- [x] 2.2 Add historical-content domain and application services for source traceability, authenticity labels, review transitions, correction/supersession, and publication gates with focused unit tests.
- [x] 2.3 Add fragmented-journey domain rules for trigger, playback, mission-pending, collection, dependency eligibility, and final reconstruction while keeping legacy journeys readable; cover state transitions and retries with unit tests.
- [x] 2.4 Refactor seed reconciliation to insert/update the in-review Nantou audio-fragment route without duplicating records or replacing existing journey-compatible content; add idempotency tests.

## 3. Backend APIs and private evidence

- [x] 3.1 Extend route summaries/details and authenticated fragment reveal serialization with readiness, safe previews, trigger policy, audio manifests, missions, dependencies, source summaries, and spoiler boundaries; add contract tests.
- [x] 3.2 Implement active-tour and fragment-trigger endpoints with server proximity verification, accuracy handling, demo gating, raw-coordinate non-retention, and stable idempotent responses; add near/far/inaccurate/duplicate tests.
- [x] 3.3 Implement playback completion, ledger, fragment collection, reconstruction, and sourced recap endpoints with authorization and state-conflict tests.
- [x] 3.4 Implement the private `EvidenceStorage` port and local-volume adapter with atomic writes, image decoding/normalization, EXIF removal, configured limits/retention, and storage-failure tests.
- [x] 3.5 Implement journey-scoped evidence upload/read/delete APIs with MIME validation, ownership checks, idempotent retries, mission-state rollback after deletion, and cross-guest authorization tests.
- [x] 3.6 Add evidence-volume and narration-asset health checks plus Docker configuration that keeps private uploads outside public media paths; verify persistence across API container recreation.

## 4. Flutter persistence and service adapters

- [x] 4.1 Add maintained compatible location, background audio/session, camera, permissions, and SQLite dependencies behind domain-facing ports; configure Android/iOS permissions, background modes, and user-facing purpose strings.
- [x] 4.2 Implement guest/session persistence, prepared-route manifests, active-tour snapshots, fragment snapshots, narration queue identity, pending evidence references, and an idempotent local outbox; add restart and reconciliation tests.
- [x] 4.3 Extend API repository models and requests for fragmented routes, active-tour state, triggers, playback, evidence, ledger, reconstruction, and recap while preserving legacy route parsing; add repository tests.
- [x] 4.4 Implement prepared-route download/version verification for audio, transcripts, source summaries, and mission metadata with offline and missing-asset tests.

## 5. Location-aware audio engine

- [x] 5.1 Implement a pure trigger engine for accuracy filtering, consecutive samples, entry/exit hysteresis, dependency eligibility, cooldown, and once-per-fragment acknowledgement; drive it with deterministic synthetic-location tests.
- [x] 5.2 Implement the active-tour controller and platform location adapter for monitoring, pause/stop, stale-sample detection, Android foreground notification, iOS background behavior, and configured demo triggers; test permission and lifecycle transitions.
- [x] 5.3 Implement the single narration queue and audio-session adapter with prepared-file preference, pause/resume/seek/replay/speed, lock-screen controls, transcript fallback, interruption handling, and headset-disconnect pause; add coordinator tests.
- [x] 5.4 Integrate offline trigger/playback with the outbox so queued acknowledgements reconcile without duplicate collection or surprise replay after reconnect; test process death at each state boundary.
- [x] 5.5 Add a persisted real/simulated location-mode controller for demo-enabled builds; default to real, skip permission and real monitoring in simulation, support safe runtime switching, clearly label simulation, and test persistence plus both lifecycle paths.

## 6. Headset-first Flutter experience

- [x] 6.1 Build the route readiness and tour-setup flow with download size, central question, review/fiction disclosure, permission education, headset guidance, and three-tap-compatible start behavior; add widget tests.
- [x] 6.2 Build a restrained active-tour screen and system-control state showing monitoring health, current/queued narration, location limitations, pause/stop, transcript, and remaining fragment count; test reduced-motion and accessibility semantics.
- [x] 6.3 Build photo mission capture/review/postpone/retry/delete flows with safe prompts, pending-upload states, private evidence display, and camera-denial behavior; add widget and controller tests.
- [x] 6.4 Build the spoiler-safe story ledger with collected, mission-pending, nearby-locked, and undiscovered states plus source/authenticity details; add state rendering tests.
- [x] 6.5 Build the causal reconstruction interaction, targeted correction feedback, sourced complete-story recap, and traveler-photo composition; add gating and success-path widget tests.
- [x] 6.6 Add resume and failure UX for app restart, background suspension, inaccurate GPS, API loss, unavailable audio, unsupported interaction versions, and demo/in-review labeling; add focused recovery tests.

## 7. Verification and delivery preparation

- [x] 7.1 Run backend lint/tests, Flutter format/analyze/tests, migration checks, strict OpenSpec validation, and a Docker API/media/evidence smoke test; fix all regressions in legacy Shanghai and Shenzhen flows.
- [ ] 7.2 Execute the documented Android/iOS device matrix for locked screen, foreground/background transitions, calls, navigation prompts, headset disconnect, poor GPS, offline mode, process termination, and photo retry; record unsupported platform behavior honestly.
- [x] 7.3 Update deployment and privacy documentation for background location, notification, camera, private evidence volume, retention, feature flags, demo triggering, and rollback without deleting MySQL or evidence volumes.
- [ ] 7.4 Build an API-mode Android review APK against the configured backend and verify the complete five-fragment journey using synthetic triggers plus at least one real-location field pass before promoting the route beyond in-review state.
