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

## Controller layout — `api` interfaces, `controller` implementations

**Every endpoint's contract (routing + OpenAPI annotations + request/response
shapes) lives on an interface in the `api` package; a plain `@RestController`
class in a `controller` package implements it and holds no annotations beyond
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

// controller/GenerateController.java
package com.tn.auth.controller;

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
- The implementing class in `controller` carries the dependencies
  (`@AllArgsConstructor` + `final` fields, as elsewhere in this layer) and
  nothing else — no `@RequestMapping`, no `@Tag`, no `@Operation`. If a
  reviewer finds a mapping or OpenAPI annotation on a class in `controller`,
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

## API versioning — every path starts `/v<n>`

**Every API path starts with its major version: `/v1/...`.** An API stays on
its version for as long as its changes are backwards compatible. A breaking
change to an existing API moves it to the next version (`/v1` → `/v2`, `/v2` →
`/v3`, and so on) rather than changing the existing version in place.

Breaking changes include:
- removing or renaming an endpoint, a field, or a query parameter;
- changing a field's type or meaning;
- making an optional request field required;
- removing an enum value a caller may send or receive.

Adding an endpoint, an optional request field, or a response field is not
breaking, and stays on the current version. So is a new error response for a
case that previously succeeded only by accident (e.g. a new 429 when a limit
is exceeded).

- The version is part of the path in the `api` interface's mapping (for
  example `@RequestMapping("/v1/users")`, or `/v1/...` on each method). It is
  never a header or a query parameter.
- When an API moves to a new version, keep serving the previous one until its
  consumers have moved, then remove it. Don't break it in place to save the
  bump.
