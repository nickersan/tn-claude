# Spring Boot standard

Applies to `java-spring-service` components. Builds on the Java and Maven standards.

Two sections below are drafted for real (API docs, contract testing) — the first
services to actually apply them are `tn-auth-service`, `tn-user-service`, and
`tn-temporary-token-service` as part of their current overhaul. Everything else on
this page is still the original placeholder list.

## API documentation — SpringDoc / OpenAPI

**Every `@RestController` endpoint is annotated so SpringDoc can generate accurate
OpenAPI docs from it — annotations aren't optional decoration.**

- Dependency: `org.springdoc:springdoc-openapi-starter-webmvc-ui`, already managed
  by `tn-parent` — but bump the pin. `tn-parent` currently has `3.0.1`, which has a
  known Jackson 2/Jackson 3 mismatch on Spring Boot 4
  ([springdoc/springdoc-openapi#3200](https://github.com/springdoc/springdoc-openapi/issues/3200))
  — real for us, since `tn-parent` already runs Jackson 3
  (`tools.jackson.core:jackson-databind:3.1.2`). Move to `3.1.1` (current latest at
  time of writing) in `tn-parent`'s `dependencyManagement`.
- Annotate with `io.swagger.v3.oas.annotations.*`:
  - `@Tag(name = "...")` on the controller class.
  - `@Operation(summary = "...")` on each mapped method — one sentence, what it
    does.
  - `@ApiResponse(responseCode = "...", description = "...")` for the success case
    and every distinct error case the endpoint can return (not just 200 — a
    consumer reading the generated docs needs the 4xx shapes too).
  - Request/response records get field-level `@Schema(description = "...")` where
    the field name alone doesn't say enough (e.g. what format an identifier value
    must be in) — don't annotate fields that are already self-explanatory.
- No hand-written OpenAPI YAML/JSON — it's generated from the annotated code, so
  there's one source of truth and it can't drift.
- Docs are served at SpringDoc's defaults (`/v3/api-docs`, Swagger UI at
  `/swagger-ui.html`) — don't relocate them without a reason.

## Contract testing — Java DSL, not Groovy

**New and touched contracts are written in Java, under `src/ct/java/contracts`,
using `tn-parent`'s existing `contracts-producer-java` profile** — not the Groovy
DSL under `src/ct/resources/contracts` (the `contracts-producer-groovy` profile).
Both profiles remain valid in `tn-parent` (other components may still use Groovy),
but Java is the standard going forward: one language for test code, not two, and
no separate Groovy toolchain to reason about.

Shape (verified against the current Spring Cloud Contract reference, not
guessed):

```java
package contracts;

import java.util.Collection;
import java.util.Collections;
import java.util.function.Supplier;

import org.springframework.cloud.contract.spec.Contract;
import org.springframework.cloud.contract.verifier.util.ContractVerifierUtil;

public class ShouldGenerateTokenPair implements Supplier<Collection<Contract>>
{
  @Override
  public Collection<Contract> get()
  {
    return Collections.singletonList(Contract.make(c ->
    {
      c.description("should generate token pair");
      c.request(r ->
      {
        r.method(r.POST());
        r.url("/generate");
        r.headers(h -> h.contentType(h.applicationJson()));
        r.body(ContractVerifierUtil.map().entry("identifierType", "EMAIL").entry("identifier", "test@testing.com"));
      });
      c.response(r ->
      {
        r.status(r.OK());
        r.headers(h -> h.contentType(h.applicationJson()));
        r.body(ContractVerifierUtil.map().entry("refresh", "REFRESH").entry("access", "ACCESS"));
      });
    }));
  }
}
```

- One contract (one `Supplier<Collection<Contract>>` implementation) per
  `.groovy` file being migrated — same test name/description, same
  request/response shape, translated to the class's own current API (a contract
  being migrated during a change that also alters the API — like this one — should
  describe the *new* shape, not the old one; don't migrate format and defer the
  content update).
- Base test class (`AbstractContractTest`, `contract-producer.base-test-class`
  property) stays exactly as it already works — that part isn't Groovy-specific.
- `tn-parent`'s `contracts-producer-java` profile already sets
  `testFramework: JUNIT5` and reads `contract-producer.base-package.tests` /
  `contract-producer.base-class.tests` — no new build config needed, just the file
  move and the trigger directory (`src/ct/java/contracts` instead of
  `src/ct/resources/contracts`).

## Still placeholder

- Application / configuration class layout, `@ConfigurationProperties` usage.
- Persistence: Spring Data JDBC / JPA choice, `tn-query` integration, Flyway — see
  `../database/README.md` for the engine/testing side of this.
- Security: `oauth2-resource-server`, `spring-security`, jjwt.
- Actuator, health, observability (note: health *probes* for Kubernetes are
  already drafted — see `../kubernetes/README.md`; this is about what Actuator
  itself should expose beyond that).
- HTTP clients: `spring-boot-restclient`, OpenFeign, `tn-client-feign`.
- Jetty vs the default embedded server.
- The `spring-boot.version` / `spring-cloud.version` are set in `tn-parent`.
