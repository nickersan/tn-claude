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

### Requirement: Read the roles in a tn-auth-service access token
The system SHALL let a service read the `roles` claim of an access token that
passes verification, in order, and ask whether it holds a given role (matched
exactly). A token with no `roles` claim SHALL have none. A token whose `roles` is
not a list of strings SHALL be rejected as unauthenticated (401), as SHALL a token
that fails verification, including a refresh token. A role in a token is what the
holder was when the session was made, so it does not change for the life of the
session.

#### Scenario: A token's roles are read in order
- **WHEN** a service reads the roles of a valid access token whose `roles` claim
  is `["system-administrator", "support"]`
- **THEN** it gets both, in that order, and the token holds each of them but not
  `moderator`, `system` or `System-Administrator`

#### Scenario: A token without roles
- **WHEN** a service reads the roles of a valid access token with no `roles` claim
  or an empty one
- **THEN** it gets none, and the token holds no role

#### Scenario: A refresh token's roles are not read
- **WHEN** a service reads the roles of a refresh token, or of an expired, foreign
  or malformed token
- **THEN** verification fails as unauthenticated

#### Scenario: Roles that are not a list of strings
- **WHEN** a service reads the roles of a valid access token whose `roles` is a
  string, or a list of numbers
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

### Requirement: A service says whether it is alive and whether it is ready
The system SHALL give every service that depends on `tn-service` Actuator's `liveness` and `readiness` health groups, on the port the API is on, with
details never shown. Liveness SHALL depend only on the process. Readiness SHALL be the readiness state and, where the service has a datasource, that
datasource, and SHALL NOT depend on any other service or on the state of a circuit breaker. `tn-service` SHALL expose `health` and `resilience` over the
web by default, merged with what a service exposes (a service's own `env` stays) and overridden by its own settings, and SHALL expose no other endpoint.
`GET /noop` is unchanged.

#### Scenario: A service whose datasource is unreachable is not ready
- **WHEN** a service's datasource cannot be reached
- **THEN** readiness answers 503 and liveness still answers 200

#### Scenario: A service whose dependency is down is still ready
- **WHEN** a service that calls another is running and the other is down or its breaker is open
- **THEN** readiness answers that it is up
