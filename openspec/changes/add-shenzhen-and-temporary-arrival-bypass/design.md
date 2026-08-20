## Context

See `proposal.md`. The backend already exposes city-scoped route discovery and a configurable demo-arrival branch, but the seed is effectively Shanghai-only and the Flutter repository hardcodes Shanghai while always requesting device location.

## Goals / Non-Goals

**Goals:**

- Extend the existing modular catalog without a new service or API version.
- Make city selection reactive and testable above the presentation layer.
- Keep the arrival bypass explicit and reversible at one repository/config seam.
- Keep all new route media in backend storage and metadata in the database.

**Non-Goals:**

- Persisted city preferences, GPS city detection, route search, or a CMS.
- Deleting server-side coordinate validation.

## Decisions

### Seed Shenzhen through the existing catalog model

Add stable Shenzhen city/route/stop IDs and idempotent upsert-style seed helpers. This uses the same tables and API contracts as Shanghai, avoiding city-specific endpoints or schema changes. New Shenzhen imagery is registered in `media_assets` and served through the existing media endpoint.

### Make city an explicit repository input

Add a lightweight city DTO and repository methods for listing cities and loading a featured route by city slug. A Riverpod selected-city provider defaults to `shenzhen`; discovery watches it so route state naturally refreshes. The UI selector consumes backend city data rather than a client-maintained city list.

### Reuse the existing explicit demo-arrival contract

Change the mobile arrival repository method back to a coordinate-free call that sends `{ "demo": true }`. Remove the geolocation package, service, and mobile permissions. Enable `ALLOW_DEMO_ARRIVAL` in MVP configuration. Coordinate handling remains intact in Flask so restoration later requires changing the client contract and one environment flag, not rewriting journey rules.

### Preserve recoverable failures

If city loading fails, discovery retains the selected slug and exposes its existing retry state. If demo arrival is disabled unexpectedly, the backend's structured error is shown through the existing journey error presentation.

## Risks / Trade-offs

- [Arrival can be spoofed during MVP testing] → Keep the bypass explicit, configuration-gated, and documented as temporary.
- [Seed copy may be mistaken for verified history] → Mark Shenzhen content `demo_unverified` and keep wording observation-led.
- [An existing database may skip new seed data] → Replace the current early-return seed flow with per-city/media reconciliation.

## Migration Plan

1. Deploy code and run the existing Alembic/seed startup command; no new schema migration is required.
2. Verify `/cities`, Shenzhen route detail, and Shenzhen media URLs before distributing the client.
3. Roll back by disabling `ALLOW_DEMO_ARRIVAL`; seeded Shenzhen rows can remain without affecting Shanghai.
