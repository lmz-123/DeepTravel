## Context

See `proposal.md` for motivation and the delta specs for observable behavior. Published fragments currently store one `audio_path`; the independent admin can generate three previews but approval promotes all variants to a public key derived only from fragment/transcript/version and then replaces that singular path. The public Flask API and Flutter models therefore cannot preserve two independently approved voices.

The registration page owns a long-lived `TextEditingController` inside a Riverpod-driven authentication subtree. The reported suffix-restoration sequence must be tested at the editing-value and submitted-request boundaries; changing suggestion flags is not an acceptable correctness fix. Flutter has documented composing/editing synchronization failures when controller values and platform editing state are reconciled, so the implementation must avoid programmatic writes to an active username field and preserve selection/composing state supplied by the text client.

## Goals / Non-Goals

**Goals:**

- Keep narration as pre-generated, cloud-hosted editorial media suitable for uninterrupted headphone use.
- Add normalized content records without branching route logic by city or hardcoding profile names in Flutter.
- Keep singular fragment audio fields valid for deployed clients while the new client selects a profile track.
- Make username deletion correctness independently reproducible without relying on a particular keyboard's suggestion setting.

**Non-Goals:**

- Runtime TTS, arbitrary traveler-supplied provider voice IDs, voice cloning, or per-fragment user voice mixing.
- Cross-device preference sync in the first iteration.
- Migrating historical narration text or changing journey completion rules.

## Decisions

### 1. Voice profiles and fragment tracks are separate content entities

Add `narration_voice_profiles` with UUID, stable slug, display name, description, provider/model/voice metadata, preview media reference, display order, lifecycle status, and default flag. Add `fragment_narration_tracks` with fragment/profile identity, transcript hash, script version, public media reference, generation provenance, approval/publication timestamps, and a unique constraint across fragment/profile/script version.

This avoids storing a JSON audio map on every fragment, lets lifecycle validation query coverage, and keeps provider details out of traveler preference keys. Reusing `NarrationPreview` as public state was rejected because previews expire, use private object keys, and represent attempts rather than approved content.

### 2. Approval promotes to a profile-specific immutable key

Preview generation targets a selected stable profile. Approval writes `public/narration/{fragment}/{profile}/{transcript-hash}-{script-version}-{settings-hash}.mp3`, creates or updates the track record transactionally after storage succeeds, and leaves `StoryFragment.audio_path` untouched unless the target profile is the declared default. A dedicated default action, not ordinary approval, controls the compatibility field.

The settings hash prevents two voice/prosody variants from colliding. Approval remains exact-transcript-checked and current approved media remains intact on storage or database failure.

### 3. Public APIs expose only the route-wide complete profile intersection

The backend computes profile completeness across every narrated fragment in the published route. Route detail returns `narration_profiles`, `default_narration_profile_id`, and each fragment's `narration_tracks` only for profiles in that complete set. Journey ledger returns the same mapping needed after archival so owned journeys remain playable. Absolute media URL rules remain unchanged.

Computing completeness server-side prevents Flutter from making a partial route appear selectable. Results can be repository-eager-loaded and cached with route content because profiles change only through publication operations.

### 4. Flutter resolves an effective profile through a small domain service

A `NarrationVoicePreferenceRepository` stores a profile ID under an authenticated-user-specific key. A provider combines saved preference with the active route's complete profiles and default, yielding one effective profile plus an optional fallback notice. Account switching invalidates only the in-memory effective selection; saved keys remain isolated by user ID.

Route detail and the active tour expose the selector. Playback receives a resolved `NarrationTrack` instead of reading `audioUrl` directly. Prepared-file and background-media identities include route, fragment, profile, transcript hash, and script version so one voice cannot reuse another's cached bytes. A voice change during active playback does not mutate the playing source; it takes effect on replay or the next fragment and the UI states this explicitly.

On-device TTS was rejected because voice availability differs by phone, emotional quality is inconsistent, and it would undermine approved factual narration. Dynamic backend TTS was rejected because it adds latency, cost, and failure at the moment the traveler needs audio.

### 5. Username editing remains field-owned until submission

Wrap the account fields in one `Form` and use `TextFormField` without an application-owned username controller. The application does not observe, normalize, assign, or rebuild username text while the traveler is editing. Clicking register/login first closes the keyboard, calls `FormState.save()`, and submits that final snapshot once.

