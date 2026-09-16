# Spring Boot standard

Status: **placeholder**.

Applies to `java-spring-service` components. Builds on the Java and Maven standards.

To be distilled from the existing services (`tn-service`, `tn-data-service`,
`tn-auth-service`, `tn-user-service`, etc.) when the first project service is
created. Expected topics:

- Application / configuration class layout, `@ConfigurationProperties` usage.
- Web layer: controllers, DTOs, validation, error responses, `springdoc` OpenAPI.
- Persistence: Spring Data JDBC / JPA choice, `tn-query` integration, Flyway.
- Security: `oauth2-resource-server`, `spring-security`, jjwt.
- Actuator, health, observability.
- HTTP clients: `spring-boot-restclient`, OpenFeign, `tn-client-feign`.
- Contract testing with Spring Cloud Contract (producer in `src/ct`, consumer via stub
  runner).
- Container build via the `docker` profile; Jetty vs default server.
- The `spring-boot.version` / `spring-cloud.version` are set in `tn-parent`.
