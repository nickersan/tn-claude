# tn-resilience Specification

## Purpose
Shared protection for the calls one service makes to another through its `@HttpExchange` clients (Resilience4j): a timeout, circuit
breaker, bulkhead and rate limiter for each service called, and retries only for calls declared safe to repeat, so a slow or failing
service is contained rather than passed on to its callers. A service gets it by depending on the library and sets it under
`tn.resilience`. Requested by okayat (home-feed); the read-only `resilience` endpoint and configurable half-open calls came with 1.2.0
(okayat's health-endpoint-libraries). The behaviour from 1.1.0 is not spec'd here; its tests and README say it.

## Requirements

### Requirement: The state of a service's protection can be read
The system SHALL report, as the read-only Actuator endpoint `resilience`, for each group of services a service calls: its circuit breaker (state,
failure rate or null until enough calls, calls counted, failed, refused), bulkhead (concurrent calls available and allowed) and rate limiter
(permissions available). A service that calls no other SHALL report no groups. Reading SHALL NOT change any breaker, bulkhead or limiter, and the
endpoint SHALL be absent when `tn.resilience.enabled` is false.

#### Scenario: A breaker closes once the service is back
- **WHEN** the service is back and the `halfOpenCalls` calls (10 unless set) let through after the open wait have succeeded
- **THEN** the breaker reads `CLOSED`; until then `OPEN`, or `HALF_OPEN` once a call has been let through, because state moves only when a call is made

### Requirement: Half-open trial calls are configurable
The system SHALL let the number of calls a breaker lets through to try a service after its open wait be set with `half-open-calls`, defaulting to
Resilience4j's 10, for all groups or per group.

#### Scenario: A lower count closes sooner
- **WHEN** `half-open-calls` is 3 and three trial calls succeed
- **THEN** the breaker closes
