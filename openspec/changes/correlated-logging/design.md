# Design

## Decisions

**The action id is the trace id.** A client starts a trace when the user acts (a click, a pull to refresh) and sends a W3C `traceparent`
on each request it makes for that action, with a new span id per request. Every service continues it, so one id joins the client's lines
and every service's. A separate `X-Action-Id` header was considered and dropped: W3C trace context is what Micrometer Tracing and any
aggregator already understand, and it keeps exporting traces open as a later step without changing a header.

**Micrometer Tracing with the OpenTelemetry bridge, propagation only.** Spring Boot's tracing auto-configuration puts `traceId`/`spanId` in
the MDC and instruments the auto-configured `RestClient.Builder`. tn-service sets W3C propagation and sampling to always (so every line has
ids), and no span exporter. Exporting spans is a later, separate decision (okayat `log-collection` records Grafana Cloud as the cloud
suggestion, which takes traces too).

**`userId`, `sessionId` and `client` are baggage, correlated into the MDC.** `management.tracing.baggage.remote-fields` and
`correlation.fields` carry them between services in the W3C `baggage` header and onto every line. `sessionId` and `client` come from the
edge (okayat-bff reads `X-Session-Id` and `X-Client`); `userId` from verification.

**`userId` is set where a token is verified.** When `AccessTokenVerifier` accepts an access token, tn-service sets the `userId` baggage to
its subject for the current trace. So the BFF's lines and every service's after it carry the user, and a service that verifies the
delegate token overwrites any value it was sent with the one it verified. The baggage value is for logs only: the `X-Delegate-User-Token`
requirement is unchanged, and no service may authorize on it.

**An edge discards an incoming `userId`.** `tn.logging.edge=true` (set by a BFF) drops `userId` from incoming baggage before anything
logs. Without it a service trusts its caller's baggage, as it trusts the network policy that lets the caller in.

**Source from build info.** `tn-parent` adds the `build-info` goal to `spring-boot-maven-plugin`. At startup tn-service puts
`service.name` (`spring.application.name`, else the build artifact) and `service.version` on the Logback logger context, which the Logstash
encoder writes on every line. Nothing goes in each service's `logback-spring.xml`. Without build info (a test run from the IDE) the name
falls back as above and the version is `unknown`.

**Background work has a trace of its own.** A scheduled job or event handler not started by a request gets a new trace from Micrometer's
`@Scheduled` observation and no `userId`; services name the job in its log lines as they do now.

## Risks
- A client built with `RestClient.create()` rather than the injected builder does not propagate. okayat `service-log-ids` checks each service.
- Sampling always costs a little per request; with no exporter that is only id generation and MDC writes.
