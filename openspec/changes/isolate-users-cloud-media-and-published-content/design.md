## Context

See `proposal.md` for motivation and the delta specs for observable behavior. The current API already protects ordinary and fragmented journey operations with `guest_session_id`, but a guest session is being used as both authentication and durable identity. The target model uses a conventional `users` principal and retains guest sessions only as a migration seam. Evidence ownership checks are present, but accepted files and editorial media live on container-mounted filesystems.

Route visibility currently depends only on `published_at IS NOT NULL`. The independent admin normalizes input `published` to `verified`, labels both as “已发布”, and automatically adds `published_at` when an editor chooses `verified`. This makes editorial review and online visibility indistinguishable. Public route-by-id lookups also use the same published-only repository needed for catalog starts, so simply archiving Shanghai would break existing journeys.

The admin and Flask service are separate deployables sharing one backend-owned MySQL schema. The design therefore keeps migrations in `DeepTravel`, uses explicit contract-compatible mappings in `DeepTravel-admin`, and avoids a third content service.

## Goals / Non-Goals

**Goals:**

- Retain bearer-token APIs while making `users.id` the durable ownership principal and keeping test login low-friction.
- Make public/private object storage an infrastructure adapter behind domain-facing ports.
- Separate editorial verification from publication in schema, API predicates and admin language.
- Preserve active legacy journeys while replacing Shanghai discovery with a generic fragmented route.
- Generate expressive narration as an editorial build-time operation whose output is a normal versioned media asset.

**Non-Goals:**

- Derive identity from an installation UUID, IMEI, Android ID, advertising ID or another hardware/device fingerprint.
- Add SMS/social login, password recovery, traveler roles or a profile subsystem in this MVP.
- Allow clients to upload unprocessed evidence directly into the final private bucket.
- Move route content to a second database or call TTS during traveler playback.
- Make TTS output authoritative without transcript, provenance and operator approval.

## Decisions

### 1. A conventional user account is the durable principal

Add `users` with UUID primary key, normalized unique username, password hash, account kind (`registered`, `test`, or `legacy`), active flag, authentication version, and timestamps. Journeys gain a non-null `user_id` after backfill; evidence is owned transitively by the journey. New service/repository methods use `user_id`, never `guest_session_id`, as the authorization boundary.

Normal authentication uses three small endpoints:

```text
POST /api/v1/auth/register     { username, password }
POST /api/v1/auth/login        { username, password }
GET  /api/v1/auth/me
```

Passwords use Werkzeug's versioned `scrypt` hash and are never logged or returned. The existing token manager issues an expiring signed bearer token with `user_id` and `auth_version`; logging in again after expiration restores the same progress. Generic authentication errors and per-IP/username rate limits avoid account enumeration and brute-force amplification. Password reset, refresh-token rotation and multi-device session management remain outside this MVP.

For field testing, `POST /api/v1/auth/test-login` accepts only aliases from `TEST_AUTH_USERS` and only exists when `TEST_AUTH_ENABLED=true`. Seeded `tester-a` and `tester-b` rows are distinct real user rows with `account_kind=test`; the endpoint never accepts arbitrary usernames or runs in the production profile. The Flutter test build exposes one-tap A/B selection under a compile-time test flag, defaults to tester A only when no authorization exists, and clears private presentation caches when switching. Formal registration/login remains the production path.

Migration creates one `legacy` user per existing guest session, backfills its journeys, and links `guest_sessions.user_id`. Existing guest bearer tokens resolve to that user for one compatibility window. While using such a token, the traveler may set an available username/password on the same row; ownership IDs and journey rows do not move or merge.

Alternatives considered: an installation UUID remains device-bound and fails account recovery; a permanent guest token makes leakage and revocation worse; a single global demo account would cause exactly the cross-user progress mixing this change must remove.

### 2. Ownership is verified at the first journey lookup in every private use case

The ordinary journey repository already exposes an owner-scoped lookup, and `FragmentTourService._owned_journey` already checks the current guest principal. Implementation replaces that parameter with `user_id`, makes the invariant explicit in service tests covering every private endpoint, and removes any direct journey lookup that can precede ownership verification. Idempotency keys remain scoped by journey, but duplicate lookup occurs only after ownership is established so timing or cached responses cannot leak another user's operation.

Cross-user failures use the existing not-found code, not forbidden, to avoid confirming identifiers. Evidence storage receives an owner-scoped object key only after `_owned_journey` and fragment eligibility pass.

### 3. Two object-store namespaces share one application port

The main backend defines an `ObjectStorage` port with `put`, `open`, `exists`, `delete`, `public_url` and `sign_get` operations. Implementations:

- `LocalObjectStorage`: current filesystem behavior for development/tests.
- `AlibabaOssObjectStorage`: Alibaba OSS Python SDK V2, environment credential provider and V4 signing.

Production uses separate logical stores or buckets:

