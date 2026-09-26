## Purpose

Issues and refreshes the JWT access/refresh token pair that identifies a
session throughout a system, for an opaque subject id — so any project can
obtain and refresh a session without implementing token issuance itself. This
service has no concept of an identifier, an account, or a user: it does not
resolve, store, or interpret what the subject id means, and it accepts no
other claim from a caller — every claim beyond the subject (issuer, issued-at,
expiration, and a fresh token id) is this service's own to add. Resolving an
identifier (email, phone) to a stable id is entirely another service's
responsibility — today, `tn-user-service`'s (see that capability's Purpose).
A system's login flow composes both: resolve the identifier via
`tn-user-service` first, then mint a session via this service.

## ADDED Requirements

### Requirement: Issue a session for a given subject id
The system SHALL mint a JWT access token and a JWT refresh token for a given
subject id. The issued tokens' subject SHALL be that id.

#### Scenario: Session issued for a subject id
- **WHEN** a caller requests a token pair for a subject id
- **THEN** the system returns a valid access/refresh token pair whose subject
  is that id

### Requirement: This service does not resolve, store, or interpret identifiers
The system SHALL NOT look up, validate, or persist any identifier, account, or
user record. The subject id a caller supplies is opaque to this service — it
neither creates nor resolves it.

#### Scenario: An unrecognised id is accepted at face value
- **WHEN** a caller requests a token pair for a subject id this service has
  never seen before
- **THEN** the system mints a valid token pair for it without attempting to
  look up, validate, or create any record for that id beyond what is needed to
  manage the resulting refresh token

### Requirement: The system does not accept caller-supplied claims
The system SHALL accept only a subject id from the caller; every other claim
in the issued tokens is this service's own to determine, not the caller's.

#### Scenario: A caller cannot influence any claim beyond the subject
- **WHEN** a caller requests a token pair for a subject id
- **THEN** the issued tokens carry only this service's own claims (issuer,
  issued-at, expiration, and a token id) alongside that subject — nothing the
  caller supplied beyond the id itself

### Requirement: Every issued token gets its own fresh token id
The system SHALL assign each issued token (access or refresh) its own freshly
generated TSID as its `jti` (JWT ID) claim, generated when that specific token
is minted. Access and refresh tokens issued together SHALL each get their own
distinct token id — they SHALL NOT share one — and a refreshed access token
SHALL get a new token id of its own, not the one carried by the refresh token
that produced it.

#### Scenario: Access and refresh tokens issued together get different token ids
- **WHEN** the system issues a token pair
- **THEN** the access token's `jti` claim and the refresh token's `jti` claim
  are different TSID values

#### Scenario: A refreshed access token gets a new token id
- **WHEN** the system issues a new access token for a valid refresh token
- **THEN** the new access token's `jti` claim is a freshly generated TSID,
  different from the refresh token's own `jti`

### Requirement: Refresh preserves the original subject id
The system SHALL issue a new access token for a valid, unexpired refresh
token, carrying the same subject id the original session had.

#### Scenario: Valid refresh token
- **WHEN** a caller presents a refresh token that matches the most recently
  issued one for its subject and has not expired
- **THEN** the system returns a new access token carrying the same subject id
  as the original session

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
a database-sequence value, per `tn-claude/standards/java/identifiers.md`. This
is the refresh token's own database row id, separate from the `jti` claim
embedded in the JWT it stores.

#### Scenario: New refresh token record gets a TSID
- **WHEN** the system issues a new session
- **THEN** the refresh token record's primary key is a TSID value, not a
  sequence-issued one

### Requirement: Structured logging masks the token
The system SHALL log token issuance and refresh events as structured (JSON)
log entries, per `tn-claude/standards/logging/README.md`, and SHALL NOT log an
access or refresh token value unmasked. The subject id is not masked — it is
an opaque internal id, no more sensitive than any other in this layer.

#### Scenario: Session issuance is logged without leaking the token
- **WHEN** the system issues or refreshes a token pair
- **THEN** it emits a structured log entry describing the event, and that
  entry does not contain the unmasked access or refresh token value
