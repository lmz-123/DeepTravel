## Why

Most self-guided travel products optimize for finding and checking off places, while curious travelers need a lightweight way to understand a place without turning the trip into a lesson. The MVP must test whether a story-led walk with real-world observation challenges can sustain attention through a complete 60–90 minute route.

## What Changes

- Introduce the “见地” Flutter application with an elegant editorial visual system and smooth, accessible motion.
- Introduce city and route discovery, a five-stop Shanghai demonstration route, route detail, and a map-based preview.
- Introduce an active journey flow combining short audio stories, observation prompts, answer feedback, manual/demo arrival, pause/resume, and route progress.
- Introduce a completion recap that records explored stops, insights, and elapsed progress.
- Introduce a versioned Flask REST API backed by MySQL, with guest sessions and durable journey progress.
- Add Docker Compose, seed data, backend tests, mobile tests, and local-development documentation.
- Clearly label demonstration history copy as unverified seed content pending editorial review.

### Non-goals

- Payments, user-generated routes, social feeds, multiplayer sync, AR, AI chat, background geofencing, production offline map tiles, and a CMS are excluded.
- The MVP does not claim publication-grade historical authority.
- The MVP does not cover multiple production cities or account/password authentication.

### MVP validation goals

- A new user can start the featured route in no more than three primary taps.
- A user can complete all five stops without registration or third-party API keys.
- Progress survives an API process restart when MySQL is used.
- Every stop follows the loop: arrive, listen/read, observe, answer, receive insight, continue.

## Capabilities

### New Capabilities

- `route-discovery`: Browse cities and curated cultural routes, inspect duration, distance, themes, stops, and editorial metadata.
- `guided-journey`: Start or resume a guest journey, progress through ordered stops, submit observation answers, and complete the route.
- `experience-client`: Deliver the Flutter user experience, local demo mode, polished motion, resilient loading/error states, and accessible controls.
- `platform-runtime`: Run the Flask API and MySQL datastore locally with deterministic seed data, health checks, migrations, and tests.

### Modified Capabilities

None.

## Impact

- New `backend/` Flask application, migrations, seed command, and test suite.
- New `mobile/` Flutter application and bundled visual assets.
- New root Docker Compose and environment templates.
- New public `/api/v1` JSON contract consumed by the mobile repository layer.
- MySQL becomes the production-like persistence target; SQLite remains available for fast tests and zero-setup backend inspection.
