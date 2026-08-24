## Context

Discovery route summaries already contain route presentation data and a public audio-tour manifest, while the active tour stores narration files in `prepared_assets`. Public manifests deliberately hide full fragment text until a node is revealed, so a real offline package needs a separate manifest contract. The current pre-trip downloader writes a second file tree and the route-start preparation path is governed by automatic-download preferences, which is unsuitable for an explicit card action.

## Goals / Non-Goals

**Goals:**

- Make the card control the single explicit package-download entry.
- Preserve one canonical audio file/index path for downloading, streaming fallback, and playback.
- Commit only complete, version-matched, checksum-verified packages.
- Support offline cold read, start, local progress, queued mutations, and automatic reconnect reconciliation.

**Non-Goals:**

- Packaging maps, community content, or private cloud media.
- Reworking route discovery ranking, card navigation, location algorithms, or editorial publication.

## Decisions

### 1. The backend publishes a canonical offline manifest, not a binary archive

`GET /api/v1/routes/{slug}/offline-package` returns a JSON envelope with package version, canonical SHA-256, route metadata, full route story text needed during offline playback, and the current published narration asset identities. Each audio identity includes URL, byte size, script version, MIME type, and SHA-256. JSON keeps partial retry possible and avoids duplicating large audio into a server-generated archive.

The package checksum covers canonical JSON excluding the checksum field. The client verifies that checksum before downloading and verifies every selected narration file after download. Missing checksums, version disagreement, or byte mismatch keep the package out of the complete state.

### 2. Package download reuses `PreparedRouteService`

Explicit package download bypasses the automatic-download preference but calls the same prepared-file lookup, temporary `.download` write, validation, atomic rename, and `prepared_assets` registration used by the player. The service adds progress callbacks and checksum-aware validation; it does not introduce another audio directory or cache index.

Package metadata is stored in the existing local tour database only after all assets pass validation. Partial audio remains reusable on retry, while the package status is failed/incomplete and cannot be used for an offline start.

### 3. Card state is route-scoped and interaction-isolated

A route-scoped Riverpod controller exposes idle, downloading with completed/total counts, complete with version/integrity summary, failed with retry, and stale. The footer uses a 48 dp `IconButton` with a 20 dp glyph. Its gesture owns the tap, while the surrounding card `InkWell` remains the city-manual navigation action.

The old pre-trip prepare/remove buttons are removed so the card remains the only explicit download entry. Settings cleanup remains a management action, not a second per-card download entry.

### 4. Verified metadata is the offline read fallback

Route detail first uses the API and falls back only to a complete verified local package. Discovery cold start can reconstruct the downloaded city/route cards from package metadata when the API is unreachable. Stale or failed packages are visible for retry but are never treated as playable.

### 5. Offline journey IDs are local aliases reconciled before dependent events

When starting a verified package without network access, the client creates a deterministic account-and-route-scoped local journey alias and seeds its ledger from the packaged fragments. Trigger, playback, and evidence mutations update the local ledger first and enter the existing outbox with stable UUID idempotency keys.

Reconnect reconciliation processes `start_journey` before dependent mutations, stores the returned server journey ID as the alias mapping, substitutes it into later events, and acknowledges each event only after the server accepts it. Existing trigger/playback/evidence endpoints already use idempotency keys, and journey creation is start-or-resume by account/route, so retries are safe.

Connectivity changes trigger reconciliation in addition to the existing start-time attempt. A failed item stops the ordered pass and remains pending.

### 6. Playback progress is durable local state

The player periodically checkpoints fragment position and duration into the local journey snapshot. Offline completion updates the local ledger and queues the same playback acknowledgement used online. Restoring a route uses the local checkpoint before subsequent server reconciliation.

## API Contract

```json
{
  "data": {
    "package_version": "nantou-2026.08-review.1",
    "package_checksum_sha256": "<64 lowercase hex>",
    "city": {"id": "...", "slug": "shenzhen", "name": "深圳"},
    "route": {
      "id": "...",
      "slug": "nantou-ancient-city",
      "audio_tour": {
        "script_version": "nantou-2026.08-review.1",
        "fragments": [
          {
            "id": "...",
            "title": "...",
            "transcript": "...",
            "audio": {
              "url": "https://...",
              "size_bytes": 1234,
              "script_version": "nantou-2026.08-review.1",
              "checksum_sha256": "<64 lowercase hex>"
            }
          }
        ]
      }
    }
  }
}
```

## Failure Behavior

- Manifest fetch fails: show failed/retry; retain any previously complete version.
- Package checksum fails: reject before audio download and retain the prior complete package.
- One asset fails: show failed/retry, do not commit new package metadata, and reuse already verified files on retry.
- Package version changes: show stale and require an explicit new download; never mix manifest versions.
- Network is absent during start: allow only a complete verified package; otherwise retain the normal recoverable error.
- Reconnect sync fails: stop at the first unacknowledged event and retry on the next connectivity recovery without duplicating accepted events.

## Risks / Trade-offs

- [Full text is available after package download] → Expose it only through the explicit package endpoint for published routes; the UI still reveals nodes according to journey rules.
- [Checksumming large files costs CPU] → Verify once after download and reuse indexed files while version, size, path, and checksum identity match.
- [Local and server journey IDs differ temporarily] → Persist an alias mapping and resolve it in the ordered outbox before dependent events.
- [Removing detail download changes an existing affordance] → The card entry is always visible earlier and is the product-defined single source of truth.

## Migration Plan

1. Deploy the additive checksum and offline-package read contract.
2. Release the client database migration and package service; existing prepared audio remains valid but is reverified before a package is marked complete.
3. Enable the card entry and remove the duplicate detail action in the same client release.
4. Rollback can hide the card control; additive endpoint/fields and cached audio remain harmless. No server data migration is required.
