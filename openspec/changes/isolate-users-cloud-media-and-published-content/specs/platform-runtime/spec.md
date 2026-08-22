## MODIFIED Requirements

### Requirement: Guest authorization
The system SHALL issue expiring bearer tokens for authenticated users, SHALL require the token's user principal for every journey and private evidence resource, and SHALL expose test-account authorization only behind an explicit deployment flag.

#### Scenario: Missing guest token
- **WHEN** a client accesses a journey endpoint without a valid guest token
- **THEN** the system returns an unauthorized structured error

#### Scenario: Same user logs in again
- **WHEN** a known user authenticates after its previous token expires
- **THEN** the new token resolves to the same user principal and preserves its journeys

#### Scenario: Different user requests a private resource
- **WHEN** one user presents its valid token for another user's journey or evidence
- **THEN** the system returns not found without disclosing ownership metadata

#### Scenario: Test authorization is disabled
- **WHEN** the production profile receives a test-login request
- **THEN** the route behaves as unavailable and no authorization is issued
