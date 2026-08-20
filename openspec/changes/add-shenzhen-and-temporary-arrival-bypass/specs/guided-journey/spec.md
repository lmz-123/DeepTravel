## MODIFIED Requirements

### Requirement: Arrival confirmation

The system SHALL accept arrival when submitted coordinates are within the stop radius and SHALL accept an explicit demo-arrival request when the temporary deployment switch is enabled. The shipped MVP client SHALL use the explicit demo-arrival request and SHALL NOT require device coordinates during this temporary phase.

#### Scenario: Location is near the stop

- **WHEN** the guest submits coordinates within the current stop arrival radius
- **THEN** the current stop becomes arrived

#### Scenario: Location is too far away

- **WHEN** the guest submits coordinates outside the current stop arrival radius
- **THEN** the system rejects arrival and returns the calculated distance

#### Scenario: Demo arrival is disabled

- **WHEN** the guest requests demo arrival while demo arrival is disabled
- **THEN** the system rejects the request

#### Scenario: Temporary tap-to-arrive is enabled

- **WHEN** the user taps the arrival action and the backend temporary bypass is enabled
- **THEN** the client sends an explicit demo-arrival request
- **AND** the backend marks the current stop arrived without device coordinates
