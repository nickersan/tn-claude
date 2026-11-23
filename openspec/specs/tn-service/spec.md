# tn-service Specification

## Purpose
Shared service-level support for every tn-based service. For identity, it lets a
service verify a `tn-auth-service` access token itself, and defines how one
service passes a user's token to another when acting on that user's behalf, so a
receiving service proves who the user is instead of trusting an asserted id.

For logging (from 2.4.0), it makes every line of a service correlated with no code in the service: the action (the W3C trace, continued
and sent on), who it is for (`user.id` from a verified token, else `session.id`) and the client (`client.name`) as baggage, and the
service's own name and version, plus one INFO request line per request with its path and query. Propagation only; no spans are exported.
The dotted names (2.5.0; `userId`, `sessionId` and `client` before) keep the correlation apart from fields a service logs itself; an
edge discards the old name as well as the new. Requested by okayat's correlated-logging series; see the logging standard for levels.

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
The system SHALL give every service that depends on `tn-service` Actuator's `liveness` and `readiness` health groups, on the API's port,
details never shown. Liveness SHALL depend only on the process; readiness on the readiness state and the service's own datasource, if any,
never on another service or a breaker. `tn-service` SHALL expose `health` and `resilience` by default, merged with and overridden by the
service's own settings, and nothing else (platform/health).

#### Scenario: A service whose datasource is unreachable is not ready
- **WHEN** a service's datasource cannot be reached
- **THEN** readiness answers 503 and liveness still answers 200

#### Scenario: A service whose dependency is down is still ready
- **WHEN** a service that calls another is running and the other is down or its breaker is open
- **THEN** readiness answers that it is up

### Requirement: A log line names the action it is part of
The system SHALL continue the W3C `traceparent` a service is sent, or start a trace when it is sent none, and SHALL put `traceId` and
`spanId` on every log line written while the request is handled. Every call the service makes with Spring's `RestClient.Builder` SHALL send
the trace on.

#### Scenario: A request that carries a trace
- **WHEN** a service is sent a request with a `traceparent`
- **THEN** every line it logs for that request has that trace id

#### Scenario: A request that carries none
- **WHEN** a service is sent a request with no `traceparent`
- **THEN** every line it logs for that request has one new trace id

#### Scenario: The trace is sent on
- **WHEN** a service handling a traced request calls another service
- **THEN** the call carries the same trace id in `traceparent`

### Requirement: A log line names who it is for
The system SHALL carry `user.id`, `session.id` and `client.name` between services in the W3C `baggage` header and SHALL put each that is set on
every log line written while the request is handled. When a service verifies an access token, the system SHALL set `user.id` to the
token's subject. The `user.id` on a log line SHALL NOT be used to identify the acting user.

#### Scenario: The user from a verified token
- **WHEN** a service verifies a valid access token while handling a request
- **THEN** its later lines for that request, and the lines of the services it calls, have the token's subject as `user.id`

#### Scenario: Session and client carried on
- **WHEN** a service is sent baggage with `session.id` and `client.name`
- **THEN** its lines for that request have them, and so do the lines of the services it calls

#### Scenario: A verified token wins over a sent user
- **WHEN** a service sent `user.id` in baggage verifies a token for a different subject
- **THEN** its later lines have the token's subject

### Requirement: An edge trusts no caller's user
The system SHALL let a service declare itself an edge (`tn.logging.edge=true`). An edge SHALL discard a `user.id` it is sent in baggage.

#### Scenario: A client asserts a user
- **WHEN** an edge is sent baggage with a `user.id` and no access token
- **THEN** none of its lines for that request have a `user.id`

### Requirement: A log line names the service that wrote it
The system SHALL put `service.name` and `service.version` on every log line, from the service's application name and build info, with no
configuration in the service.

#### Scenario: Name and version on every line
- **WHEN** a service built with `tn-parent` logs anything
- **THEN** the line has the service's name and released version

### Requirement: Correlation changes nothing else
The system SHALL export no spans, and a service sent no trace or baggage SHALL start and behave as before.

#### Scenario: A service that is sent nothing
- **WHEN** a service depending on `tn-service` is sent a request with no `traceparent` and no `baggage`
- **THEN** it answers as before, and its lines differ only by the new fields

### Requirement: A service logs each request it answers
The system SHALL write one INFO line for each HTTP request a service answers, with the method, the path, each query parameter as a field of its own, the status and the time
taken, and SHALL NOT write the request's body or headers on it. Health and `/noop` requests SHALL NOT be logged.

#### Scenario: A request is logged once
- **WHEN** a service answers a request
- **THEN** it writes one line with the method, path, query parameters as fields, status and time taken, with the request's trace and baggage fields

#### Scenario: Probes are not logged
- **WHEN** a service answers a health or `/noop` request
- **THEN** it writes no request line for it
