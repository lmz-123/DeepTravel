## Why

The MVP already scopes most journey operations to an expiring guest session, but guest sessions are not a durable user boundary and can expose or detach progress when client state changes. Media is still bound to server disks, the admin conflates `verified` with “published”, and Shanghai still exposes the older quiz loop with flat preview narration; these gaps now block credible multi-user testing and content operations.

## What Changes

- Add a conventional account identity boundary: users can register and log in with a username and password, bearer tokens identify `user_id`, and every journey, fragment, reconstruction and private evidence operation is ownership-scoped.
- Keep MVP testing lightweight with an explicitly enabled test-login endpoint and Flutter test build that can enter isolated test accounts A/B in one tap. Test login is disabled by default in production and does not use installation UUIDs, hardware identifiers or device fingerprints.
- Preserve current guest progress through a compatibility mapping from each legacy guest session to a temporary user; an authenticated legacy user can set login credentials without moving journey rows between users.
- Add a storage port with local and Alibaba Cloud OSS implementations. Admin content images, covers, narration and traveler evidence are uploaded through validated backend/admin flows, while MySQL stores provider metadata and canonical object URLs instead of binary data.
- Keep traveler evidence private in OSS and expose it only through short-lived owner-authorized access; published editorial images/audio use configured public CDN/OSS URLs.
- Define an explicit route lifecycle `draft → in_review → verified → published → archived`. `verified` means editorial approval but remains offline; only `published` with a publication timestamp is returned by public city, route and detail APIs.
- Correct the independent admin labels, counts, editing controls, validation, verify/publish actions and visibility indicators. Prevent ordinary route saves from silently publishing content.
- Add client-side defensive filtering and neutral states so non-published routes are never rendered even if a stale or misconfigured API includes them.
- Publish a new five-fragment Shanghai walking route through the generic admin path, with location-triggered narration, transcripts, photo observations and reconstruction like Shenzhen. Archive the old public quiz route while preserving existing journey access; no answer task is required on the new route.
- Add a replaceable narration-generation provider to the independent admin, with MiniMax `speech-2.8-hd` as the MVP provider. Operators can choose a curated preset voice, emotion, pace and pronunciation dictionary, preview the result, approve it and store the generated audio in OSS.
- Migrate existing server media and existing online route lifecycle values idempotently, with local-storage fallback retained for development and tests.

## Capabilities

### New Capabilities

- `anonymous-install-identity`: Account-backed user authentication, strict `user_id` ownership, legacy guest conversion and gated test-account login. The existing capability path is retained to revise the already-created artifact.
- `cloud-media-storage`: Provider-neutral object storage, OSS-backed editorial media and private traveler evidence.
- `content-publication-lifecycle`: Unambiguous draft/review/verification/publication/archive transitions across admin, backend and client.
- `shanghai-fragmented-audio-route`: Shanghai parity with Shenzhen's location audio, photo observation and reconstruction loop without quiz answers.
- `expressive-narration-generation`: Admin-operated expressive TTS previews and approved narration versions stored as normal media assets.

### Modified Capabilities

- `platform-runtime`: Journey authorization becomes account-backed while an environment-gated test login keeps MVP verification simple.
- `route-discovery`: Public discovery exposes only explicitly published cities/routes and only cloud/backend media URLs.
- `guided-journey`: Existing owners may finish an archived route, while newly started Shanghai journeys use the fragmented loop without answer gating.
- `experience-client`: The client supports normal and test login, hides non-published records defensively and presents cloud-hosted private evidence only to its owner.

## Impact

- Flask API, SQLAlchemy models/repositories, Alembic migrations, token/session flow, evidence storage, route visibility queries and deployment environment gain users, password authentication, test-login gating, lifecycle and object-storage support.
- Flutter gains login/register state, test-account switching and defensive publication filtering; its route UI remains data-driven and receives no Shanghai content constants.
- `DeepTravel-admin` gains OSS media operations, lifecycle actions/status labels, expressive narration preview/generation and a Shanghai package imported through the existing graph contract.
- MySQL stores users, password hashes, user-owned progress, canonical media/object references and TTS generation metadata; no image/audio binary is stored in MySQL.
- New optional dependencies and secrets include Alibaba OSS credentials/configuration and a MiniMax API key. Local/test profiles require neither.

## Non-goals

- SMS login, social login, password recovery, profile systems, roles for travelers or device fingerprinting.
- Public access to traveler photos, permanent signed evidence URLs or direct unvalidated client uploads to OSS.
- Runtime TTS on the traveler's phone, voice cloning of a real person, or automatic publication of generated audio without operator preview.
- Rewriting active legacy Shanghai journeys or deleting their answer/evidence history.
- Declaring Shanghai historical claims reviewed without named sources and an explicit admin review decision.

## MVP Validation Goals

- Two logged-in test accounts receive different user principals; neither can read or mutate the other's journey, ledger, reconstruction or evidence, while logging out and back into the same account preserves progress.
- Admin-uploaded covers, route images and generated narration resolve from OSS/CDN URLs; traveler photos are private objects and owner-only retrieval uses short-lived access.
- A route in `draft`, `in_review` or `verified` is absent from cities, route lists and route detail; only the explicit publish action makes it visible, and archive removes it from new discovery without breaking owned active journeys.
- Shanghai appears as a five-fragment audio route with no answer UI or answer requirement, and a generic configured fixture proves that this behavior is not route-specific Flutter code.
- At least three curated expressive voice previews are compared on the same Shanghai fragment; the approved MiniMax generation is traceable by model, preset voice, emotion, pace, script version and OSS media record.
- Backend, admin and Flutter suites pass with local storage and fake TTS providers, without private cloud credentials.
