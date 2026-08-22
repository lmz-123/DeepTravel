## 1. Generic Content Contracts

- [x] 1.1 Add backend-owned migration metadata for trigger coordinate provenance and management package idempotency, preserving all existing rows and verifying upgrade/downgrade on MySQL.
- [x] 1.2 Implement a framework-neutral fragmented-route graph schema and validator covering identifiers, order, dependency DAG, WGS-84 geometry, assets, claims/sources, missions and reconstruction items, with focused unit tests.
- [x] 1.3 Add backward-compatible reconstruction item normalization and ledger/API output using stable IDs, deterministic shuffle and position-only mismatch feedback, with Nantou regression tests.

## 2. Independent Admin Management Path

- [x] 2.1 Extend the `DeepTravel-admin` SQLAlchemy mappings and authenticated API to read/write a complete private draft graph without broad schema creation, with transaction and authorization tests.
- [x] 2.2 Add route validate and atomic publish endpoints with field-addressable errors, package-version idempotency, public visibility guarantees, media reference protection and `published_route_locked` conflict behavior.
- [x] 2.3 Extend the admin web route workspace for story arc, fragments, dependencies, triggers/provenance, missions, sources/claims, causal-order editing and validation/publish results.
- [x] 2.4 Extend JSON import/export to the same complete graph contract and test that UI-created and imported drafts produce equivalent management payloads.

## 3. Dameisha Content and Media

- [x] 3.1 Author the sourced five-fragment Dameisha package with stable identifiers, causal relationships, review labels, exactly three safe postponable photo missions and the provisional WGS-84 trigger policy.
- [x] 3.2 Generate and upload a text-free documentary cover plus five Mandarin preview narrations derived exactly from configured transcripts, then verify backend URLs and MIME types.
- [x] 3.3 Import, validate and publish Dameisha through the generic admin path twice to verify idempotency, catalog coexistence and absence of any Dameisha-specific runtime seed branch.

## 4. Flutter Reconstruction and Continuity

- [x] 4.1 Remove all route-specific reconstruction strings from Flutter and populate the reorderable puzzle from ledger-supplied stable items for Dameisha, Nantou and a generic configured fixture.
- [x] 4.2 Present wrong-order feedback in a root overlay above the modal sheet, show the exact mismatch count, mark mismatched rows without revealing correct order and clean up overlay state on retry, success and disposal.
- [x] 4.3 Verify collected audio controls and full transcripts survive navigation/re-entry, and real mode continues monitoring after stale, inaccurate or server-rejected samples.

## 5. Automated Verification

- [x] 5.1 Add backend API tests for draft invisibility, validation rollback, atomic publication, route lock, Dameisha discovery/detail, journey creation, real arrival, ledger, reconstruction and photo evidence.
- [x] 5.2 Add independent admin server/UI tests for complete content CRUD/import, validation paths, publish state, media protection and compatibility with backend-owned schema.
- [x] 5.3 Add Flutter widget/controller tests that reproduce the modal occlusion bug and prove the root mismatch overlay, count, row highlighting, configured options and correct completion flow.
- [x] 5.4 Run backend format/lint/tests, admin server and web tests/build, Flutter format/analyze/tests, and clean plus existing-data MySQL integration smoke tests.

## 6. Field and Delivery

- [x] 6.1 Add a Dameisha Android field checklist recording at least eight samples per stop, accuracy/drift, trigger timing, safe surface, false-entry checks and background/re-entry behavior.
- [ ] 6.2 Smoke-test both deployed services and all media over their production addresses, then install a release APK configured for `http://115.29.221.190:5001` with simulation disabled.
- [ ] 6.3 Commit scoped changes, push `main` to both `DeepTravel` and `DeepTravel-admin`, and provide idempotent server pull/migration/redeploy commands plus the APK artifact.