- Operational endpoints are not API and carry no version: the health probe
  (`/noop`, see `../kubernetes/README.md`), `/actuator/**`, and SpringDoc's
  `/v3/api-docs` and `/swagger-ui.html` (whose `v3` is the OpenAPI spec's version,
  not the service's).

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

**An action on one specific resource, or on one of its collections, hangs off
that resource: `POST /v1/<resource>/{id}[/<collection>]/actions/<name>`.** The
top-level `/v1/actions/` is only for operations that don't belong to one resource
(a find-or-create, sending a passcode). For example:

```
GET  /v1/spots/{id}/followers                  list the collection
POST /v1/spots/{id}/followers/actions/add      the caller follows
POST /v1/spots/{id}/followers/actions/remove   the caller unfollows
GET  /v1/spots/{id}/admins
POST /v1/spots/{id}/admins/actions/add         body: {"userId": ...}, another user
POST /v1/spots/{id}/admins/actions/remove      body: {"userId": ...}
POST /v1/spots/{id}/actions/rollback           body: {"revision": ...}
```

Listing a collection stays a plain `GET`. In a public API, changing one goes through
named actions rather than `PUT`/`DELETE` on a member path (`.../followers/{userId}`),
because the member is usually the caller, who mustn't be named in the request (below).

**Public APIs never carry the caller's own identity.** In an API a client calls
directly (a BFF), who is calling comes from the bearer token's subject, and nothing
else. An action applied to the caller (following a spot) has no user id in its
path or body at all. A user id appears only when it names a *different* user, e.g.
the user being made an administrator, and then in the body. This keeps a client
from acting as someone else by changing an id.

**Internal (service-to-service) APIs use plain member resources instead.** Behind a
BFF, the member is simply named in the path:

```
PUT    /v1/spots/{id}/followers/{userId}   idempotent add
DELETE /v1/spots/{id}/followers/{userId}   idempotent remove
PUT    /v1/spots/{id}/admins/{userId}
DELETE /v1/spots/{id}/admins/{userId}
```

The acting user still travels separately, as a delegate user token (below), so
authorization ("is the caller an administrator?") keeps working. Where only the
user themselves may change a membership (following), the service rejects a path
user who isn't the token's subject with 403, which costs one comparison.

## Delegated calls — pass the user's token, never a user id

**A service calling another on a user's behalf passes that user's access token in
`X-Delegate-User-Token`** (the raw JWT, no `Bearer ` prefix;
`com.tn.service.security.DelegateUserToken.HEADER`). The receiving service
identifies the user only by verifying the token with `tn-service`'s
`AccessTokenVerifier`. It checks the signature, expiry, issuer and
`token_use` = `access`. `subjectRequired(token)` returns the user, and
`subject(token)` returns an `Optional` for the rare caller that can do without one.
An invalid token, or a missing subject where one is required, is a 401
(`InvalidAccessTokenException`).

Nothing is auto-configured. The service declares the verifier bean itself, from
`tn-auth-service`'s public key (base64 X.509) and issuer. The key and issuer are the
same for every service in a project, so they're project-level properties,
`<project>.access-token.public-key` and `<project>.access-token.issuer`, declared
once and used by each service that verifies tokens:

```java
@Bean
AccessTokenVerifier accessTokenVerifier(
  @Value("${okayat.access-token.public-key}")
  String publicKey,
  @Value("${okayat.access-token.issuer}")
  String issuer
)
  throws NoSuchAlgorithmException, InvalidKeySpecException
{
  return new AccessTokenVerifier(publicKey, issuer);
}
```

**Never accept a user id asserted in a header** (`X-User-Id` and the like). The
receiving service can't tell a real one from a forged one, so anything that can
reach it could act as any user. A verified token proves who the user is.

A call with no user (an anonymous read) simply omits the header. An endpoint that
needs a user returns 401 when the header is missing or its token fails
verification.

## HTTP clients — `@HttpExchange` interfaces, not Feign or hand-written calls

**Call another service through a Spring HTTP interface**: an interface in the
consumer's `client` package, its methods annotated `@GetExchange`,
`@PostExchange`, `@PutExchange`, `@DeleteExchange` and so on. Register it with
`@ImportHttpServices`, one group per downstream service, and set the group's base
URL in configuration:

```java
@HttpExchange("/v1/spots")
public interface SpotServiceClient
{
  @GetExchange("/{id}")
  Spot get(@PathVariable long id);

  @PutExchange("/{id}/followers/{userId}")
  void follow(@RequestHeader(DelegateUserToken.HEADER) String delegateUserToken, @PathVariable long id, @PathVariable long userId);
}

@Configuration
@ImportHttpServices(group = "spot-service", types = SpotServiceClient.class)
class ClientConfiguration {}
```

```yaml
spring:
  http:
    serviceclient:
      spot-service:
        base-url: ${SPOT_SERVICE_URL:http://localhost:8093}
```

- **Not Feign.** Spring Cloud OpenFeign is feature-complete, and it pulls in the
  Spring Cloud release train for something Spring Framework 7 and Boot 4 now do
  natively, backed by the same `RestClient`. Feign must not be used in new or
  changed code. `tn-client-feign` and the Feign dependencies still managed in
  `tn-parent` are kept for reference only.
- **Not hand-written `RestClient` calls.** They repeat URI building, headers and
  body handling in every method, and `body(...)` returns a nullable value that
  every caller then has to guard.
- **Errors come from `RestClient`'s own exceptions**, whose class names already
  carry the status: `HttpClientErrorException.NotFound`,
  `HttpClientErrorException.TooManyRequests`, `HttpServerErrorException` and so
  on. The caller catches the one that means something to it and translates it
  into its own meaningfully named exception (a 429 from a token service becomes
  `PasscodeThrottledException`). Declare those exceptions in the interface
  method's `throws` so the caller can see them. For group-wide behaviour
  (timeouts, a shared error mapping), use a `RestClientHttpServiceGroupConfigurer`
  bean, not per-call code.
- **Return the body type the API promises.** Where the API allows no body (for
  example, a lookup that can find nothing without it being an error), return
  `Optional<T>`, which HTTP interfaces support directly. Never return `null` for
  "absent" (see `standards/java/idioms.md`).
- **The delegate user token is a parameter**, `@RequestHeader(value =
  DelegateUserToken.HEADER, required = false)` where anonymous calls are allowed,
  and required otherwise.
- **Don't share the producer's API interface.** The consumer declares its own
  interface and records, so the two services build independently. The producer's
  contracts, run against the consumer through the stub runner, catch any drift.

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
`spots/search`'s anonymous browse, if it ever needs to support that — not
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

**Naming the fragment interface: `<Entity>RepositoryExtended`, not
`<Entity>RepositoryCustom`.** When a Spring Data repository needs hand-written
methods alongside its generated ones (a native upsert like the above, a bulk
op, anything `CrudRepository`/`tn-query`'s queryable base can't derive), the
three-piece shape is:

- `<Entity>Repository extends CrudRepository<Entity, Id>, <Entity>RepositoryExtended`
  — the public interface callers inject.
- `<Entity>RepositoryExtended` — a plain interface declaring just the
  hand-written methods.
- `<Entity>RepositoryImpl` — implements `<Entity>RepositoryExtended`; Spring
  Data finds it by the `Impl` suffix convention and composes it into
  `<Entity>Repository`'s proxy automatically.

`Extended` names what the interface *is* (more methods on top of the
generated set) rather than how it got there (`Custom` describes the
mechanism, not the interface's role, and reads the same whether the
extension is one bespoke method or ten). Applies wherever this repository-
fragment pattern is used, not just `tn-user-service`'s `UserRepository`
(the first place it's used in this layer).

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
