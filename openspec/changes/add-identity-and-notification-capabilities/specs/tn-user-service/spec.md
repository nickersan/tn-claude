## Purpose

Holds a user's profile, keyed by the identifier (email or phone) that was verified
to create the account, so other services have one place to read/write profile data.
Deliberately does not issue or verify tokens — that separation is intentional and
retained by `tn-auth-service` (see that capability's Purpose).

## ADDED Requirements

### Requirement: Profile keyed by a generic identifier
The system SHALL store a user profile keyed by an identifier (type: email or phone,
plus value), rather than by email alone.

#### Scenario: Create a profile for an email identifier
- **WHEN** a caller creates a profile for an email address
- **THEN** the system stores it with `identifierType = EMAIL` and validates the
  value as an email address

#### Scenario: Create a profile for a phone identifier
- **WHEN** a caller creates a profile for a phone number
- **THEN** the system stores it with `identifierType = PHONE`

### Requirement: One account per identifier
The system SHALL enforce that each (identifier type, identifier value) pair maps to
at most one profile.

#### Scenario: Duplicate identifier rejected
- **WHEN** a caller attempts to create a second profile for an identifier type and
  value that already has one
- **THEN** the system rejects the request and does not create a duplicate profile

### Requirement: Profile details are optional beyond the identifier
The system SHALL allow a profile to exist with only its identifier set; name fields
are optional and may be supplied later.

#### Scenario: Profile created with identifier only
- **WHEN** a caller creates a profile supplying only the identifier
- **THEN** the system creates the profile without requiring a name

### Requirement: Find-or-create by identifier is a single safe operation
The system SHALL provide a find-or-create operation that, given an identifier,
returns the existing profile for it or creates one if none exists, and SHALL
guarantee at most one profile is ever created for a given identifier even when
the operation is called concurrently for the same new identifier (the system
runs as multiple instances in any real environment, so this guarantee SHALL
hold across instances, not just within one process).

#### Scenario: Creates when absent
- **WHEN** a caller invokes find-or-create for an identifier with no existing
  profile
- **THEN** the system creates a profile for that identifier and returns it

#### Scenario: Returns the existing profile when present
- **WHEN** a caller invokes find-or-create for an identifier that already has a
  profile
- **THEN** the system returns the existing profile without creating another one

#### Scenario: Concurrent calls for the same new identifier create exactly one profile
- **WHEN** two or more calls invoke find-or-create for the same identifier at
  the same time, and no profile exists for it beforehand
- **THEN** exactly one profile is created, and every caller receives that same
  profile

### Requirement: This service does not issue or verify tokens
The system SHALL NOT issue, refresh, or verify a session token — that is
`tn-auth-service`'s responsibility, not this service's.

#### Scenario: Profile operations never return a token
- **WHEN** a caller creates, reads, or updates a profile
- **THEN** the response contains profile data only, never a token

### Requirement: Profile records use TSID primary keys
The system SHALL assign each profile record's primary key as a TSID, not a
database-sequence value, per `tn-claude/standards/java/identifiers.md`.

#### Scenario: New profile gets a TSID
- **WHEN** the system creates a profile
- **THEN** the record's primary key is a TSID value, not a sequence-issued one

### Requirement: Structured, masked logging
The system SHALL log profile creation and lookup events as structured (JSON) log
entries, per `tn-claude/standards/logging/README.md`, and SHALL NOT log a full
identifier value unmasked.

#### Scenario: Profile creation is logged without leaking the identifier
- **WHEN** the system creates or looks up a profile
- **THEN** it emits a structured log entry describing the event, and that entry
  does not contain the unmasked identifier value
