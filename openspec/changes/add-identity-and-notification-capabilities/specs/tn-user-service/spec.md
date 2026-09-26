## Purpose

Holds a user's profile, keyed by the stable account id `tn-auth-service`
establishes (see that capability's Purpose — an account is the anchor identity,
one or more verified identifiers link to it), so other services have one place
to read/write profile data. Deliberately does not issue or verify tokens, does
not store an identifier value, and does not know how many identifiers an
account has linked — that's `tn-auth-service`'s responsibility, not this
service's.

## ADDED Requirements

### Requirement: Profile keyed by account id
The system SHALL store a user profile keyed by an account id (`tn-auth-service`'s
stable, per-account identifier) rather than by an identifier's type and value.

#### Scenario: Create a profile for an account
- **WHEN** a caller creates a profile for an account id
- **THEN** the system stores the profile keyed by that account id

### Requirement: One profile per account
The system SHALL enforce that each account id maps to at most one profile.

#### Scenario: Duplicate account rejected
- **WHEN** a caller attempts to create a second profile for an account id that
  already has one
- **THEN** the system rejects the request and does not create a duplicate profile

### Requirement: Profile details are optional beyond the account id
The system SHALL allow a profile to exist with only its account id set; name
fields are optional and may be supplied later.

#### Scenario: Profile created with account id only
- **WHEN** a caller creates a profile supplying only the account id
- **THEN** the system creates the profile without requiring a name

### Requirement: Find-or-create by account id is a single safe operation
The system SHALL provide a find-or-create operation that, given an account id,
returns the existing profile for it or creates one if none exists, and SHALL
guarantee at most one profile is ever created for a given account id even when
the operation is called concurrently for the same new account id (the system
runs as multiple instances in any real environment, so this guarantee SHALL
hold across instances, not just within one process).

#### Scenario: Creates when absent
- **WHEN** a caller invokes find-or-create for an account id with no existing
  profile
- **THEN** the system creates a profile for that account id and returns it

#### Scenario: Returns the existing profile when present
- **WHEN** a caller invokes find-or-create for an account id that already has a
  profile
- **THEN** the system returns the existing profile without creating another one

#### Scenario: Concurrent calls for the same new account id create exactly one profile
- **WHEN** two or more calls invoke find-or-create for the same account id at
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

### Requirement: Structured logging
The system SHALL log profile creation and lookup events as structured (JSON) log
entries, per `tn-claude/standards/logging/README.md`. Unlike `tn-auth-service`
and `tn-notification-service`, this service holds no identifier value or token
to mask — an account id carries no more sensitivity than any other internal id
in this layer — so there is nothing beyond the general standard to call out
here.

#### Scenario: Profile creation is logged
- **WHEN** the system creates or looks up a profile
- **THEN** it emits a structured log entry describing the event
