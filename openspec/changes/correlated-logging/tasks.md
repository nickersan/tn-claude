# Tasks

Library-only change (tn-parent, tn-service): unit and integration tests, no acceptance draft; acceptance belongs to the okayat changes
that roll it in (`member-app-log-ids`, `service-log-ids`). Each repo is released on its own when green and reviewed; tn-parent first.
Compatibility: both only add. A service on the old tn-service ignores `traceparent` and `baggage`, as now.

## 1. tn-parent - done when `mvn verify` is green, released
- [x] 1.1 `spring-boot-maven-plugin` runs `build-info` for every deployable service (the `assembly` profile; libraries get none, as their jars share `lib/` with the service), released as 4.4.0. Verify on a consumer build that
      `META-INF/build-info.properties` holds the artifact and version. Release.

## 2. tn-service - after 1, done when `mvn verify` is green, JaCoCo checked, released
- [ ] 2.1 Micrometer Tracing with the OpenTelemetry bridge, W3C propagation, sampling always, no exporter; baggage remote and correlation
      fields `userId`, `sessionId`, `client`. Verify with integration tests named for "A request that carries a trace", "A request that
      carries none", "The trace is sent on" (a `RestClient` from the injected builder to a stub server) and "Session and client carried on".
- [ ] 2.2 `AccessTokenVerifier` sets `userId` baggage to the subject on success; `tn.logging.edge` discards incoming `userId`. Verify with
      tests named for "The user from a verified token", "A verified token wins over a sent user" and "A client asserts a user".
- [ ] 2.3 `service.name` and `service.version` on the Logback context from `BuildProperties` (fallbacks as in the design). Verify with a
      test named for "Name and version on every line", reading the encoded JSON.
- [ ] 2.4 One INFO request line per request (method, path and query, status, time taken; no body or headers; not for health or `/noop`). Verify with tests named for "A request is logged once" and "Probes are not logged".
- [ ] 2.5 Verify "A service that is sent nothing": the existing integration tests pass unchanged. Update `catalog.yaml`'s summary. Release.