- Public editorial: `public/content/...`, delivered through `OSS_PUBLIC_BASE_URL` (prefer a custom CDN domain).
- Private evidence: `private/evidence/{user-prefix}/{journey-id}/{uuid}.jpg`, bucket-private and accessible only with short-lived signed GET or authenticated backend streaming.

The backend continues to proxy evidence upload because image decoding, size/dimension checks, re-encoding and EXIF removal must happen before bytes reach the final object. This is simpler and safer than direct presigned upload plus an asynchronous quarantine processor for the MVP. Admin editorial uploads are likewise proxied initially; their 30 MB limit is acceptable.

The independent admin implements the same storage contract against the shared configuration rather than importing Flask code. Contract fixtures verify equivalent key, URL and failure behavior across both repositories.

### 4. Media rows store canonical references and generation provenance

An additive migration extends `media_assets` with:

- `storage_provider` (`local` or `oss`)
- `object_key`
- `canonical_url`
- `visibility` (`public` or `private`)
- `size_bytes`, `checksum_sha256`
- `metadata_json` for generation/import provenance

`storage_path` remains temporarily for legacy compatibility. Evidence rows gain `storage_provider`, `object_key` and `canonical_reference`; private signed URLs are never persisted. The canonical private reference is an internal `oss://bucket/key`-style locator, not a public bearer URL.

Serializers treat absolute `https://` URLs as final. Safe legacy relative paths continue through `/api/v1/assets/...` until migrated. Admin validation checks cloud objects with `HEAD/exists`, MIME and checksums instead of resolving every value under `media_root`.

An idempotent command uploads existing content files, compares checksum before copying, updates every city/route/stop/fragment media reference in one database transaction per asset group, and emits a report. It never migrates evidence into the public namespace.

### 5. Publication uses a real state machine and separate read paths

Canonical route states are:

```text
draft → in_review → verified → published → archived
  ↑          │          │          │
  └──────────┴──────────┴──────────┘ (new revision remains a private draft)
```

Ordinary form saves may set `draft`, `in_review`, `verified` or `archived` under transition rules but never manufacture publication time. Fragment graph actions are split:

- `POST /routes/{id}/submit-review`
- `POST /routes/{id}/verify` after whole-graph validation/reviewer confirmation
- `POST /routes/{id}/publish` only from `verified`, rerunning validation and atomically setting `published_at`
- `POST /routes/{id}/archive`, preserving immutable content referenced by journeys

The public catalog repository predicates on both `content_status == published` and `published_at IS NOT NULL`. City listing uses an `EXISTS` published-route predicate. Direct public slug detail uses the same rule. A separate internal `get_route_for_journey(route_id)` ignores public visibility but is callable only after journey ownership has been established. Thus archival blocks new starts without breaking pinned journeys.

Migration maps every non-archived row with a non-null `published_at` to `published`, preserving current Nantou/Dameisha/Shanghai visibility during deployment. Rows without a timestamp remain offline. Nested claim/field review states remain separate and can still produce clearly labeled publication warnings; route publication is an operator decision, not a false claim that every nested interpretation is reviewed.

Flutter filters list records to `published` as defense in depth and logs contract violations. Backend deployment and migration precede the new APK because the existing production payload currently calls online routes `verified` or `demo_unverified`.

### 6. Shanghai becomes a new managed route; the old route is archived

Editing `wukang-urban-slices` in place is unsafe because existing answer journeys reference its stops. A new package and slug are created through the generic admin graph contract. It contains five fragments, WGS-84 public pedestrian triggers, three or fewer safe postponable photo observations, linked claims/sources, reconstruction items, cloud cover and approved expressive audio.

The story question focuses on how concession-era street planning and residences, architecture and changing uses, preservation policy, and contemporary city-walk attention created the layered streets visible today. Research uses named official municipal/district archives, cultural heritage listings and museum/library material; field relationships remain labeled until checked on site.

After the new route is validated, verified and published, `wukang-urban-slices` transitions to `archived`. It leaves discovery, but owners with existing journeys continue through the internal journey route reader and legacy answer UI. No Flutter Shanghai branch is added; interaction type and ledger data select the fragmented presentation.

### 7. Expressive TTS is an admin provider, not a runtime plugin

The integration boundary is a small `NarrationSynthesizer` contract taking transcript, model, curated `voice_id`, emotion, speed, pitch and pronunciation dictionary and returning normalized audio plus provider metadata. The initial production adapter calls MiniMax's domestic T2A endpoint with `speech-2.8-hd` because its official API offers hundreds of preset voices, Mandarin, emotion control, pronunciation entries and high-quality MP3 output. Keys remain server-side in `MINIMAX_API_KEY`.

Alternatives retained behind the same boundary:

- Alibaba Model Studio CosyVoice: strong same-vendor fit with OSS and preset/Instruct emotional voices.
- Azure Speech: mature SSML and Chinese `story`, `documentary-narration`, `narration-relaxed` and emotion styles, but adds a second overseas cloud dependency.
- Manual studio upload: always available and remains the final fallback.