The regression harness drives the actual sequence—insert `liser`, delete range 3–5, insert `tt` at offset 3—then taps register and asserts both the rendered value and repository request are `listt`. A device integration check repeats the sequence with the production Android text connection. Suggestion/autocorrect flags are unrelated to correctness and are not used as the fix.

If the defect reproduces below the Flutter editing-value boundary on the target device, the fallback is a narrowly scoped native Android username input platform view; this is a last resort because it increases focus, semantics, and theming complexity.

### 6. Independent admin owns route-wide voice generation and publication, not traveler preference

The admin adds profile list/edit/publish/default controls and makes voice/profile selection explicit for each route-wide generation batch. The default profile is selected initially. The primary action generates one configured delivery for every narrated fragment, promotes each successful result directly to that profile's formal public track, and then refreshes route coverage. Generating another profile repeats the route batch without touching any other profile. Coverage shows every route fragment as complete, stale, or missing. Publishing a non-default profile requires complete current-script coverage; archiving removes it from new public selection but does not delete media needed by pinned journeys.

The route batch returns per-fragment results and may preserve successful tracks when one node fails; prior formal tracks are never removed on provider or storage failure. Retry defaults to missing/stale nodes to avoid unnecessary provider cost. A force-regenerate option and the existing per-fragment audition/replacement path are secondary correction tools, not the normal setup workflow.

The admin chooses which safe profiles exist and verifies their audio; the client chooses among those profiles. Neither side contains city-specific voice constants.

## API Contracts

Route and ledger fragment payloads retain `audio_url` and add:

```json
{
  "default_narration_profile_id": "voice-calm",
  "narration_profiles": [
    {
      "id": "voice-calm",
      "name": "沉静纪实",
      "description": "克制、清晰，适合历史街区",
      "preview_audio_url": "https://cdn.example/voices/calm.mp3"
    }
  ],
  "fragments": [
    {
      "id": "fragment-1",
      "audio_url": "https://cdn.example/default.mp3",
      "narration_tracks": {
        "voice-calm": {
          "audio_url": "https://cdn.example/calm/fragment-1.mp3",
          "transcript_hash": "...",
          "script_version": "v2"
        }
      }
    }
  ]
}
```

Admin APIs gain profile CRUD/lifecycle/default operations, route coverage, route/profile batch generation with per-fragment results, and secondary profile-targeted preview generation/approval. Validation errors list stable fragment IDs and never expose TTS credentials.

## Failure Behavior

- Saved profile missing or incomplete: use the backend default, persist the effective fallback for that account/route, and show one non-blocking notice.
- Selected track fetch fails: offer retry and default-track fallback without marking playback complete automatically.
- Preview/approval fails: leave every existing profile track and singular default path unchanged.
- Route batch partially fails: retain every prior formal track, keep successful new tracks, list failed fragment IDs/titles, and leave incomplete profiles unavailable to travelers until retry succeeds.
- Profile publication validation fails: remain offline and return missing/stale fragment IDs.
- Username editing regression detected: registration remains on screen with the exact current visible value; no normalized or stale value is submitted.

## Risks / Trade-offs

- [Multiple voices multiply audio storage and editorial listening work] → Limit MVP to three profiles and expose route coverage before publication.
- [A selected voice may disappear after editorial withdrawal] → Preserve a declared default and make fallback visible but non-blocking.
- [Old and new clients read different audio fields] → Keep `audio_path/audio_url` bound to the default profile and add fields only.
- [Editing behavior can differ by Android keyboard/firmware] → Test complete editing values in widgets plus the production Android text connection; avoid controller text mutation while focused.
- [Admin and Flask map one shared schema independently] → Keep migrations in DeepTravel, mirror models explicitly, and add contract tests in both repositories.

## Migration Plan

1. Add reversible profile/track tables and indexes; deploy readers that tolerate no profile rows.
2. Idempotently create one published default profile and backfill each current fragment `audio_path` as its default track without copying media.
3. Deploy admin profile generation/approval/coverage and generate at least two additional complete profiles before publishing them.
4. Deploy Flask additive serializers and verify old singular fields and new complete profile mappings together.
5. Release the production-profile Flutter APK, verify per-account choice, cache separation, background playback, resume, and the exact username edit sequence on Android.
6. Roll back the client/API independently if needed; retain additive tables and default compatibility fields. Do not delete profile media during rollback.
