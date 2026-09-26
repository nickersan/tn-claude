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

## Controller layout — `api` interfaces, `controllers` implementations

**Every endpoint's contract (routing + OpenAPI annotations + request/response
shapes) lives on an interface in the `api` package; a plain `@RestController`
class in a `controllers` package implements it and holds no annotations beyond
`@RestController` itself.** Springdoc-openapi's own documented pattern for
keeping API documentation separate from handler logic — Spring MVC's
`RequestMappingHandlerMapping` resolves `@RequestMapping`-family annotations
(`@GetMapping`/`@PostMapping`/etc.) via `AnnotatedElementUtils`, which looks at
interfaces a controller class implements, so nothing needs repeating on the
implementing method. Not a new invention — this is how Spring and SpringDoc
already expect controllers documented at scale; codifying it here so every
service in this layer does it the same way rather than each accreting its own
variant.

```java
// api/GenerateApi.java
package com.tn.auth.api;

public interface GenerateApi
{
  @PostMapping("/v1/generate")
  @Operation(summary = "Issue a token pair")
  @ApiResponse(responseCode = "200", description = "Token pair issued")
  TokenPair generate(@RequestBody GenerateRequest request);

  record GenerateRequest(String id, List<Claim> claims) {}
}

// controllers/GenerateController.java
package com.tn.auth.controllers;

@RestController
@AllArgsConstructor
public class GenerateController implements GenerateApi
{
  private final AuthService authService;

  @Override
  public TokenPair generate(GenerateRequest request)
  {
    return authService.generate(request.id(), request.claims());
  }
}
```

- `@Tag(name = "...")` goes on the interface, not the implementing class —
  it's part of the documented contract.
- Request/response records (and any endpoint-local types) are nested in, or
  live alongside, the interface in `api` — they're part of the contract, not
  the implementation.
- The implementing class in `controllers` carries the dependencies
  (`@AllArgsConstructor` + `final` fields, as elsewhere in this layer) and
  nothing else — no `@RequestMapping`, no `@Tag`, no `@Operation`. If a
  reviewer finds a mapping or OpenAPI annotation on a class in `controllers`,
  that's the signal something drifted from this convention.
- Applies to every controller in every `java-spring-service` component, not
  just ones being actively touched — new controllers are written this way
  from the start; existing controllers are restructured to match as the
  component they live in is next touched for other reasons (no blanket
  retrofit sweep mandated by this entry alone).

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

## API design — REST for resources, `/actions/` for everything else

**Resource-shaped operations (get/create/update/delete/list-and-filter a thing)
stay REST-conventional: `GET`/`POST`/`PUT`/`DELETE` on the resource's own path,
filtering via `tn-query` (`?q=<expression>`, validated against the entity's actual
fields the way `tn-data-service`'s `QueryBuilder` already does it).** Keep that —
it's a good, consistent convention across the layer and worth preserving even
where a hand-written controller replaces `tn-data-service`'s fully-generic one
(see `../database/README.md` and the identity-overhaul change's design.md for why
a generic auto-registered controller isn't always the right fit, even though the
*conventions* it established are).

**Operations that don't map onto a single resource verb get an explicit action
path instead of being forced into CRUD shape: `POST /v1/actions/<kebab-case-
name>`.** A find-or-create is the motivating example — it's not "insert" (might
already exist) or "update" (might not exist yet) or a plain "get" (may need to
create); it's its own operation, so it gets its own path rather than a strained
mapping onto `POST`/`PUT`/`GET`:

```
POST /v1/actions/find-or-create
```

Request body: the identifier (type + value). Response: the resulting record,
whether it already existed or was just created. Same rules as any other
endpoint — `@Operation`/`@ApiResponse` annotated, its own Java contract, no
special-casing just because the path looks different.

Use this pattern sparingly — most operations genuinely are resource CRUD, and
`/actions/` is for the real exceptions, not a way to avoid thinking about REST
shape. If a service accumulates several action endpoints, that's a signal to
look again at whether it's still the right service boundary.

## Pagination — Spring Data's native `Pageable`, not a hand-rolled scheme

**Don't reinvent pagination query params.** `tn-data-service` currently does —
custom `$pageNumber`/`$pageSize`/`$sort`/`$direction` params and a hand-rolled
`com.tn.lang.util.Page` response wrapper. That's now superseded: accept
`org.springframework.data.domain.Pageable` directly as a controller method
parameter (Spring Boot auto-configures `PageableHandlerMethodArgumentResolver`
whenever `spring-data-commons` is on the classpath, which it already is via
`spring-boot-starter-data-jpa`) — it resolves the standard `page`, `size`, and
repeatable `sort` (`sort=name,desc`) request params for you, no bespoke parsing.

**Don't serialize `Page<T>` directly — it's explicitly not a stable contract.**
Spring Data's own docs warn that `PageImpl`'s JSON shape can change between
versions. Since Spring Data 3.3 (well below what `tn-parent` manages),
`org.springframework.data.web.PagedModel<T>` gives a stable wrapper without
needing Spring HATEOAS: `new PagedModel<>(page)`, or enable it service-wide with
`@EnableSpringDataWebSupport(pageSerializationMode = VIA_DTO)`.

**For a large, deep-scrolled dataset, prefer keyset pagination over offset —
`Window<T>`/`ScrollPosition` (Spring Data 3.1+) — instead of `Pageable`.** Offset
pagination gets slower as the offset grows (the database scans and discards
every skipped row); keyset pagination uses an indexed `WHERE` clause instead and
stays fast at any depth, at the cost of no "jump to page N" and no total count.
Not needed for a small/bounded dataset (a user-profile table, say) — worth
reaching for on something users might actually scroll deep into (candidate:
`locations/search`'s anonymous browse, if it ever needs to support that — not
decided, see `okayat-platform`'s own design.md).

## Concurrency-safe find-or-create (and any other check-then-act operation)

**Every service in this layer runs as multiple instances in any real
environment — in-process synchronization (a `synchronized` block, a local lock)
provides no safety at all across them.** A find-or-create (or any other
check-then-act sequence — "does this exist, if not create it") must be made safe
by the database, not the application process. On PostgreSQL, the idiomatic
one-statement version is an upsert against the unique constraint:

```sql
INSERT INTO identifier (identifier_type, identifier_value, ...)
VALUES (:type, :value, ...)
ON CONFLICT (identifier_type, identifier_value)
DO UPDATE SET identifier_value = EXCLUDED.identifier_value
RETURNING *;
```

The `DO UPDATE SET <col> = EXCLUDED.<col>` (a functional no-op) is the standard
Postgres idiom to make `RETURNING` give you the existing row on conflict, not
just on insert — `DO NOTHING` alone returns no row when the conflict branch
fires. Alternative if a raw upsert doesn't fit cleanly (e.g. behind Spring Data
JPA's repository abstraction): attempt the insert, catch the
`DataIntegrityViolationException` Spring translates a unique-constraint
violation into, and re-`find` on conflict — but be deliberate about the
transaction boundary if you do, since a caught constraint violation still marks
a surrounding `@Transactional` rollback-only in Spring; the insert attempt and
the conflict re-fetch need to be arranged so the retry isn't silently doomed by
the same transaction. The native upsert avoids that wrinkle entirely, which is
why it's the preferred shape.

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
