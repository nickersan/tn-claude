# tn-temporary-token-service Specification

## Purpose
Generates and verifies a short-lived, one-time token against an arbitrary owner
string, so any service can build an OTP-style verification flow without
implementing token generation and expiry itself.

## Requirements

### Requirement: Generate a token for an owner
The system SHALL generate a token value for a given owner string, with a
caller-specified type (numeric or base64) and time-to-live in minutes.

#### Scenario: Generate a numeric token
- **WHEN** a caller requests a numeric token for an owner with a given
  time-to-live
- **THEN** the system returns a six-digit numeric token value and its expiry time

#### Scenario: Generate a base64 token
- **WHEN** a caller requests a base64 token for an owner with a given
  time-to-live
- **THEN** the system returns an opaque base64-encoded token value and its expiry
  time

### Requirement: Verify a token
The system SHALL verify a token value against an owner, succeeding only when the
value matches the most recently generated token for that owner and it has not
expired.

#### Scenario: Correct token within its validity period
- **WHEN** a caller verifies the correct token value for an owner before its
  time-to-live has elapsed
- **THEN** the system reports the token as valid

#### Scenario: Incorrect token
- **WHEN** a caller verifies a token value for an owner that does not match the
  most recently generated one
- **THEN** the system reports the token as invalid

#### Scenario: Expired token
- **WHEN** a caller verifies a token value for an owner after its time-to-live has
  elapsed
- **THEN** the system reports the token as invalid

### Requirement: Owner is an opaque string
The system SHALL treat the owner as an opaque string with no interpretation of its
contents — it SHALL NOT require the owner to be an email address, phone number, or
any other specific shape.

#### Scenario: Non-identifier owner accepted
- **WHEN** a caller generates or verifies a token using an owner string that is not
  an email address or phone number
- **THEN** the system processes the request the same way as for any other owner
  string

### Requirement: Structured, masked logging
The system SHALL log generate and verify events as structured (JSON) log entries,
per `tn-claude/standards/logging/README.md`, and SHALL NOT log a token value or the
full owner value unmasked. The current implementation logs the owner in the clear
(`log.info("Generated token for: {}; ...", owner)`) — that does not meet this
requirement when the owner is an email address or phone number, and needs
correcting, not just leaving as-is.

#### Scenario: Generate/verify is logged without leaking the token or owner
- **WHEN** the system generates or verifies a token
- **THEN** it emits a structured log entry describing the event, and that entry
  does not contain the unmasked token value or the unmasked owner value
