## ADDED Requirements

### Requirement: Offline package availability does not change route browsing semantics

Published scenic cards SHALL retain their existing order, route ownership, and navigation behavior while adding route-scoped offline-package status. When discovery cannot reach the API, complete verified packages MAY supply their stored city and route presentation metadata.

#### Scenario: Online discovery loads

- **WHEN** published routes are available from the API
- **THEN** the client uses the existing city selection and ranking behavior
- **AND** package state changes do not reorder or open cards

#### Scenario: Offline cold start has downloaded packages

- **WHEN** discovery starts without network access and at least one complete verified package is stored
- **THEN** the client presents the stored city and scenic route cards as offline-ready
- **AND** it does not present failed or incomplete packages as usable routes