The admin creates preview records in a private/temporary object prefix. The operator compares at least three variants against the same transcript. Approval requires the stored transcript SHA-256 to match the current script, copies or promotes the object into public versioned media, and writes model/voice/emotion/prosody/pronunciation metadata. Publication validation requires an approved narration whose script version matches the fragment.

The preferred direction is restrained `calm` or provider automatic/fluent prosody around 0.92–1.0 speed, with per-fragment variation only where the text supports it. TTS never rewrites the historical transcript.

### 8. Failure behavior preserves the last valid public experience

- OSS unavailable during upload: no media row/reference is committed; existing approved asset remains.
- Database failure after object write: best-effort object cleanup and an orphan audit command.
- TTS timeout/error: preview is failed with sanitized provider trace; current narration remains.
- Signed evidence URL expiry: Flutter requests a fresh owner-authorized URL.
- Lifecycle validation failure: status and timestamp do not change.
- Identity rotation race: unique hash plus transactional retry returns the existing principal.

### 9. Verification is layered and credential-free by default

Backend tests use two registered/test users against all ordinary/fragment/evidence operations, logout/re-login with a fake clock, disabled test-auth behavior, legacy-user conversion, lifecycle visibility, archived journey continuation, local object storage and a fake OSS contract. Admin tests cover state labels/transitions, object upload rollback, cloud media validation and fake TTS preview/approval. Flutter tests cover normal login, test-account switching, private-cache clearing, published-only discovery, no answer UI for a configured Shanghai-like fixture, legacy journey compatibility and expiring evidence access.

Optional integration tests run against a dedicated OSS prefix and MiniMax account only when explicit environment flags are present; they are never part of the default suite.

## Risks / Trade-offs

- [The deliberately simple password flow lacks recovery and refresh tokens] → Keep the MVP account surface minimal, permit re-login after expiry, version token subjects, rate-limit failures and add recovery only when real account operations require it.
- [A test-login endpoint could become a production bypass] → Make route registration conditional at startup, require an explicit allowlist, fail production configuration if test auth is enabled, and cover disabled behavior in deployment smoke tests.
- [Server-proxied photo upload uses bandwidth] → Keep current size limits and image normalization; consider quarantine plus direct presigned upload only after usage justifies it.
- [Database and OSS cannot share one transaction] → Upload first under immutable keys, commit references second, clean up on failure and audit orphans.
- [A client-side published filter could temporarily hide all old-status routes] → Deploy backend migration before the APK and smoke-test public payloads.
- [Archiving without a full route snapshot still depends on immutable rows] → Retain the existing published-route structural lock; add immutable content revisions before allowing edits to archived referenced routes.
- [Expressive TTS can sound theatrical or mispronounce names] → Curated allowlist, three-way audition, restrained styles, pronunciation dictionary, exact transcript hash and manual approval.
- [Shanghai research can repeat popular myths] → Require named source/claim links and separate documented facts from editorial/field interpretation.

## Migration Plan

1. Add `users`, nullable `journeys.user_id`, `guest_sessions.user_id`, media columns and lifecycle-compatible indexes with downgrade tests; deploy code that reads legacy and new ownership values.
2. Backfill `published` from existing `published_at`, deploy strict public predicates and verify Nantou/Dameisha/current Shanghai visibility before changing admin labels.
3. Create one legacy user per guest session, backfill journey ownership, deploy dual-token compatibility and account/test-login endpoints, then make `journeys.user_id` non-null after consistency checks. Monitor authentication failures and cross-owner denials.
4. Configure public/private OSS buckets, RAM least-privilege credentials and optional CDN; deploy storage adapters in backend and admin with local fallback.
5. Run the idempotent content-media migration, compare checksum/URL/MIME results, then keep legacy local serving during a burn-in period.
6. Deploy admin lifecycle actions and MiniMax preview generation. Generate and approve replacement narration without changing published references until each preview passes listening review.
7. Research/import/validate/verify/publish the new Shanghai fragmented package. Smoke-test discovery and a complete journey, then archive the legacy Shanghai route and verify an existing legacy journey still resumes.
8. Build and install the production-address APK, test register/logout/login, tester A/B switching in a test build, cross-user denial, private photo retrieval, published-only catalogs and both real/simulated location modes. Confirm the production profile exposes no test-login route.

Rollback keeps additive user/media columns and the guest compatibility mapping. Restore the previous app/backend while guest and local-media paths remain, set object storage to local if needed, and revert route lifecycle values from `published` to `verified` only together with the old public predicate. Never delete migrated OSS objects or archive the old Shanghai route until the new route and continuation checks pass.

## Open Questions

- The final MiniMax preset voice IDs and per-fragment expressive settings will be selected by same-script A/B listening in the admin; this does not change provider contracts or tasks.
- Shanghai trigger centers and field-audit labels will be finalized from an on-site pass through the existing admin configuration path.
