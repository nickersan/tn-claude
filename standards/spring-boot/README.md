# Spring Boot standard

Applies to `java-spring-service` components. Builds on the Java and Maven standards.
One file per topic:

- [`api-documentation.md`](api-documentation.md) — SpringDoc / OpenAPI annotations on every endpoint.
- [`controllers.md`](controllers.md) — `api` interfaces hold the contract, `controller` classes implement it.
- [`contract-testing.md`](contract-testing.md) — contracts in the Java DSL, not Groovy.
- [`api-versioning.md`](api-versioning.md) — every path starts `/v<n>`; what counts as breaking.
- [`api-design.md`](api-design.md) — REST for resources, `/actions/` for everything else; public vs internal APIs.
- [`delegated-calls.md`](delegated-calls.md) — pass the user's token, never a user id.
- [`http-clients.md`](http-clients.md) — `@HttpExchange` interfaces, `tn-resilience`, not Feign.
- [`actuator.md`](actuator.md) — expose only `health` and `resilience`.
- [`pagination.md`](pagination.md) — Spring Data's `Pageable` / `PagedModel`, keyset for deep data.
- [`concurrency.md`](concurrency.md) — database-safe find-or-create; `<Entity>RepositoryExtended`.

## Not yet written

- Application / configuration class layout, `@ConfigurationProperties` usage.
- Persistence: Spring Data JDBC / JPA choice, `tn-query` integration, Flyway — see
  `../database/README.md` for the engine/testing side of this.
- Security: `oauth2-resource-server`, `spring-security`, jjwt.
- Observability beyond Actuator exposure (health *probes* for Kubernetes are drafted in
  `../kubernetes/README.md`).
- Jetty vs the default embedded server.
- The `spring-boot.version` / `spring-cloud.version` are set in `tn-parent`.
