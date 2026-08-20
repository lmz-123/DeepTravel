## Purpose

Let travelers choose which supported city they want to explore while making Shenzhen the initial MVP market without removing access to Shanghai content.

## ADDED Requirements

### Requirement: Shenzhen is the default selected city

The client SHALL select Shenzhen when discovery is first opened and SHALL request Shenzhen's featured route.

#### Scenario: First launch

- **WHEN** the user opens discovery without an existing in-memory city selection
- **THEN** Shenzhen is displayed as selected
- **AND** Shenzhen route content is requested from the backend

### Requirement: User can switch supported cities

The client SHALL present backend-provided supported cities and SHALL reload discovery content for the city selected by the user.

#### Scenario: Switch from Shenzhen to Shanghai

- **WHEN** the user selects Shanghai from the city selector
- **THEN** the selected-city label changes to Shanghai
- **AND** the featured route changes to Shanghai content without restarting the app

#### Scenario: City route loading fails

- **WHEN** the backend cannot return routes for the selected city
- **THEN** the client shows a recoverable error for that city
- **AND** keeps the user's selected-city state
