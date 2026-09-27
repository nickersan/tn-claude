# tn-service Specification

## Purpose
Shared service-level support for every tn-based service. For identity, it lets a
service verify a `tn-auth-service` access token itself, and defines how one
service passes a user's token to another when acting on that user's behalf, so a
receiving service proves who the user is instead of trusting an asserted id.

## Requirements

### Requirement: Verify a tn-auth-service access token
The system SHALL verify an access token's RS256 signature against
`tn-auth-service`'s public key, and SHALL check its expiry and issuer and that its
`token_use` claim is the string `access`. A token that passes SHALL yield its
subject, which MAY be absent. A token that fails any check SHALL be rejected as
unauthenticated (401). A caller that requires the subject SHALL have a token
without one rejected as unauthenticated.

#### Scenario: A valid access token yields its subject
- **WHEN** a service verifies an unexpired access token signed by
  `tn-auth-service`'s key with the configured issuer
- **THEN** verification returns the token's subject

#### Scenario: A valid access token without a subject
- **WHEN** a service verifies a valid access token with no subject, or a blank one
- **THEN** verification returns no subject
- **AND** a service that requires the subject has the token rejected as
  unauthenticated

#### Scenario: A refresh token is not accepted
- **WHEN** a service verifies a token whose `token_use` is `refresh`, missing, or
  not a string
- **THEN** verification fails as unauthenticated

#### Scenario: An expired, foreign or malformed token is not accepted
- **WHEN** a service verifies a token that has expired, is signed by another key,
  has another issuer, or isn't a JWT at all
- **THEN** verification fails as unauthenticated

### Requirement: A delegated call carries the user's access token
The system SHALL define `X-Delegate-User-Token` as the header in which a service
acting for a user passes that user's access token (the raw JWT) to another
service. A receiving service SHALL identify the user only by verifying this
token, and SHALL NOT accept a user id asserted in a header.

#### Scenario: The receiving service identifies the user from the token
- **WHEN** a service receives a request whose `X-Delegate-User-Token` holds a
  valid access token
- **THEN** it treats the token's subject as the acting user

### Requirement: A service creates its own verifier
The system SHALL let a service create a verifier from `tn-auth-service`'s public
key, given either as a key or as base64 X.509 text (whitespace ignored), and the
expected issuer. The system SHALL NOT create a verifier or read any property
unless a service asks it to.

#### Scenario: A verifier from a pasted key
- **WHEN** a service creates a verifier from the base64 public key text, line
  breaks included, and the issuer
- **THEN** that verifier accepts access tokens signed with the matching private
  key

#### Scenario: A service that doesn't use the verifier is unaffected
- **WHEN** a service depending on `tn-service` doesn't create a verifier
- **THEN** it starts and behaves as before
