## Purpose

Issues and refreshes the JWT access/refresh token pair that identifies a user
throughout a system, for a verified identifier — so any project can obtain and
refresh a session without implementing token issuance itself. Deliberately owns
only the token/session record, not the user's profile: that separation is
intentional and retained by `tn-user-service` (see that capability's Purpose).
An account is the stable anchor identity; one or more verified identifiers
(email, phone, WhatsApp) link to it, and any of them can be used to sign in.

## ADDED Requirements

### Requirement: Issue a session for a verified identifier, resolving to its linked account
The system SHALL mint a JWT access token and a JWT refresh token for a given
identifier (email address, phone number, or WhatsApp number), creating a record
for that identifier — and a new account for it to link to — on first use. The
issued token's subject SHALL identify the account, not the identifier record.

#### Scenario: First session for a new identifier
- **WHEN** a caller requests a token pair for an identifier that has no existing
  record
- **THEN** the system creates a record for that identifier, creates a new
  account linked to it, and returns a valid access/refresh token pair whose
  subject identifies that account

#### Scenario: Session for a known identifier
- **WHEN** a caller requests a token pair for an identifier that already has a
  record
- **THEN** the system returns a valid access/refresh token pair for that
  identifier's linked account, without creating a duplicate record or a second
  account

### Requirement: An account may have more than one linked identifier
The system SHALL allow more than one identifier to link to the same account,
and SHALL treat a sign-in with any identifier linked to an account as a sign-in
to that account.

#### Scenario: Signing in with either of two linked identifiers
- **WHEN** an account has both an email and a phone number linked to it, and a
  caller requests a token pair for either one
- **THEN** the system issues a session whose subject identifies that same
  account, regardless of which linked identifier was used

### Requirement: An authenticated caller can link an additional identifier to their account
The system SHALL allow a caller with a valid session to link a further
identifier to their account. The system does not itself verify that the new
identifier belongs to the caller — the caller is trusted to have already
verified it (e.g. via `tn-temporary-token-service`'s OTP flow) before
requesting the link.

#### Scenario: Linking a new identifier
- **WHEN** an authenticated caller requests to link an identifier that is not
  yet linked to any account
- **THEN** the system links that identifier to the caller's account, and a
  subsequent sign-in with it resolves to the same account

#### Scenario: Identifier already linked to a different account
- **WHEN** an authenticated caller requests to link an identifier that is
  already linked to a different account
- **THEN** the system rejects the request and does not change either account's
  linked identifiers

#### Scenario: Identifier already linked to the caller's own account
- **WHEN** an authenticated caller requests to link an identifier that is
  already linked to their own account
- **THEN** the system leaves the account's linked identifiers unchanged and
  does not error

### Requirement: Refresh an access token
The system SHALL issue a new access token for a valid, unexpired refresh token
without requiring the identifier to be re-verified.

#### Scenario: Valid refresh token
- **WHEN** a caller presents a refresh token that matches the most recently issued
  one for its account and has not expired
- **THEN** the system returns a new access token

#### Scenario: Unrecognised or superseded refresh token
- **WHEN** a caller presents a refresh token that does not match the most recently
  issued one for its account, or that fails signature verification
- **THEN** the system rejects the request and does not issue a new access token

### Requirement: Identifier type is email, phone, or WhatsApp
The system SHALL accept an email address, a phone number, or a WhatsApp number
as the identifier, and SHALL carry the identifier's type and value as claims in
the issued access token, describing which identifier was used for *this*
session. These claims are informational, not the canonical way to identify the
user — the token's subject (identifying the account) is; see "Issue a session
for a verified identifier, resolving to its linked account."

#### Scenario: Email identifier
- **WHEN** a caller requests a token pair for an email address
- **THEN** the issued access token carries `identifierType = EMAIL` and the email
  address

#### Scenario: Phone identifier
- **WHEN** a caller requests a token pair for a phone number
- **THEN** the issued access token carries `identifierType = PHONE` and the phone
  number

#### Scenario: WhatsApp identifier
- **WHEN** a caller requests a token pair for a WhatsApp number
- **THEN** the issued access token carries `identifierType = WHATSAPP` and the
  WhatsApp number

### Requirement: Token/session records are separate from profile data
The system SHALL NOT require or store user profile details (name or any field
beyond the identifier itself) — profile data is `tn-user-service`'s responsibility,
not this service's.

#### Scenario: Session issued without profile data
- **WHEN** a caller requests or refreshes a token pair
- **THEN** the system does so without requiring, storing, or returning any profile
  field

### Requirement: Identifier and account records use TSID primary keys
The system SHALL assign each identifier record's and each account record's
primary key as a TSID, not a database-sequence value, per
`tn-claude/standards/java/identifiers.md`.

#### Scenario: New identifier record gets a TSID
- **WHEN** the system creates a record for a previously unseen identifier
- **THEN** the record's primary key is a TSID value, not a sequence-issued one

#### Scenario: New account record gets a TSID
- **WHEN** the system creates a new account
- **THEN** the account's primary key is a TSID value, not a sequence-issued one

### Requirement: Structured, masked logging
The system SHALL log token issuance and refresh events as structured (JSON) log
entries, per `tn-claude/standards/logging/README.md`, and SHALL NOT log an access
token, refresh token, or full identifier value unmasked.

#### Scenario: Session issuance is logged without leaking the token
- **WHEN** the system issues or refreshes a token pair
- **THEN** it emits a structured log entry describing the event, and that entry
  does not contain the unmasked access or refresh token value
