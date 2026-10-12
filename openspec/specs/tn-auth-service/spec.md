# tn-auth-service Specification

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

## Requirements

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
  manage the resulting session

### Requirement: The system does not accept caller-supplied claims
The system SHALL accept only a subject id from the caller; every other claim
in the issued tokens is this service's own to determine, not the caller's.

#### Scenario: A caller cannot influence any claim beyond the subject
- **WHEN** a caller requests a token pair for a subject id
- **THEN** the issued tokens carry only this service's own claims (issuer,
  issued-at, expiration, a token id, and the token type) alongside that
  subject — nothing the caller supplied beyond the id itself

### Requirement: Every token states whether it is an access or a refresh token
The system SHALL include a `token_use` claim in every token it issues, with the
value `access` for an access token and `refresh` for a refresh token, so that a
service verifying a token can reject the wrong kind. The claim is this service's
own; a caller cannot supply or influence it.

#### Scenario: Token pair carries both types
- **WHEN** the system issues a token pair
- **THEN** the access token's `token_use` claim is `access` and the refresh
  token's `token_use` claim is `refresh`

#### Scenario: A refreshed access token is an access token
- **WHEN** the system issues a new access token for a valid refresh token
- **THEN** the new access token's `token_use` claim is `access`

#### Scenario: Refresh rejects a token that is not a refresh token
- **WHEN** a caller presents an access token, or any validly signed token whose
  `token_use` claim is not `refresh`, as a refresh token
- **THEN** the system rejects the request and does not issue a new access token

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

### Requirement: Each sign-in is its own session, refreshed until it goes unused
The system SHALL treat each issued token pair as a session of its own, so any
number of sessions for one subject can be refreshed at once. Each refresh SHALL
issue a new access token for the same subject, and a new refresh token that
replaces the one presented and starts a new refresh period. A session ends
only when its refresh token expires unused.

#### Scenario: Valid refresh token
- **WHEN** a caller presents the current refresh token of a session, and it has
  not expired
- **THEN** the system returns a new access token carrying the same subject id,
  and a new refresh token whose expiry is a full refresh period from now

#### Scenario: Another sign-in does not end a session
- **WHEN** a session's subject is issued a second session
- **THEN** the first session's refresh token can still be refreshed

#### Scenario: A session in use outlasts its first refresh period
- **WHEN** a session is refreshed within each refresh period, for longer than
  one period in total
- **THEN** each refresh succeeds

#### Scenario: A session left unused ends
- **WHEN** a caller presents a refresh token that has expired, or fails
  signature verification
- **THEN** the system rejects the request and does not issue a new access
  token

### Requirement: A replaced refresh token is accepted briefly
The system SHALL, for a short grace period after a refresh token is replaced,
answer a refresh with that token by issuing a new access token and returning the
refresh token that replaced it, without replacing it again. Afterwards it SHALL
reject that token, and the session SHALL stay refreshable with its current one.

#### Scenario: A retried refresh converges
- **WHEN** a caller presents a refresh token within the grace period after it
  was replaced
- **THEN** the system returns a new access token and the refresh token that
  replaced it

#### Scenario: A replaced token is rejected after the grace period
- **WHEN** a caller presents a replaced refresh token after the grace period
- **THEN** the system rejects it, and the session's current refresh token still
  refreshes

### Requirement: A session can be ended by its refresh token
The system SHALL end the session a refresh token belongs to when that token is
presented to revoke it, whether it is the session's current token or its
previous one, so neither can refresh again, including within the grace period.
Other sessions of the same subject SHALL be unaffected. A genuine refresh token
whose session no longer exists, or which has itself expired, SHALL be accepted
and change nothing. Anything that is not a genuine refresh token SHALL be
rejected and end no session.

#### Scenario: A revoked session cannot refresh
- **WHEN** a caller revokes a session's current refresh token, or its previous
  one within the grace period, and then presents either to refresh
- **THEN** the system rejects the refresh

#### Scenario: Revoking leaves other sessions alone
- **WHEN** one of a subject's sessions is revoked
- **THEN** the subject's other sessions can still be refreshed

#### Scenario: Revoking an ended session succeeds
- **WHEN** a caller revokes a genuine refresh token whose session has already
  been revoked, purged or has expired
- **THEN** the system accepts the request and changes nothing

#### Scenario: Only a refresh token can revoke
- **WHEN** a caller presents an access token, a token that fails signature
  verification, or a malformed token to revoke a session
- **THEN** the system rejects the request and ends no session

### Requirement: A subject's other sessions can be ended, sparing one
The system SHALL end every session of a subject except the one a refresh token
belongs to, whether the token is that session's current one or its previous one
within the grace period, and SHALL return how many sessions it ended. Sessions of
other subjects SHALL be unaffected. A token that is not a genuine, unexpired
refresh token of that subject, or whose session no longer exists, SHALL be
rejected and end no session. Access tokens already issued remain valid until
they expire.

#### Scenario: Every other session ends and the named one is kept
- **WHEN** a subject has three sessions and a caller ends the others, naming one
  by its refresh token
- **THEN** the system reports 2 ended, the other two cannot refresh, and the named
  one can

#### Scenario: The token the named session just replaced still names it
- **WHEN** a caller ends the other sessions naming the token a session replaced
  within the grace period
- **THEN** that session is kept and the others end

#### Scenario: No other sessions
- **WHEN** a subject with one session ends the others
- **THEN** the system reports 0 ended and the session can still refresh

#### Scenario: Another subject's sessions are unaffected
- **WHEN** one subject's other sessions are ended
- **THEN** sessions of other subjects can still be refreshed

#### Scenario: A token that cannot name the session to keep is rejected
- **WHEN** a caller names an access token, a malformed or expired token, a token
  whose session has ended, or a refresh token of another subject
- **THEN** the system rejects the request and ends no session

### Requirement: Expired sessions are removed
The system SHALL remove sessions whose refresh token has expired.

#### Scenario: An expired session is removed
- **WHEN** a new session is issued after another session's refresh token has
  expired
- **THEN** the expired session no longer exists and live sessions remain

### Requirement: Token/session records are separate from profile and identity data
The system SHALL NOT require or store any identifier, account, or user profile
data — that is entirely another service's responsibility (today,
`tn-user-service`'s).

#### Scenario: Session issued without profile or identity data
- **WHEN** a caller requests or refreshes a token pair
- **THEN** the system does so without requiring, storing, or returning any
  identifier, account, or profile field

### Requirement: Session records use TSID primary keys
The system SHALL assign each session record's primary key as a TSID, not a
database-sequence value, per `tn-claude/standards/java/identifiers.md`. This is
the session's own database row id, separate from the `jti` claims embedded in
the JWTs it issues.

#### Scenario: New session record gets a TSID
- **WHEN** the system issues a new session
- **THEN** the session record's primary key is a TSID value, not a
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
