## Context

The workspace starts without application code. The MVP spans a mobile client, HTTP API, persistence, seed editorial content, and local orchestration. See `proposal.md` for motivation and the capability specs for observable behavior. The system must run without map or AI credentials, while leaving clean seams for production location, media, and content systems.

## Goals / Non-Goals

**Goals:**

- Deliver one end-to-end vertical slice with strict module boundaries.
- Keep business rules independent from Flask, SQLAlchemy, Flutter widgets, and Dio.
- Make MySQL the production-like store while retaining SQLite for fast tests.
- Let Flutter switch between in-memory demo and REST implementations through dependency injection.
- Make content and journey modules independently extractable later.

**Non-Goals:**

- Distributed deployment, event buses, Kubernetes, background geofencing, a CMS, and production media delivery.
- Exact offline navigation or automatic audio geofencing in the foreground/background.

## Decisions

### Modular monolith with ports at persistence boundaries

The Flask code is separated into presentation, application, domain, infrastructure, and bootstrap packages. Application use cases depend on repository protocols; SQLAlchemy implementations point inward. Catalog and Journey exchange identifiers/DTOs only.

Alternative: separate microservices now. Rejected because deployment, failure handling, and data consistency would obscure MVP learning without a demonstrated scaling need.

### Explicit journey state machine

Journey state is represented by `active|completed`; per-stop state is derived from arrival and answer records. Application services enforce ordered arrival, answer, and advancement inside database transactions.

Alternative: let the mobile client post an arbitrary progress number. Rejected because it permits invalid and untraceable states.

### Anonymous JWT session

`POST /sessions/guest` creates a random session record and returns an expiring signed token containing only the session ID. Journey queries always scope by that ID.

Alternative: no authorization. Rejected because journey IDs would become bearer secrets and progress could be read or changed by guessing identifiers.

### REST DTOs and stable error envelope

The API uses `/api/v1`, snake_case JSON, ISO-8601 UTC timestamps, and `{error:{code,message,details}}`. Presentation serializers prevent ORM models from escaping the infrastructure layer.

Alternative: GraphQL. Rejected because the small, sequential interaction surface benefits from simpler HTTP caching, tests, and operational tooling.

### Flutter feature-first MVVM with Riverpod

Each feature contains domain, data, and presentation code. Views render state and forward gestures; ViewModels coordinate repositories. Repository providers select `DemoExperienceRepository` or `ApiExperienceRepository` from a compile-time environment flag.

Alternative: global service locator and stateful screens. Rejected because it couples network/storage and business state to widgets, making later feature extraction expensive.

### Keyless map presentation

The MVP renders a designed route canvas from coordinates and supports an optional OpenStreetMap-backed screen later. The default experience needs no Google/Apple map key and demo mode simulates arrival explicitly.

Alternative: require a commercial map SDK on first run. Rejected because API-key setup would prevent deterministic evaluation and is unnecessary for validating the content loop.

### Bundled editorial assets and demo copy

Two generated editorial photographs are bundled with the application. Seed history copy carries `content_status=demo_unverified`, and the client shows the status. No remote image dependency is required.

## Failure Behavior

- Validation, authentication, not-found, state conflict, and location distance failures map to distinct 4xx codes.
- Unexpected failures use a generic 500 message and preserve details only in server logs.
- API-mode mobile failures retain the last state and expose retry; demo mode never requires network.
- Repeated start and answer requests are idempotent.

## Migration Seams

- Catalog repositories can be replaced by a CMS or remote catalog service without changing use cases.
- Journey repositories can move to a separate database/service because APIs use route and stop IDs rather than ORM relations outside infrastructure.
- Audio URLs can move from seed placeholders to object storage/CDN without schema changes.
- Demo location service can be replaced by platform geolocation behind a client service interface.

## Risks / Trade-offs

- [Seed historical content may be mistaken for authoritative copy] → mark every route response and relevant screen as demonstration content requiring review.
- [Python 3.14 may expose dependency lag] → containerize on Python 3.13 and keep local requirements version-bounded.
- [MySQL is slower for tests] → use SQLite for unit/API tests and run a Compose smoke test against MySQL.
- [No real audio file weakens immersion] → implement complete player UI and text alternative now; expose stable `audio_url` for later licensed narration.
- [Manual demo arrival differs from real GPS] → keep server distance validation and a location service seam, but make demo arrival explicitly labeled.

## Migration Plan

1. Start MySQL and API through Compose; migrations create empty schema.
2. Run the idempotent seed command to insert the Shanghai route.
3. Launch Flutter in demo mode for zero-setup evaluation or API mode against local `/api/v1`.
4. Rollback is limited to stopping containers and removing the isolated development volume; no existing user data is migrated.

## Open Questions

- Select a licensed narration voice and audio hosting provider before a public pilot.
- Select a production map provider after target geography, cost, and mainland China coordinate requirements are confirmed.
