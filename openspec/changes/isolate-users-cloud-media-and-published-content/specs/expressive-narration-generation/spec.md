## Purpose

Let editors replace flat preview audio with expressive, reviewable Mandarin narration generated from curated preset voices and stored as versioned route media.

## ADDED Requirements

### Requirement: Narration generation is provider-replaceable
The independent admin SHALL generate narration through a provider-neutral contract. The MVP SHALL support MiniMax `speech-2.8-hd`, while local and automated-test profiles use a deterministic fake or manual-upload path without paid credentials.

#### Scenario: Provider is not configured
- **WHEN** an operator opens narration controls without a provider key
- **THEN** the admin reports generation unavailable while retaining transcript editing and manual audio upload

#### Scenario: Provider request fails
- **WHEN** synthesis times out or returns an error
- **THEN** the current approved narration remains referenced and no partial media record is published

### Requirement: Operators can audition curated expressive voices
For a fragment transcript, the admin SHALL allow generation of at least three previews varying curated preset voice and/or restrained emotional direction, with configurable pace, pitch and pronunciation entries. Preview generation MUST NOT change published audio.

#### Scenario: Editor compares previews
- **WHEN** three generation variants complete
- **THEN** each is independently playable and labeled with provider, model, voice, emotion, pace and generation time

#### Scenario: Historical name needs pronunciation control
- **WHEN** the transcript contains a configured pronunciation entry
- **THEN** the provider request applies that pronunciation without changing the visible transcript

### Requirement: Approved narration is versioned and cloud-hosted
Approving a preview SHALL upload the normalized audio to object storage, create or update a media record with generation metadata, and bind the fragment to that version only when transcript and script versions match.

#### Scenario: Operator approves a preview
- **WHEN** the preview transcript hash matches the current fragment script
- **THEN** its OSS URL, MIME type, size, checksum, model, voice and expressive settings become the fragment's approved narration version

#### Scenario: Transcript changed after preview
- **WHEN** the fragment transcript no longer matches the preview's transcript hash
- **THEN** approval is rejected and a new preview is required

### Requirement: Expressive direction remains suitable for factual travel narration
Generated narration SHALL favor calm, reflective, documentary or story-like delivery and MUST preserve every factual statement in the approved transcript. Emotional settings SHALL not insert fictional dialogue, unsupported certainty or melodramatic sound effects.

#### Scenario: Generated words differ from transcript
- **WHEN** the generation result cannot be traced to the exact approved transcript and provider settings
- **THEN** it cannot be approved for publication

