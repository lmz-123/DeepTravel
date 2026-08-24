## 1. Offline package contract

- [x] 1.1 Add narration asset checksums and a canonical published-route offline-package endpoint containing route metadata and complete story text; verify version, checksum, publication filtering, and ordinary route contract compatibility.

## 2. Shared local package cache

- [x] 2.1 Extend the prepared-audio cache with explicit-download mode, progress, SHA-256 validation, and reusable verified-file lookup; test success, retry, partial failure, and checksum rejection.
- [x] 2.2 Persist complete package metadata, integrity/version state, and local journey aliases through the existing SQLite snapshot/outbox schema without adding a second cache; test cold reads and stale/incomplete rejection.

## 3. Single card entry

- [x] 3.1 Add the 48 dp footer-left accessible package control with idle, progress, complete, stale, and failed/retry states; verify it never invokes card navigation and remains visually separated from “打开城市手册”.
- [x] 3.2 Remove the route-detail pre-trip download/remove controls while retaining the pre-trip content and Settings cache management.

## 4. Offline read and journey continuity

- [x] 4.1 Fall back to verified package metadata for route detail and discovery cold start when the API is unavailable; test that failed/stale packages are not treated as usable.
- [x] 4.2 Allow a verified route to create a local journey alias, reveal packaged text, play shared cached audio, and checkpoint progress without network access; add controller tests for offline start and restart restore.
- [x] 4.3 Reconcile local journey creation and dependent trigger/playback/evidence events in order with idempotency keys when connectivity returns; test repeated recovery and partial failure.

## 5. Verification and documentation

- [x] 5.1 Run backend formatting/tests, Flutter format/analyze/tests, and strict OpenSpec validation; update README behavior notes without changing unrelated product documentation.

## 6. Follow-up interaction and discovery layout

- [x] 6.1 Keep download feedback inline as determinate circular progress without a dialog or detail page.
- [x] 6.2 Add an inline Settings offline-cache list with selective package removal and shared-audio protection.
- [x] 6.3 Remove the home footprint-resume card and move city stories below scenic-area selection.
- [x] 6.4 Add regression coverage and rerun Flutter analysis/tests plus strict OpenSpec validation.
