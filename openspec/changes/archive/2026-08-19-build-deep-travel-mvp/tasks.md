## 1. Project foundation

- [x] 1.1 Create repository documentation, environment templates, ignore rules, and Docker Compose services; verify Compose configuration renders successfully.
- [x] 1.2 Scaffold the Flask and Flutter projects with explicit layer boundaries; verify dependency direction with imports and static analysis.

## 2. Backend domain and persistence

- [x] 2.1 Implement catalog and journey domain entities, errors, distance calculation, and repository ports; verify journey state rules with unit tests.
- [x] 2.2 Implement SQLAlchemy models, transaction handling, and repository adapters for MySQL/SQLite; verify schema creation and CRUD behavior.
- [x] 2.3 Add deterministic five-stop Shanghai seed content with demo verification metadata; verify repeated seeding is idempotent.

## 3. Backend application and API

- [x] 3.1 Implement guest session issuance and authorization; verify missing, invalid, and valid token scenarios.
- [x] 3.2 Implement route discovery and detail use cases/endpoints; verify ordering, unknown slugs, and metadata contracts.
- [x] 3.3 Implement journey start/resume, arrival, answer, advance, and recap use cases/endpoints; verify a complete five-stop API journey and idempotent requests.
- [x] 3.4 Add health, structured errors, configuration, migrations, and container startup; verify API and database health with the Compose configuration and MySQL smoke runtime.

## 4. Flutter foundation and data layer

- [x] 4.1 Implement the Material 3 design system, routing, shared motion/widgets, and accessibility defaults; verify theme and navigation widget tests.
- [x] 4.2 Implement domain models, repository contracts, REST service, demo service, and Riverpod dependency selection; verify parsing and demo journey tests.

## 5. Flutter experience

- [x] 5.1 Implement discovery and route detail screens with bundled editorial imagery, route metrics, route canvas, and three-tap start; verify widget smoke tests.
- [x] 5.2 Implement the active journey screen with arrival, audio-shaped story controls, observation challenge, answer feedback, and animated progress; verify the five-stop demo flow.
- [x] 5.3 Implement the completion recap and resilient loading/error states; verify completed and retry UI states.

## 6. Delivery verification

- [x] 6.1 Run backend formatting/static checks and the complete test suite; resolve all failures.
- [x] 6.2 Run Flutter formatting, analyze, and tests using an available SDK; resolve all failures or document the exact unavailable tool limitation.
- [x] 6.3 Validate the OpenSpec change strictly, update checked tasks, and document local demo/API startup commands and known MVP limitations.
