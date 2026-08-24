## Why

Travelers currently meet two partial download behaviors: route audio may be prepared only after starting a journey, and pre-trip story resources can be downloaded from route detail. Neither behavior creates one understandable scenic-area package that can be verified and started without a network connection. The duplicate entry also makes download and route navigation easier to confuse.

## What Changes

- Keep exactly one offline-package entry on each scenic-area card, at the left side of the card footer, separated from the right-side “打开城市手册” navigation action.
- Give the entry explicit idle, downloading/progress, complete, failed/retry, and stale-version states without allowing its tap to open route detail or begin exploration.
- Keep download feedback inline on the scenic card as a circular progress indicator; do not open a download dialog or detail page.
- Publish a versioned offline-package manifest containing route metadata, complete story text, selected narration assets, byte sizes, and SHA-256 checksums.
- Download package audio through the same prepared-asset index and file paths used by the narration player; atomically commit package metadata only after integrity validation succeeds.
- Allow a verified package to open and start without network access, retaining text, audio, route state, and playback progress locally.
- Queue offline journey creation, triggers, playback progress, and evidence state with stable idempotency keys, then reconcile automatically when connectivity returns.
- Remove the duplicate pre-trip resource download action from route detail while keeping cache cleanup in Settings.
- List installed scenic offline packages in Settings and allow each package to be removed independently.
- Remove the discovery-page “继续我的足迹” card and place city-story modules after scenic-area selection.

## Capabilities

### New Capabilities

- `offline-route-package`: Versioned scenic-area package publication, integrity validation, shared local cache, offline journey start, and reconnect reconciliation.

### Modified Capabilities

- `experience-client`: Scenic-area cards expose one accessible, non-navigating download control with clear lifecycle feedback.
- `guided-journey`: A verified downloaded route can start and retain progress offline, then synchronize idempotently.
- `route-discovery`: Published route packages expose complete versioned metadata and verified asset identities without changing ordinary card browsing.

## Impact

- Flask gains one public read-only offline-package endpoint and additive checksum fields on narration assets.
- Flutter gains an offline-package service/controller, durable package metadata, cached route fallback, card status UI, and offline journey reconciliation.
- Existing narration prepared files remain the sole audio cache used by both package download and playback.
- No admin workflow, content schema, scenic-route ordering, card image layout, or journey rules change.

## Non-goals

- Offline maps or map tiles.
- Downloading community posts, remote photos, or arbitrary city-wide content.
- Changing route publication, historical review, location trigger thresholds, or reconstruction rules.
- Adding another download entry on route detail, imagery, or the card's right edge.

## MVP Validation Goals

- Every scenic-area card has one 44–48 dp download target at footer left and its tap never invokes card navigation.
- Downloaded metadata, story text, and selected-profile audio pass size and SHA-256 verification before the package becomes complete.
- A completed package can be opened and started after network loss, and its audio is read from the same prepared cache as normal playback.
- Offline trigger/playback state survives restart and queued mutations reconcile once, in order, after connectivity returns.
