## Purpose

Holds a user's profile and the identifiers (email, phone) linked to it — this
service is the identity anchor: its own id is the stable id used everywhere
once a user is authenticated, including as the subject `tn-auth-service` mints
a session for (see that capability's Purpose — `tn-auth-service` itself has no
concept of an identifier or an account; resolving one to a stable id is
entirely this service's job). Deliberately does not issue or verify tokens —
that separation is intentional and retained by `tn-auth-service`.

## ADDED Requirements

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

### Requirement: An existing user can link an additional identifier
The system SHALL allow a further identifier to be linked to an existing user,
but only into that identifier type's empty slot. The system does not itself
verify that the new identifier belongs to that user — the caller is trusted to
have already verified it (e.g. via `tn-temporary-token-service`'s OTP flow)
before requesting the link.

#### Scenario: Linking a new identifier into an empty slot
- **WHEN** a caller requests to link an identifier of a type the user does not
  yet have linked, and that value does not belong to any other user
- **THEN** the system links that identifier to the user, and a subsequent
  find-or-create with it resolves to the same user

#### Scenario: Identifier value already belongs to a different user
- **WHEN** a caller requests to link an identifier value that already belongs
  to a different user
- **THEN** the system rejects the request and does not change either user's
  linked identifiers

#### Scenario: Identifier already linked to the same user
- **WHEN** a caller requests to link an identifier value the user already has
  linked for that type
- **THEN** the system leaves the user's linked identifiers unchanged and does
  not error

#### Scenario: Type slot already holds a different value
- **WHEN** a caller requests to link an identifier of a type the user already
  has linked, and the value differs from the one already linked
- **THEN** the system rejects the request and leaves the user's existing
  identifier of that type unchanged — changing an identifier is a distinct,
  not-yet-specified capability, not what linking provides

### Requirement: This service does not issue or verify tokens
The system SHALL NOT issue, refresh, or verify a session token — that is
`tn-auth-service`'s responsibility, not this service's.

#### Scenario: Profile operations never return a token
- **WHEN** a caller creates, reads, updates, or links an identifier to a user
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
The system SHALL log profile creation, lookup, and identifier-linking events
as structured (JSON) log entries, per `tn-claude/standards/logging/README.md`,
and SHALL NOT log an email address or phone number value unmasked.

#### Scenario: Profile events are logged without leaking an identifier value
- **WHEN** the system creates, finds, or links an identifier to a user
- **THEN** it emits a structured log entry describing the event, and that
  entry does not contain the unmasked email address or phone number value
