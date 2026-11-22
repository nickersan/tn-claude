## ADDED Requirements

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
The system SHALL carry `userId`, `sessionId` and `client` between services in the W3C `baggage` header and SHALL put each that is set on
every log line written while the request is handled. When a service verifies an access token, the system SHALL set `userId` to the
token's subject. The `userId` on a log line SHALL NOT be used to identify the acting user.

#### Scenario: The user from a verified token
- **WHEN** a service verifies a valid access token while handling a request
- **THEN** its later lines for that request, and the lines of the services it calls, have the token's subject as `userId`

#### Scenario: Session and client carried on
- **WHEN** a service is sent baggage with `sessionId` and `client`
- **THEN** its lines for that request have them, and so do the lines of the services it calls

#### Scenario: A verified token wins over a sent user
- **WHEN** a service sent `userId` in baggage verifies a token for a different subject
- **THEN** its later lines have the token's subject

### Requirement: An edge trusts no caller's user
The system SHALL let a service declare itself an edge (`tn.logging.edge=true`). An edge SHALL discard a `userId` it is sent in baggage.

#### Scenario: A client asserts a user
- **WHEN** an edge is sent baggage with a `userId` and no access token
- **THEN** none of its lines for that request have a `userId`

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
The system SHALL write one INFO line for each HTTP request a service answers, with the method, the path and query, the status and the time
taken, and SHALL NOT write the request's body or headers on it. Health and `/noop` requests SHALL NOT be logged.

#### Scenario: A request is logged once
- **WHEN** a service answers a request
- **THEN** it writes one line with the method, path and query, status and time taken, with the request's trace and baggage fields

#### Scenario: Probes are not logged
- **WHEN** a service answers a health or `/noop` request
- **THEN** it writes no request line for it
