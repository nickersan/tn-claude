# tn-user-service Specification

## Purpose
Holds a user's profile and the identifiers (email, phone) linked to it — this
service is the identity anchor: its own id is the stable id used everywhere
once a user is authenticated, including as the subject `tn-auth-service` mints
a session for (see that capability's Purpose — `tn-auth-service` itself has no
concept of an identifier or an account; resolving one to a stable id is
entirely this service's job). Deliberately does not issue or verify tokens —
that separation is intentional and retained by `tn-auth-service`.

## Requirements

### Requirement: A user has at most one identifier of each type
The system SHALL store at most one email address and at most one phone number
per user, each individually unique across every user — no two users may share
the same email, and no two users may share the same phone number.

#### Scenario: A user is created with one identifier
- **WHEN** a caller creates a user with an email address
- **THEN** the system stores that email address against the new user, and no
  other user may be created or updated with the same email address

#### Scenario: A second identifier of a different type coexists
- **WHEN** a user that already has an email address linked has a phone number
  linked to it
- **THEN** the system stores both, and either can subsequently be used to find
  that same user

### Requirement: Profile details are optional beyond an identifier
The system SHALL allow a profile to exist with only one identifier set; name
fields and the other identifier type are optional and may be supplied later.

#### Scenario: Profile created with a single identifier only
- **WHEN** a caller creates a profile supplying only an email address
- **THEN** the system creates the profile without requiring a name or a phone
  number

### Requirement: Find-or-create by identifier is a single safe operation
The system SHALL provide a find-or-create operation that, given an identifier
type and value, returns the existing user for it or creates one if none
exists, and SHALL guarantee at most one user is ever created for a given
identifier value even when the operation is called concurrently for the same
new value (the system runs as multiple instances in any real environment, so
this guarantee SHALL hold across instances, not just within one process).

#### Scenario: Creates when absent
- **WHEN** a caller invokes find-or-create for an identifier value with no
  existing user
- **THEN** the system creates a user with that identifier and returns it

#### Scenario: Returns the existing user when present
- **WHEN** a caller invokes find-or-create for an identifier value that
  already belongs to a user
- **THEN** the system returns the existing user without creating another one

#### Scenario: Concurrent calls for the same new identifier value create exactly one user
- **WHEN** two or more calls invoke find-or-create for the same identifier
  value at the same time, and no user exists for it beforehand
- **THEN** exactly one user is created, and every caller receives that same
  user

### Requirement: A user is created or updated by supplying its full representation
The system SHALL accept the same shape — email, phone, and name fields,
without an id — for both creating a new user and replacing an existing one's
profile. Updating a user's profile SHALL be permitted to change its email
and/or phone, including adding a second identifier alongside an existing one;
the system does not treat an identifier as immutable once set. The system
does not itself verify that a supplied identifier belongs to the caller — the
caller is trusted to have already verified it (e.g. via
`tn-temporary-token-service`'s OTP flow) before requesting the create or
update.

#### Scenario: Adding a second identifier via update
- **WHEN** a caller updates an existing user, supplying both the identifier it
  already has and a second identifier of the other type
- **THEN** the system stores both, and either can subsequently be used to find
  that same user

#### Scenario: Changing an existing identifier via update
- **WHEN** a caller updates an existing user, supplying a different value for
  an identifier type it already has
- **THEN** the system replaces the existing value with the supplied one

#### Scenario: A value already belonging to a different user is rejected
- **WHEN** a caller creates or updates a user supplying an email address or
  phone number that already belongs to a different user
- **THEN** the system rejects the request and does not change either user's
  stored identifiers

### Requirement: A user must have at least one identifier
The system SHALL reject creating or updating a user such that it would have
neither an email address nor a phone number.

#### Scenario: Creating a user without any identifier
- **WHEN** a caller creates a user supplying neither an email address nor a
  phone number
- **THEN** the system rejects the request

#### Scenario: Updating a user to remove its only identifier
- **WHEN** a caller updates a user, supplying neither an email address nor a
  phone number where the user previously had at least one
- **THEN** the system rejects the request and leaves the user's stored
  identifiers unchanged

### Requirement: This service does not issue or verify tokens
The system SHALL NOT issue, refresh, or verify a session token — that is
`tn-auth-service`'s responsibility, not this service's.

#### Scenario: Profile operations never return a token
- **WHEN** a caller creates, reads, or updates a user
- **THEN** the response contains profile data only, never a token

### Requirement: User records use TSID primary keys
The system SHALL assign each user record's primary key as a TSID, not a
database-sequence value, per `tn-claude/standards/java/identifiers.md`. This id
is the stable id used everywhere once a user is authenticated, including the
subject id passed to `tn-auth-service.generate()`.

#### Scenario: New user gets a TSID
- **WHEN** the system creates a user
- **THEN** the record's primary key is a TSID value, not a sequence-issued one

### Requirement: Structured, masked logging
The system SHALL log profile creation, lookup, and update events as
structured (JSON) log entries, per `tn-claude/standards/logging/README.md`,
and SHALL NOT log an email address or phone number value unmasked.

#### Scenario: Profile events are logged without leaking an identifier value
- **WHEN** the system creates, finds, or updates a user
- **THEN** it emits a structured log entry describing the event, and that
  entry does not contain the unmasked email address or phone number value
