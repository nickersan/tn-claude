# Proposal

Requested by okayat-platform on 2026-11-22 (the correlated-logging series: `log-collection`, `member-app-log-ids`, `service-log-ids`,
`admin-log-ids`). Split at the start, on the user's word, so the library lands first and every service picks it up with a version bump.

## Why
Every tn and okayat service already writes JSON log lines to stdout (Logstash encoder), but nothing on a line says which user action it
belongs to, who it was for, or which service and version wrote it. Following one click through the BFF and the services it reaches means
matching timestamps by hand. okayat wants every log line, client and server, to carry an action id, a user (or a session for someone not
signed in) and its source, so an aggregator can show the system as a whole.

## What Changes
- **An action id on every line**: a service continues the W3C `traceparent` it is sent (or starts one), puts `traceId` and `spanId` on
  every log line while it handles the request, and sends the trace on with every call it makes. One user action is one trace, so the
  trace id is the action id across every service it reaches.
- **Who on every line**: `userId`, `sessionId` and `client` ride as W3C `baggage` and are put on every log line. `userId` is set from the
  subject of an access token the service verifies; it is for logging only and is never used to identify the user (that stays
  `X-Delegate-User-Token`).
- **An edge trusts no caller's user**: a service set as an edge (a BFF) discards an incoming `userId`, so a client cannot make its lines look
  like someone else's.
- **Where on every line**: `service.name` and `service.version`, from the service's build info.
- **A line per request**: one INFO line for each request a service answers (method, path and query, status, time taken), without its body or headers and not for probes. Today the request filter logs only at DEBUG, which is off, so a successful request leaves no line.
- **No change for anything else**: no spans are exported (propagation only), and a service sent no trace or baggage starts and behaves as
  before.

## Capabilities
### New Capabilities

### Modified Capabilities
- `tn-service`: correlated log lines (trace, user, session, client, source) and their propagation between services.

## Impact
- `tn-parent`: the Spring Boot plugin writes `build-info`, so a service knows its name and version. A new minor version.
- `tn-service`: Micrometer Tracing (OpenTelemetry bridge, W3C propagation, no exporter), the baggage fields and their MDC correlation, the
  verifier setting `userId`, the edge setting, `service.name`/`service.version` on the logger context. A new minor version.
- Consumers pick it up by bumping `tn-parent` and `tn-service`; none has to change code. HTTP clients built from Spring's `RestClient.Builder`
  (the `@HttpExchange` groups tn-resilience configures) propagate with no change.
- Rolled into services by okayat `service-log-ids` and into the BFFs by `member-app-log-ids` / `admin-log-ids`; recorded in `catalog.yaml`
  `requested_changes` on `tn-service` and `tn-parent`.
