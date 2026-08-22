## Why

The Shenzhen catalog currently proves the fragmented audio-tour loop only at Nantou, while new fragmented routes still require developer-authored seed code and Flutter hard-codes Nantou reconstruction choices. Dameisha is needed now as both a real-location coastal field test and the first end-to-end proof that future cities and attractions can be authored, validated and published from the independent admin without a code release.

## What Changes

- Add a second Shenzhen fragmented audio route at Dameisha with five connected, sourced story fragments: old village and place name, transport opening the bay, the 1999 public beach, visitor carrying-capacity tension, and post-typhoon resilient reconstruction.
- Extend the existing independent admin and management API so an operator can configure the complete fragmented-route graph: city, route, story arc, fragments, dependencies, WGS-84 triggers, photo missions, sources, claims, reconstruction items, cover and narration media.
- Add a draft validation and atomic publish workflow. Invalid or incomplete content remains private; newly published cities and routes become available to the existing public API without a backend or mobile deployment.
- Stop using route-specific seed code as the source of new editorial content. Existing seeds remain only as legacy/bootstrap data, while Dameisha is installed through the same management import/publish contract available to future content.
- Add WGS-84 trigger regions on dry public walking surfaces, with two-sample entry confirmation, non-overlapping radii, accuracy limits, coordinate provenance and field-audit labels.
- Add three safe, postponable photo missions, five versioned Mandarin preview narrations, matching transcripts, a backend-hosted cover, source/claim records and a causal reconstruction.
- Remove route-specific reconstruction choices from Flutter. The ledger supplies route-configured reconstruction items, and an incorrect submission displays a root-level top overlay with the mismatch count while highlighting mismatched positions inside the puzzle.
- Keep the real/simulated location selector available in every Android build. Field testing selects real location at runtime; release configuration MUST NOT remove the simulated test path or force a mode.
- Replace the single-route home presentation with a backend-driven city and route discovery carousel. Published routes returned by the selected city's public API are horizontally swipeable with polished selection animation, and Flutter contains no destination-specific fallback copy or route records.
- Add management publish, public API, dependency, asset, coordinate, reconstruction-overlay and real-location transition tests, plus a Dameisha field checklist.

## Capabilities

### New Capabilities

- `dameisha-field-route`: Defines the admin-authored and atomically published five-fragment Dameisha route, field-safe WGS-84 triggers, sourced media/content, data-driven reconstruction, top-layer mismatch feedback and real-location field acceptance criteria.

### Modified Capabilities

None. The change extends the new Dameisha capability through existing public route and journey endpoints while keeping existing published routes and journeys compatible.

## Impact

- The Flask backend gains authenticated content-validation/publish support, generic reconstruction-option output and any schema metadata needed for coordinate provenance and safe publication.
- The independent `DeepTravel-admin` FastAPI service and web UI gain fragmented-route editing, whole-route validation, import and publish controls against the shared MySQL database.
- Flutter removes Nantou-specific reconstruction constants, consumes reconstruction items from the ledger and presents incorrect-order feedback above modal content.
- Flutter also removes compile-time location-mode gating and destination-specific home fallbacks, then renders all published backend routes in a horizontally swipeable selector.
- MySQL receives additive management metadata and Dameisha content through the admin publishing transaction; existing Nantou, Shanghai, guest journey and evidence rows remain intact.
- Deployment media gains one route cover and five preview audio assets served from the backend.

## Non-goals

- Claim that the draft route or coordinates are publication-reviewed before the on-site pass.
- Place triggers in seawater, require swimming, or ask the traveler to cross traffic for a clue.
- Add turn-by-turn navigation, tide prediction, weather services, computer-vision scoring or new mobile permissions.
- Add multi-user editorial roles, concurrent collaborative editing, scheduled publication or a general-purpose CMS workflow.
- Permit structural mutation of a published route after user journeys reference it; published revisioning can build on the validation boundary later.
- Replace Nantou as Shenzhen's featured route before field results are reviewed.

## MVP Validation Goals

- An operator can create or import Dameisha in the independent admin, see all validation failures, publish it atomically, and then discover it in the existing mobile client without redeploying backend or Flutter code.
- A draft missing media, claims, sources, reconstruction items, dependencies or valid non-overlapping WGS-84 triggers cannot become publicly visible and cannot partially modify the previous published state.
- With simulated location disabled, an Android device can walk the authored order and trigger all five fragments once using two qualifying WGS-84 samples per region.
- The same release APK always exposes the real/simulated location switch; selecting real mode performs the field walk, while selecting simulated mode remains available for controlled testing.
- When the Shenzhen catalog returns Nantou and Dameisha, both appear as swipe-selectable home cards without a client content update; selection details and navigation always follow the currently centered backend route.
- Every triggered or collected fragment continues to expose its audio controls and full transcript after leaving and re-entering the journey.
- The reconstruction puzzle shows only items supplied by the active route; a wrong order raises a root-level visible message stating the mismatch count and marks the mismatched rows without revealing the correct order.
- No Dameisha or Nantou reconstruction text is hard-coded in Flutter, and a configured test route can complete the same reconstruction flow unchanged.
