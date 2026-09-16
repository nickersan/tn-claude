## Purpose

Issues and refreshes the JWT access/refresh token pair that identifies a user
throughout a system, for a verified identifier — so any project can obtain and
refresh a session without implementing token issuance itself. Deliberately owns
only the token/session record, not the user's profile: that separation is
intentional and retained by `tn-user-service` (see that capability's Purpose).

## ADDED Requirements

### Requirement: Issue a session for a verified identifier
The system SHALL mint a JWT access token and a JWT refresh token for a given
identifier (email address or phone number), creating a record for that identifier
on first use.

#### Scenario: First session for a new identifier
- **WHEN** a caller requests a token pair for an identifier that has no existing
  record
- **THEN** the system creates a record for that identifier and returns a valid
  access/refresh token pair

#### Scenario: Session for a known identifier
- **WHEN** a caller requests a token pair for an identifier that already has a
  record
- **THEN** the system returns a valid access/refresh token pair without creating a
  duplicate record

### Requirement: Refresh an access token
The system SHALL issue a new access token for a valid, unexpired refresh token
without requiring the identifier to be re-verified.

#### Scenario: Valid refresh token
- **WHEN** a caller presents a refresh token that matches the most recently issued
  one for its identifier and has not expired
- **THEN** the system returns a new access token

#### Scenario: Unrecognised or superseded refresh token
- **WHEN** a caller presents a refresh token that does not match the most recently
  issued one for its identifier, or that fails signature verification
- **THEN** the system rejects the request and does not issue a new access token

### Requirement: Identifier type is email or phone
The system SHALL accept either an email address or a phone number as the
identifier, and SHALL carry the identifier's type and value as claims in the issued
access token so a resource server can identify the user without a further lookup.

#### Scenario: Email identifier
- **WHEN** a caller requests a token pair for an email address
- **THEN** the issued access token carries `identifierType = EMAIL` and the email
  address

#### Scenario: Phone identifier
- **WHEN** a caller requests a token pair for a phone number
- **THEN** the issued access token carries `identifierType = PHONE` and the phone
  number

### Requirement: Token/session records are separate from profile data
The system SHALL NOT require or store user profile details (name or any field
beyond the identifier itself) — profile data is `tn-user-service`'s responsibility,
not this service's.

#### Scenario: Session issued without profile data
- **WHEN** a caller requests or refreshes a token pair
- **THEN** the system does so without requiring, storing, or returning any profile
  field

### Requirement: Identifier records use TSID primary keys
The system SHALL assign each identifier record's primary key as a TSID, not a
database-sequence value, per `tn-claude/standards/java/identifiers.md`.

#### Scenario: New identifier record gets a TSID
- **WHEN** the system creates a record for a previously unseen identifier
- **THEN** the record's primary key is a TSID value, not a sequence-issued one

### Requirement: Structured, masked logging
The system SHALL log token issuance and refresh events as structured (JSON) log
entries, per `tn-claude/standards/logging/README.md`, and SHALL NOT log an access
token, refresh token, or full identifier value unmasked.

#### Scenario: Session issuance is logged without leaking the token
- **WHEN** the system issues or refreshes a token pair
- **THEN** it emits a structured log entry describing the event, and that entry
  does not contain the unmasked access or refresh token value
