## Purpose

Issues and refreshes the JWT access/refresh token pair that identifies a session
throughout a system, for an opaque subject id and a caller-supplied set of
claims — so any project can obtain and refresh a session without implementing
token issuance itself. This service has no concept of an identifier, an
account, or a user: it does not resolve, store, or interpret what `id` means,
or what any claim means. Resolving an identifier (email, phone) to a stable id
is entirely another service's responsibility — today, `tn-user-service`'s (see
that capability's Purpose). A system's login flow composes both: resolve the
identifier via `tn-user-service` first, then mint a session via this service.

## ADDED Requirements

### Requirement: Issue a session for a given id and claims
The system SHALL mint a JWT access token and a JWT refresh token for a given
subject id and a caller-supplied list of claims. The issued tokens' subject
SHALL be that id, and their payload SHALL carry every supplied claim.

#### Scenario: Session issued for an id and claims
- **WHEN** a caller requests a token pair for an id and a list of claims
- **THEN** the system returns a valid access/refresh token pair whose subject
  is that id and whose payload carries every supplied claim

### Requirement: This service does not resolve, store, or interpret identifiers
The system SHALL NOT look up, validate, or persist any identifier, account, or
user record. The `id` a caller supplies is opaque to this service — it neither
creates nor resolves it.

#### Scenario: An unrecognised id is accepted at face value
- **WHEN** a caller requests a token pair for an id this service has never
  seen before
- **THEN** the system mints a valid token pair for it without attempting to
  look up, validate, or create any record for that id beyond what is needed to
  manage the resulting refresh token

### Requirement: Claims are opaque name/value pairs
The system SHALL accept claims as a list of name/value pairs and SHALL NOT
require, validate, or interpret their names or values — their meaning is
entirely the calling system's concern.

#### Scenario: Arbitrary claim names are carried through unchanged
- **WHEN** a caller supplies claims with names this service has never been
  told the meaning of
- **THEN** the issued token carries them exactly as supplied

### Requirement: Refresh preserves the original id and claims
The system SHALL issue a new access token for a valid, unexpired refresh token,
carrying the same subject id and the same claims the original session had,
without requiring re-verification of whatever those claims describe.

#### Scenario: Valid refresh token
- **WHEN** a caller presents a refresh token that matches the most recently
  issued one for its subject and has not expired
- **THEN** the system returns a new access token carrying the same subject id
  and the same claims as the original session

#### Scenario: Unrecognised or superseded refresh token
- **WHEN** a caller presents a refresh token that does not match the most
  recently issued one for its subject, or that fails signature verification
- **THEN** the system rejects the request and does not issue a new access
  token

### Requirement: Token/session records are separate from profile and identity data
The system SHALL NOT require or store any identifier, account, or user profile
data — that is entirely another service's responsibility (today,
`tn-user-service`'s).

#### Scenario: Session issued without profile or identity data
- **WHEN** a caller requests or refreshes a token pair
- **THEN** the system does so without requiring, storing, or returning any
  identifier, account, or profile field

### Requirement: Refresh token records use TSID primary keys
The system SHALL assign each refresh token record's primary key as a TSID, not
a database-sequence value, per `tn-claude/standards/java/identifiers.md`.

#### Scenario: New refresh token record gets a TSID
- **WHEN** the system issues a new session
- **THEN** the refresh token record's primary key is a TSID value, not a
  sequence-issued one

### Requirement: Structured logging masks the token and every claim value
The system SHALL log token issuance and refresh events as structured (JSON)
log entries, per `tn-claude/standards/logging/README.md`, and SHALL NOT log an
access token, refresh token, or any claim *value* unmasked — this service
cannot know which claim values are sensitive, so it treats all of them as if
they were. Claim *names* and the subject id are not masked.

#### Scenario: Session issuance is logged without leaking the token or claim values
- **WHEN** the system issues or refreshes a token pair
- **THEN** it emits a structured log entry describing the event, and that
  entry does not contain the unmasked access or refresh token value, or the
  unmasked value of any claim
