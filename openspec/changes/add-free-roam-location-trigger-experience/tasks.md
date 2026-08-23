## 1. Baseline and scope guardrails

- [x] 1.1 Add regression coverage that locks the current real-location behavior: every untriggered manifest fragment is evaluated independently, overlapping qualified regions choose the nearest point deterministically, and authored dependencies do not gate a real trigger.
- [x] 1.2 Audit current route, fragment, narration-track and trigger-region publication rules and document the exact existing combination used for new field-trigger eligibility; preserve owner access to already saved withdrawn content.
- [x] 1.3 Confirm the existing independent-admin trigger-region editor and content package already express every required field; add no admin change, city geometry, route recommendation field, or database migration unless this audit disproves the design assumption.

## 2. Backend field-story contract

- [x] 2.1 Harden the existing trigger application service so real-location requests validate owner journey, stable fragment membership, current publication eligibility, independent trigger policy and idempotency without consulting authored position or dependency completion.
- [x] 2.2 Extend the backward-compatible public fragment/ledger projection with a backend-derived display theme and expected listening duration, using existing arbitrary experience tags, route/arc content and published narration metadata without a client enum or new content table.
- [x] 2.3 Preserve dependency IDs and the causal model solely as narrative/reconstruction metadata, and verify unordered trigger/playback timestamps never rewrite or reorder that content.
- [x] 2.4 Add API/application tests for a later point first, skip-and-return, overlapping regions, unpublished/withdrawn point rejection, already-saved point readability, idempotent retry, arbitrary themes, duration fallback and absence of photo/answer gates.

## 3. Flutter nearby-point domain and state

- [x] 3.1 Add rolling-deployment-safe fragment fields for backend display theme and expected duration while preserving unknown labels and avoiding fake values when an old API omits them.
- [x] 3.2 Implement a pure nearby-point projection that combines manifest fragments, ledger states and one transient real sample; order by unrounded distance then backend position and stable ID, and fall back to backend order with null distance when location is unavailable.
- [x] 3.3 Derive per-point outside/candidate/in-range/triggered/heard state from each point's existing region policy without using selected node, route position, dependency IDs, photo evidence or observation state as eligibility inputs.
- [x] 3.4 Keep raw coordinates and calculated distances out of persistence, non-trigger API requests and runtime logs; clear the transient nearby state when stopping, switching user/route or disposing the active tour.
- [x] 3.5 Add pure/controller tests for arbitrary walking order, different per-point radii, overlap tie breaks, permission/service/acquisition failure, stable no-location ordering, no fake distance, transient privacy and stale-state cleanup.

## 4. Flutter free-roam presentation and replay

- [x] 4.1 Restore and preserve the original node rail and node-page structure as the primary journey navigation; remove the replacement nearby-point list and place selected-node backend story copy, theme, duration, heard and proximity/trigger status directly below the rail and before the existing audio card.
- [x] 4.2 Enable every published node button for selection regardless of authored order. Untriggered selection is informational only and must not trigger, reveal, play or collect; triggered and collected nodes continue through the existing single-player replay flow. Render exactly the backend node count, adapting visual size/spacing and using safe horizontal scrolling when density requires it rather than assuming five nodes.
- [x] 4.3 Ensure historical selection/replay never emits a trigger or duplicate collection, never changes the live location candidate set, and safely returns to the current formal journey state after interruption.
- [x] 4.4 Add explicit loading, unavailable-location, empty-content, offline and retry presentation; display no calculated distance without a current sample and preserve readable backend order.
- [x] 4.5 Add widget/semantics tests proving the original node rail remains visible, every node is selectable, untriggered selection changes no progress, selected-node copy appears between rail and audio card, non-five node counts remain usable without overflow, triggered-node replay still works, and no mandatory real-mode next-stop action returns.

## 5. Partial footprints and causal reconstruction

- [x] 5.1 Reuse the authenticated journey collection as the single footprint source and show active partial journeys alongside completed footprints with collected/total points, last activity and optional evidence count.
- [x] 5.2 Resume a partial footprint through the existing owner journey context, local snapshot/outbox reconciliation and server ledger without resetting to the first authored point or losing triggered, heard or optional-photo state.
- [x] 5.3 Keep observation hints and photos non-blocking across trigger, collection, resume and completion, including a valid no-photo partial/completed footprint state.
- [x] 5.4 Add backend and Flutter tests proving incomplete journeys remain visible/resumable, unordered collection unlocks reconstruction when complete, walked order is not accepted as causal order, the authored causal order still succeeds, and optional records never alter reconstruction eligibility.

## 6. Verification and delivery

- [x] 6.1 Run focused and full backend tests, formatter/lint, Flutter formatting/analyze/tests and privacy/log audits; preserve the original node UI, existing legacy ordered-route compatibility and unrelated user files.
- [x] 6.2 Run strict OpenSpec validation and inspect the diff for replacement node surfaces, route recommendation, map/navigation, city/range recognition, location persistence, hard-coded tags or unrelated admin/schema work.
- [x] 6.3 Update only the field/free-roam documentation needed to state that the original node rail remains the primary selector and untriggered selection is informational.
- [x] 6.4 Increment the full mobile version, build and inspect the production Android APK when required credentials are available, then commit and push scoped main-repository changes.
