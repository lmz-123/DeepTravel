## ADDED Requirements

### Requirement: Scenic cards have one isolated offline-package action

Each scenic-area card SHALL expose exactly one offline-package action at the left side of its bottom information row. The action SHALL use an 18–20 dp icon inside a 44–48 dp touch target, remain clearly separated from the right-side “打开城市手册” action, and provide an accessible name or tooltip.

#### Scenario: Traveler taps the download icon

- **WHEN** the traveler taps the scenic card's offline-package icon
- **THEN** the client starts or retries only that scenic route's package download
- **AND** it does not open route detail or begin exploration

#### Scenario: Card is browsed

- **WHEN** the traveler taps the card body or the right-side “打开城市手册” action
- **THEN** the client performs the existing route browsing behavior
- **AND** it does not implicitly start a package download

### Requirement: Offline-package lifecycle is distinguishable

The scenic card SHALL communicate idle, downloading/progress, complete, stale, and failed/retry package states without covering the scenic image.

#### Scenario: Download stays on the card

- **WHEN** a traveler starts an offline-package download
- **THEN** the footer-left action displays circular progress in place
- **AND** the client does not open a dialog, sheet, or download-detail page

#### Scenario: Download completes

- **WHEN** package validation and installation complete
- **THEN** the footer-left action shows completion
- **AND** its semantics or tooltip identifies the installed version and successful integrity check

#### Scenario: Download fails

- **WHEN** package fetch, transfer, or validation fails
- **THEN** the footer-left action shows failure and remains enabled for retry

### Requirement: Settings manage scenic offline packages individually

Settings SHALL show the verified scenic offline packages stored on the device and SHALL allow the traveler to remove one selected package without clearing other installed packages.

#### Scenario: Traveler reviews offline cache

- **WHEN** the traveler expands the offline-cache item in Settings
- **THEN** each installed package identifies its city, scenic route, version, and cached audio count

#### Scenario: Traveler clears one package

- **WHEN** the traveler confirms removal of one installed package
- **THEN** that package metadata and its unshared prepared audio are removed
- **AND** other installed packages remain available

### Requirement: Discovery prioritizes scenic selection before city stories

The discovery page SHALL place city-story modules after the scenic-area selection section and SHALL NOT show a “继续我的足迹” resume card. Footprints remain accessible from the traveler navigation.

#### Scenario: Discovery content is composed

- **WHEN** the discovery page has both scenic routes and city stories
- **THEN** scenic-area selection appears before city stories
- **AND** no footprint-resume card appears on the page
