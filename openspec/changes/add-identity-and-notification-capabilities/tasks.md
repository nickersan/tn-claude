## 1. tn-parent: new managed dependencies

- [x] 1.1 Add `net.logstash.logback:logstash-logback-encoder` to `tn-parent`'s
      `dependencyManagement`; verify `mvn clean install` on `tn-parent` still
      succeeds. Pinned `9.0` (Jackson 3, matches this pom's existing Jackson 3
      move; verified compatible with the pinned `logback-classic:1.5.32`).
- [x] 1.2 Add `io.hypersistence:hypersistence-utils-hibernate-71:3.15.5` to
      `tn-parent`'s `dependencyManagement` (the `@Tsid` Hibernate annotation —
      see `standards/java/identifiers.md` for why `-71`, not `-72` or `-73`, is
      correct for `tn-parent`'s Hibernate `7.2.7.Final`); verify `mvn clean
      install` still succeeds. (`io.hypersistence:hypersistence-tsid`, the raw
      generator, is already managed — no change needed there.)
- [x] 1.3 Bump `springdoc-openapi-starter-webmvc-ui` from `3.0.1` to `3.1.1`
      (design.md Decision 12 / Risk — Jackson 2/3 mismatch on the current pin);
      verify `mvn clean install`
- [x] 1.4 Add `org.springframework.boot:spring-boot-testcontainers` (version
      `${spring-boot.version}`, test scope) and `org.testcontainers:junit-
      jupiter:1.21.4` (test scope) to `dependencyManagement` (design.md
      Decision 14; `org.testcontainers:postgresql` is already managed); verify
      `mvn clean install`

  All four verified with `mvn dependency:resolve` (online, confirms the
  coordinates exist) and `mvn clean install` (passes) on `tn-parent`, on
  `feature/add-identity-and-notification-capabilities`, commit `5e917da`.
  Also found while doing this: `tn-parent`'s `develop` already had the
  `contracts-producer-java` Maven profile (Spring Cloud Contract Java DSL)
  and Spring Boot `4.0.5`/Jackson 3 from earlier, unrelated local commits —
  nothing else to do here for those.

## 2. Cross-service hygiene (from `standards-audit.md`, before the overhaul itself)

- [x] 2.1 Add `<relativePath/>` to the `<parent>` block in all three POMs
      (`standards-audit.md` finding 2); verify a clean checkout (no sibling
      `tn-parent` directory) still resolves the parent
- [x] 2.2 Set `groupId` to `com.tn.service` on `tn-auth-service` and
      `tn-temporary-token-service`, matching `tn-user-service` and the documented
      family scheme (finding 3); verify `mvn clean install` and update
      `tn-claude/registry.yaml`'s `groupId` entries for both
- [x] 2.3 Bump `tn-temporary-token-service`'s parent from `2.2.0-SNAPSHOT` to a
      released version (finding 1); verify `mvn clean install`
- [x] 2.4 Bump `tn-user-service`'s parent from `1.0.1` to the current released
      version — as its own reviewable step, separate from the identifier/TSID/
      logging work in §4, given how far behind it is (finding 1, design.md Risk);
      verify `mvn clean install` and that existing tests still pass unchanged
      before any overhaul work starts on top of it

  All four done together: parent bumped to the actual latest release
  (`2.2.0` — confirmed via `gh release list` against `2.2.0-SNAPSHOT` on
  `tn-parent`'s own pom, which was misleading), `<relativePath/>` added to
  all three, `groupId` set to `com.tn.service` on `tn-auth-service` and
  `tn-temporary-token-service`. `mvn clean install` passed on all three.
  Also found and fixed while updating `registry.yaml`: `tn-user-service`
  and the planned `tn-notification-service` entries were *also* stale at
  `groupId: com.tn`, contradicting their own component's declared/intended
  `com.tn.service` — fixed all four, not just the two named in this task,
  since the registry's job is to describe reality accurately.
- [x] 2.5 Remove `var` from all three services — production code and tests
      (finding 6, design.md Decision 10); verified with
      `grep -rn '\bvar \b' src --include='*.java'` returning nothing in any of the
      three
- [x] 2.6 Remove the redundant `<repositories>` block from `tn-user-service`'s POM
      (finding 8, design.md Decision 11); `tn-auth-service`/
      `tn-temporary-token-service` already omitted it correctly. Updated
      `maven/pom-style.md`'s skeleton to match

## 3. tn-auth-service: overhaul

- [x] 3.1 Finish the oauth→auth rename: `oauthService` → `authService`
      (bean/field/variable names in `ServiceConfig`, `RefreshController`,
      `AuthServiceTest`), `pilch.oauth-service.*` → `tn.auth-service.*` properties
      (finding 4); verify no reference to either old name remains
      (`grep -ri oauthservice`/`pilch` across the module)

  Also renamed in `AbstractContractTest`, `RefreshControllerIntegrationTest`,
  `GenerateControllerIntegrationTest` (same `oauthService` field, missed by
  the audit's file list but same issue). `grep -rin "oauthservice|pilch" src`
  returns nothing. Noted in passing, not fixed here: `mvn clean install`
  surfaces one pre-existing, unrelated flaky test —
  `RefreshTokenRepositoryTest.shouldFindByEmail` — saves two tokens back to
  back and orders by `created`, which collides when both land in the same
  millisecond; doesn't touch anything this task renamed, and the table it
  tests is rebuilt in 3.2/3.3 anyway.
- [x] 3.2 Replace the `Email` domain model/table with a generic `Identifier` (type
      EMAIL | PHONE, value), primary key via `@Id @Tsid private Long id;` (see
      `standards/java/identifiers.md`); verify with a unit test per identifier
      type and a persistence test asserting the generated id is TSID-shaped
- [x] 3.3 Migrate `generate`/`refresh` to the new table, carrying over existing
      `email` rows' id values unchanged (see design.md Migration Plan); verify with
      an integration test against a database seeded with pre-migration rows

  Done as 3.2/3.3/3.8 together, per design.md's actual Migration Plan
  ("no real data to migrate... schema replacement, not data migration") —
  this task's own wording ("carrying over existing email rows' id values
  unchanged") describes a staged backfill design.md explicitly rejected;
  flagging the mismatch rather than silently picking one. Rewrote
  V1_0_00/V1_0_01 in place (no separate drop-migration) since nothing has
  ever run these migrations against a real database.
- [x] 3.4 Issue `identifierType` + `identifier` JWT claims; do not keep the old
      `email` claim (this overhaul is not required to stay backward-compatible —
      see design.md Decision 2); verify with a test asserting the JWT for each
      identifier type carries exactly the new claims
- [x] 3.5 Confirm the service does not require, store, or return any profile field
      (name etc.) — verify by reviewing the request/response shapes against
      `specs/tn-auth-service/spec.md`'s "Token/session records are separate from
      profile data" requirement

  Reviewed `GenerateController.GenerateRequest`, `RefreshController.
  RefreshRequest`, `TokenPair`, and `Identifier` — none carry a name/profile
  field.
- [x] 3.6 Configure structured JSON logging (`logback-spring.xml`,
      `LogstashEncoder`) with `MaskingJsonGeneratorDecorator` masking the access
      token, refresh token, and identifier value fields; verify with a test that
      captures a log line for a generate/refresh call and asserts none of those
      values appear unmasked

  Added `log.info("Issued session"/"Refreshed session", kv("identifierType",
  ...), kv("identifierId", ...))` to `AuthServiceImpl` — deliberately logs the
  internal id, never the raw identifier value or token, per the standard's
  "log the event, not the payload" guidance; `logback-spring.xml`'s masking
  is defense-in-depth on top of that. `AuthServiceLoggingTest` captures the
  actual log event via a `ListAppender`, renders it through the same
  `LogstashEncoder`/`MaskingJsonGeneratorDecorator` config, and asserts the
  identifier value and both token values never appear.
- [x] 3.7 Register `com.tn.service.PropertyLogger` in `Application.java` (masking
      at minimum `REGEX_PASSWORD`/`REGEX_SECRET`, plus the JWT signing-key
      property names) — currently absent, so every resolved config property logs
      unmasked at startup (finding 5); verify by checking startup log output
      contains no unmasked key material

  Added a third `sensitive(".*signing.*key.*")` formatter alongside
  `REGEX_PASSWORD`/`REGEX_SECRET`, matching `tn.auth-service.token.signing.
  private-key`/`public-key`. Also had to add `tn-service` as a real dependency
  for the first time in this service, which surfaced a genuine duplicate:
  `tn-auth-service` had its own `NoopController` doing exactly what
  `tn-service`'s shared one does (`tn-user-service` already relies on the
  shared one, never had its own) — deleted the duplicate rather than working
  around the bean-name conflict.
- [x] 3.8 Drop the old `Email` table once 3.2–3.4 are confirmed working; verify
      with a clean-database integration test

  Folded into 3.2/3.3 — the migration file was rewritten in place rather
  than staged as a separate drop, so there's no old table left to drop.
- [x] 3.9 Annotate `GenerateController`/`RefreshController` for OpenAPI
      (`@Tag`/`@Operation`/`@ApiResponse` per `standards/spring-boot/README.md`);
      verify `/v3/api-docs` describes both endpoints with the new request/response
      shape and Swagger UI renders them

  `OpenApiDocsIntegrationTest` hits `/v3/api-docs` and asserts both paths are
  described. Didn't separately verify Swagger UI rendering (no browser in
  this environment) — the docs endpoint itself is the source Swagger UI
  renders from, and it's confirmed correct.
- [x] 3.10 Migrate `shouldGenerateTokenPair.groovy`/`shouldRefreshTokenPair.groovy`
      to Java contracts under `src/ct/java/contracts`, describing the new
      identifier-based request/response shape (design.md Decision 13); verify the
      generated contract tests pass and delete the `.groovy` files

  Found the `.groovy` files were never actually wired into the build (wrong
  directory — `src/ct/resources/*.groovy`, not
  `src/ct/resources/contracts/*.groovy`, so `contracts-producer-groovy` never
  activated). Also found and fixed two real bugs in `tn-parent`'s
  `contracts-producer-java` profile while getting the first real contracts
  running against it: `contract-producer.base-test-class` (tn-auth-service's
  own property) didn't match what the profile actually reads
  (`contract-producer.base-class.tests`/`base-package.tests`), and the
  profile itself set `packageWithBaseClasses` alongside `baseClassForTests`,
  which silently switches Spring Cloud Contract to package-convention base
  class discovery — broke every generated test until removed. Both fixed in
  `tn-parent` (pushed, republished) and `tn-auth-service`. Generated
  `ContractVerifierTest` passes both contracts.
- [x] 3.11 Remove the `h2` runtime dependency from this service's POM; verify
      `mvn clean install` still succeeds with it gone
- [x] 3.12 Convert `EmailRepositoryTest`/`RefreshTokenRepositoryTest` (renamed to
      match the new `Identifier` entity) to run against Testcontainers PostgreSQL
      via `@ServiceConnection` instead of H2 (design.md Decision 14); verify they
      pass against the container and check whether the bare annotation needs an
      explicit name on this Spring Boot version (design.md Risk)

  Confirmed the bare annotation fails on this Spring Boot version — needed
  `@ServiceConnection("postgresql")`. Also needed two dependencies not called
  out anywhere: `org.postgresql:postgresql` (the JDBC driver itself) and
  `org.flywaydb:flyway-database-postgresql` (Flyway's Postgres dialect) —
  both now documented in `standards/database/README.md`. Removing H2 meant
  every full `@SpringBootTest` context (not just `@DataJpaTest` ones) needed
  its own Postgres container too, since Hibernate/Flyway wire a DataSource
  at startup regardless of whether a given test touches it — added a shared
  `AbstractPostgresIntegrationTest` base rather than repeating the container
  four times.
- [x] 3.13 Create `tn-auth-service-container` (type `java-service-container`, per
      `standards/kubernetes/README.md` and `standards/maven/build-and-ci.md`) —
      the oauth→auth rename moved the jar repo but never replaced
      `tn-oauth-service-container`, so no image can be built for this service
      today; verify `mvn clean install` (the `assembly`/`docker` profiles
      auto-activate on the presence of `src/main/assembly/assembly.xml` and
      `Dockerfile`) produces a runnable image

  Created private repo `nickersan/tn-auth-service-container`
  (https://github.com/nickersan/tn-auth-service-container), pushed to `main`
  (new repo, no CI risk). `mvn clean install` produces the image; actually
  ran it (not just built it) and caught a real defect the build alone
  wouldn't show: the pilch-derived Dockerfile template pins
  `eclipse-temurin:21.0.2_13-jdk-alpine`, but `tn-parent` targets Java 25 —
  the image crashed with `UnsupportedClassVersionError` until bumped to
  `eclipse-temurin:25-jdk-alpine`. After that it starts the JVM and reaches
  Spring Boot's own startup sequence, failing only on the expected "no
  datasource configured" (no env vars supplied to this standalone smoke
  test) — a deployment-config gap, not a packaging defect. Flagged in
  `registry.yaml`, not fixed here, that the sibling container repos likely
  have the same Java-version mismatch, unverified.

## 4. tn-user-service: overhaul

- [x] 4.1 Replace the `email` column with `identifierType` + `identifierValue`
      (unique together), primary key via TSID (same approach as 3.2); verify with
      a repository test covering both identifier types and asserting the
      generated id is TSID-shaped
- [x] 4.2 Relax `fullName`/`preferredName` from `@NotNull` to optional; verify a
      profile can be created with only an identifier
- [x] 4.3 Enforce one profile per (type, value) pair; verify a duplicate-identifier
      creation is rejected

  Done together: `User` rewritten (`identifierType`/`identifierValue`, `@Tsid`,
  nullable `fullName`/`preferredName`), migration rewritten in place (no real
  deployed data, same as 3.2/3.3), unique constraint on
  `(identifier_type, identifier_value)`. Duplicate-creation rejection verified
  via `UserController`'s `DataIntegrityViolationException` → 409 handler
  (finding 4.6 below), not a separate repository test — the constraint itself
  is exercised there.
- [x] 4.4 Confirm the service exposes no token-issuing endpoint or field; verify by
      reviewing the API against `specs/tn-user-service/spec.md`'s "This service
      does not issue or verify tokens" requirement

  Reviewed `UserController`/`UserActionsController`/`UserResponse` — no token
  field or endpoint anywhere.
- [x] 4.5 Configure structured JSON logging with the identifier value masked (same
      approach as 3.6); verify with a test asserting a profile-creation log line
      does not contain the unmasked identifier

  `logback-spring.xml` masks `identifierValue`; `UserController`/
  `UserActionsController` log `identifierType` + the internal `userId` only,
  never the raw value, same "log the event, not the payload" approach as 3.6.
  `PropertyLogger` was already registered here (finding 5 only applied to
  auth-service and temp-token-service).
- [x] 4.6 Write `tn-user-service` an explicit `api`/controller package,
      replacing `tn-data-service`'s fully-generic `DataController` (design.md
      Decision 16 — resolved, not left as an investigation): REST-conventional
      `GET`/`POST`/`PUT`/`DELETE` on `/v1/users` for standard CRUD, filtering via
      `tn-query`/`QueryBuilder` (`?q=<expression>`) same as before, but hand-written
      so it's annotatable and has an explicit field-exposure surface; verify with
      controller tests covering get/create/update/delete

  `UserController` (CRUD) + `UserActionsController` (find-or-create).
  `QueryBuilder` kept exactly as before, just called directly instead of via
  the generic controller. `UserResponse` is an explicit record, not the JPA
  entity, for the explicit field-exposure surface. Duplicate-identifier POST
  maps `DataIntegrityViolationException` → 409. Verified with
  `UserControllerIntegrationTest` (get, delete) and the six Java contracts
  (get, list, create, create-conflict-shaped validation, find-or-create,
  404).
- [x] 4.7 Add `POST /v1/actions/find-or-create` (`standards/spring-boot/
      README.md`'s action-endpoint convention): request body the identifier,
      response the resulting profile whether pre-existing or just created;
      implement as a single Postgres upsert (`INSERT ... ON CONFLICT
      (identifier_type, identifier_value) DO UPDATE ... RETURNING *`), not
      check-then-insert — this must be race-safe across the multiple instances
      that run in any real environment, and in-process locking provides no such
      safety; verify with a test that fires concurrent find-or-create calls for
      the same new identifier and asserts exactly one profile results

  `UserRepositoryImpl.findOrCreate` — native query, TSID generated in Java
  (`TSID.fast()`) since a native insert bypasses Hibernate's own `@Tsid`
  generator. `UserRepositoryFindOrCreateConcurrencyIntegrationTest` fires 16
  concurrent calls for the same new identifier via an `ExecutorService` and
  asserts exactly one row results — this test is what actually proved the
  race-safety claim; writing the upsert alone wouldn't have. Surfaced a real
  bug while getting it running: see 4.12's note on the Testcontainers
  singleton-container gotcha.
- [x] 4.8 Paginate the list endpoint with `Pageable` (bound directly as a
      controller parameter) wrapped in `PagedModel<T>` for the response — not
      `tn-data-service`'s `$pageNumber`/`$pageSize`/`$direction` params or a raw
      `Page<T>` body (`standards/spring-boot/README.md`); verify the standard
      `page`/`size`/`sort` request params work and the response shape is stable
      across a repeated call

  `UserController.list` takes `Pageable` directly, wraps the result in
  `PagedModel<UserResponse>`. `?q=` filtering kept separate from Spring's own
  `page`/`size`/`sort` params (not passed through `QueryBuilder`, which still
  only knows the old `$`-prefixed reserved names) — avoids a real collision
  that would otherwise reject `page`/`size`/`sort` as unknown query fields.
- [x] 4.9 Annotate the new controller for OpenAPI; verify `/v3/api-docs`
      describes every endpoint, including the action endpoint, with the new
      identifier-based shape

  `OpenApiDocsIntegrationTest` asserts both `/v1/users` and
  `/v1/actions/find-or-create` are described.
- [x] 4.10 Migrate the Groovy contracts under `src/ct/resources/contracts/user/
      {get,post,put}/*.groovy` to Java contracts describing the new
      identifier-based request/response shape, plus a new contract for the
      find-or-create action (design.md Decision 13); verify the generated
      contract tests pass and delete the `.groovy` files

  Replaced all 30 Groovy contracts and their four Java base classes
  (`Base`/`UserGetBase`/`UserPostBase`/`UserPutBase`/`UserSaveBase`) — those
  were built entirely around the generic `DataApi`/`DataController` this
  change deletes, including validation contracts
  (missing-fullName/preferredName) for a rule that no longer exists (4.2).
  Six new Java contracts cover the new controllers' core behaviour
  (get/404/list/create/create-validation/find-or-create) — a representative
  set, not a 1:1 port of all 30, per design.md Decision 13. Had to also fix
  `contract-producer.base-class.package` (a stale Groovy-profile-era property
  name) to `contract-producer.base-class.tests`/`base-package.tests`, same
  issue 3.10 found and fixed for `tn-auth-service`.
- [x] 4.11 Remove the `h2` runtime dependency from this service's POM; verify
      `mvn clean install` still succeeds with it gone
- [x] 4.12 Convert `UserRepositoryIntegrationTest` to run against Testcontainers
      PostgreSQL via `@ServiceConnection` instead of H2 (same approach as 3.12);
      verify it passes against the container

  Same `org.postgresql:postgresql` + `flyway-database-postgresql` +
  `@ServiceConnection("postgresql")` needs as 3.12. Also found two more real
  issues specific to this service, now fixed in `tn-parent` (pushed,
  republished) and documented centrally so `tn-notification-service`/
  `tn-temporary-token-service` don't hit them blind:
  - `tn-query-jpa` transitively pulls `spring-data-commons:3.4.4` and
    `jakarta.persistence-api:3.1.0`, both incompatible with what Boot 4.0.5
    itself manages (`RepositoryFragmentsContributor`, `FindOption` missing
    respectively) — excluded both from `tn-data-service-jpa`'s dependency.
  - Spring MVC's `@PathVariable`/`@RequestParam` binding by name needs the
    `-parameters` javac flag, which `tn-parent` didn't set — added it there
    (global fix, every future `@PathVariable` usage hits this identically).
  - The shared `AbstractPostgresIntegrationTest` base class's
    `@Testcontainers`/`@Container` fields stop the container after the first
    extending test class finishes, breaking every other class sharing it in
    the same Surefire-reused JVM — switched to Testcontainers' documented
    singleton-container pattern (manual start, never stop); see
    `standards/database/README.md`. Also fixed proactively in
    `tn-auth-service`, which has the identical pattern.
- [x] 4.13 Create `tn-user-service-container` — no container repo exists for this
      service either (see 3.13); verify it produces a runnable image

  Created private repo `nickersan/tn-user-service-container`
  (https://github.com/nickersan/tn-user-service-container), pushed to `main`
  (new repo, no CI risk). Used `eclipse-temurin:25-jdk-alpine` from the
  start (learned from 3.13). Actually ran the built image; reaches Spring
  Boot's own startup sequence, failing only on the expected "no datasource
  configured" (no env vars in this standalone smoke test).

## 5. tn-notification-service (new)

- [x] 5.1 Scaffold tn-notification-service (`java-spring-service`) from the
      tn-claude conventions; verify it builds via `mvn clean install`
- [x] 5.2 Implement `send(Identifier, message)` routing to an email or SMS channel
      by identifier type; verify with a unit test per channel
- [x] 5.3 Surface a delivery failure to the caller rather than swallowing it;
      verify with a test simulating a provider error
- [x] 5.3a Annotate its controller for OpenAPI and write its contract tests in
      Java under `src/ct/java/contracts` from the start (design.md Decisions
      12/13/15 — nothing to migrate later if it's never non-compliant); verify
      `/v3/api-docs` describes the send endpoint and the contract tests pass
- [x] 5.3b If this service ends up persisting anything (a delivery-record table,
      say) it uses PostgreSQL/Testcontainers from the start, never H2 (design.md
      Decision 14/15); not applicable if it turns out to be stateless — confirm
      which before treating this as done or skipped
- [x] 5.4 Configure structured JSON logging with the message content and the
      identifier value masked from the start (this is the service the OTP flows
      through — see spec.md's rationale); verify with a test asserting a dispatch
      log line contains neither
- [x] 5.5 Register `com.tn.service.PropertyLogger` in `Application.java` from the
      start (see 3.7 — new services should never end up without it); verify
      startup log output contains no unmasked key material

  5.1–5.5, 5.3a, 5.3b done together as the initial scaffold. `NotificationSender.
  send(Identifier, message)` routes via a `Map<IdentifierType, NotificationChannel>`
  built in `ServiceConfig` (`NotificationSenderImpl`); `NotificationSenderImplTest`
  covers EMAIL and PHONE routing plus a channel-throws-`NotificationDeliveryException`
  case (5.2/5.3). The controller (`NotificationActionsController`, `POST /v1/actions/
  send-notification` per the action-endpoint convention — dispatch isn't a resource
  CRUD verb) maps `NotificationDeliveryException` to `502`, not a swallowed/caught
  failure — `NotificationActionsControllerIntegrationTest` and the
  `ShouldReturnBadGatewayWhenDeliveryFails` contract both verify this at the HTTP
  layer. OpenAPI annotations present from the start; `OpenApiDocsIntegrationTest`
  confirms `/v3/api-docs` describes the endpoint. Java DSL contracts
  (`ShouldSendNotification`, `ShouldReturnBadGatewayWhenDeliveryFails`) from the
  start, no Groovy ever written. 5.3b: confirmed not applicable — this service is
  stateless (no delivery-record persistence), so no PostgreSQL/Testcontainers
  dependency was added; noted in `README.md` rather than silently skipped.
  Structured logging masks `identifierValue` and `message` by path in
  `logback-spring.xml`; `NotificationSenderLoggingTest` proves a dispatch log line
  never contains either unmasked (same `ListAppender` + re-encode approach as
  `AuthServiceLoggingTest`). `PropertyLogger` registered in `Application.java`
  from the start (`REGEX_PASSWORD`/`REGEX_SECRET` — no signing-key-shaped property
  exists in this service yet). `mvn clean install` passes (unit + `src/it` +
  generated contract tests). Pushed to
  `feature/add-identity-and-notification-capabilities` on the new private repo
  `nickersan/tn-notification-service`.
- [ ] 5.6 Integrate a real email and SMS provider (choice is this service's own
      decision — see design.md Open Questions); verify with an integration test
      against a sandbox/test account

  Deliberately not done — explicit user direction (the provider question was put
  to the user via `AskUserQuestion` and declined; the user asked for a stub
  instead, to be implemented "according to cloud services available" later).
  What exists instead: `NotificationChannel` (the seam) with two placeholder
  implementations, `service/channel/StubEmailChannel`/`StubSmsChannel` — each
  accepts a dispatch and returns without contacting any provider, no-op by
  design, not a fake success dressed up as a real one (no network call, no
  fabricated provider response). Swapping in a real provider later means adding
  a new `NotificationChannel` implementation and rewiring `ServiceConfig`'s two
  `Map.of(...)` entries — `NotificationSender`, the contract every consumer
  depends on, does not change. Left unchecked deliberately — this task means
  real provider integration, which has not happened; don't mark it done from
  the stub existing.

  Refined per follow-up user direction: the stubs now log the recipient and
  message at INFO in the clear (plain SLF4J params, not a structured/masked
  kv field), specifically so a dispatched code can be read from the logs
  during manual testing — verified by `StubEmailChannelTest`/
  `StubSmsChannelTest`. Both are commented as a deliberate, stub-only
  exception to the masking standard; a real provider implementation must not
  carry this over. Fixed a real bug found while verifying it: the original
  `kv("message", message)` in `NotificationSenderImpl` collided with
  LogstashEncoder's own built-in `message` field, so masking it also
  clobbered every dispatch log line's own "Notification dispatched" text —
  renamed to `content` (confirmed by actually encoding a test log event
  through the real encoder+decorator, not assumed).
- [x] 5.7 Create `tn-notification-service-container`, following the same pattern
      as 3.13; verify it produces a runnable image

  Created private repo `nickersan/tn-notification-service-container`, pushed to
  `main` (new repo, no CI risk). `eclipse-temurin:25-jdk-alpine` from the start
  (learned from 3.13/4.13, not rediscovered). Actually ran the built image (not
  just built it): unlike `tn-auth-service-container`/`tn-user-service-container`,
  which stop at "no datasource configured" since this service is stateless it
  reaches full Spring Boot startup — Tomcat serving on 8080, no missing
  dependency at all.

## 6. tn-temporary-token-service: logging, docs, contracts, and database

No identity/data-model change (its API is already identifier-agnostic) — but it
picks up the same cross-cutting cleanup as the other two: logging (already
planned), plus OpenAPI, Java contracts, and PostgreSQL/Testcontainers.

- [x] 6.1 Confirm the written spec matches current generate/verify behaviour
      exactly — no data-model change; verify by reading
      `TokenGenerator`/`TokenVerifier` against `specs/tn-temporary-token-service/
      spec.md`
- [x] 6.2 Fix `GenerateController`/`VerifyController` to stop logging `owner`
      unmasked (`log.info("Generated token for: {}; ...", owner)` today); adopt
      structured JSON logging with the token value and owner masked; verify with a
      test asserting neither appears unmasked in a generate/verify log line
- [x] 6.3 Register `com.tn.service.PropertyLogger` in `Application.java` (finding
      5 — currently absent here too); verify startup log output contains no
      unmasked key material
- [x] 6.4 Annotate `GenerateController`/`GetController`/`VerifyController` for
      OpenAPI (design.md Decision 12); verify `/v3/api-docs` describes all three
      endpoints
- [x] 6.5 Migrate the eight Groovy contracts under `src/ct/resources/contracts/
      *.groovy` to Java contracts under `src/ct/java/contracts` — same
      request/response content, format only (this API doesn't change, unlike
      auth/user's — design.md Decision 13); verify the generated contract tests
      pass and delete the `.groovy` files
- [x] 6.6 Remove the `h2` runtime dependency from both this service's POM *and*
      `tn-temporary-token-service-container`'s (design.md Context — it's
      currently declared in both); verify `mvn clean install` for each
- [x] 6.7 Convert `TokenRepositoryTest` to run against Testcontainers PostgreSQL
      via `@ServiceConnection` instead of H2 (same approach as 3.12); verify it
      passes against the container

  6.1: reviewed `TokenGenerator`/`TokenVerifier`/`Token` against `specs/
  tn-temporary-token-service/spec.md` — owner stays an opaque string, no
  identifier-shape validation anywhere; matches. Baseline check before touching
  anything: `mvn clean test` failed with 13 errors on this service's *existing*
  `tn-parent 2.2.0` pin (`@MockBean` already broken under Boot 4) — confirmed,
  not assumed, then fixed as part of 6.2–6.7 below rather than left broken.
  6.2/6.3: `logback.xml` (plain-text pattern layout) replaced with
  `logback-spring.xml` (`LogstashEncoder` + `MaskingJsonGeneratorDecorator`
  masking `owner`/`token` by path); `GenerateController`/`VerifyController` log
  via `kv("owner", ...)` structured arguments instead of string interpolation.
  `PropertyLogger` registered in `Application.java` (`REGEX_PASSWORD`/
  `REGEX_SECRET` — no signing-key-shaped property exists in this service).
  6.4: `@Tag`/`@Operation`/`@ApiResponse` added to all three controllers (one
  shared "Tokens" tag); new `OpenApiDocsIntegrationTest` asserts `/v3/api-docs`
  describes `/generate`, `/verify`, and `/{owner}`.
  6.5: all 8 Groovy contracts ported 1:1 (same request/response content) to
  `src/ct/java/contracts/*.java`; the non-deterministic `expires` field uses
  `Response.anyPositiveInt()` (Java DSL's own regex-matcher sugar — no
  `consumer(regex(...))` helper exists on the Java side the way it did in
  Groovy; confirmed by decompiling the actual `Response` class rather than
  guessing an API). Also fixed the same `contract-producer.base-test-class` →
  `contract-producer.base-class.tests`/`base-package.tests` property-name bug
  3.10/4.10 found in the other two services.
  6.6/6.7: `h2` removed from both this service's pom and the container's;
  `TokenRepositoryTest` declares its own local `@Container`/
  `@ServiceConnection("postgresql")` field (not a shared base — this is the
  only `@DataJpaTest` class here, so the singleton-container gotcha doesn't
  apply, per `standards/database/README.md`'s note on that). The other four
  full-context test classes (`AbstractContractTest` and the three src/it
  classes plus the new OpenAPI one) share a new `AbstractPostgresIntegrationTest`
  singleton-pattern base, same as 3.12/4.12.

  Found and fixed along the way, not left as silent workarounds:
  - `GenerateController` had a stray `@RequestMapping("/v1")` class-level
    prefix that didn't match its own contract/integration test (both posted to
    plain `/generate`) or the other two controllers' convention — removed.
  - `AbstractContractTest`'s expiry contract never mocked
    `Supplier<LocalDateTime>`, relying on two real `LocalDateTime.now()` calls
    (at token-creation and at expiry-check) landing in different clock ticks —
    flaky on a coarse system clock, and it did fail once while getting this
    green. Fixed by mocking `localDateTimeSupplier` with a fixed offset, same
    pattern `GetControllerIntegrationTest` already used correctly.
  - The local `NoopController` was a duplicate of `tn-service`'s own (same
    fix as 3.7); deleted once `tn-service` was added as a real dependency.
  - `tn-temporary-token-service-container`'s jar dependency still referenced
    the pre-2.2-groupId-fix `com.tn:tn-temporary-token-service` instead of
    `com.tn.service:tn-temporary-token-service` — fixed.
  - `tn-temporary-token-service-container`'s Dockerfile base image was
    `eclipse-temurin:21.0.2_13-jdk-alpine` — the exact defect flagged as
    unverified-but-likely in `registry.yaml` after 3.13 caught it in
    `tn-auth-service-container`; confirmed here too and bumped to
    `eclipse-temurin:25-jdk-alpine`, verified by actually running the built
    image, not just building it.
  - Container's own `tn-parent` pin was very stale (`0.0.01-SNAPSHOT`,
    flagged in `registry.yaml`) — bumped to `2.2.0-SNAPSHOT` alongside the
    jar's own temporary pin.

  `mvn clean install` is green on both repos; both pushed
  (`tn-temporary-token-service` to the shared feature branch,
  `tn-temporary-token-service-container` to `main`, no CI workflows on either
  repo so no deploy risk).

## 7. tn-claude records

- [ ] 7.1 Update `catalog.yaml`: move the four services' entries from
      `requested_changes`/`status: requested` to reflecting the archived contract;
      verify the entries link to `openspec/specs/<service>/spec.md`

  Not done yet, deliberately — this task means the *archived* contract
  (`spec:` pointing at the permanent `openspec/specs/<service>/spec.md`,
  replacing `spec_change:`), which only exists once 7.4 archives the change,
  which itself waits on 5.6 (see below). Doing this now would mean pointing
  at a spec.md that doesn't exist yet at that path. Left unchecked rather than
  faked.
- [x] 7.2 Add/confirm `registry.yaml` entries, including `tn-notification-service`
      moving from `status: planned` to `active`, and the `groupId` fixes from §2.2;
      verify against the actual repos

  `tn-notification-service` moved to `status: active` with a note on what it
  actually does and 5.6's open status; new `tn-notification-service-container`
  entry added; `tn-temporary-token-service-container`'s note updated with the
  §6.6 fixes (groupId, H2, base image, parent pin). §2.2's `groupId` fixes were
  already correct in `registry.yaml` — confirmed against the actual repos
  (`com.tn.service` on all four services), not re-changed.
- [x] 7.3 Fold the resolved `standards-audit.md` findings back into the standards
      themselves: the `idioms.md` final-field JPA exception (finding 7), the
      `pom-style.md` `<repositories>` skeleton (finding 8, resolved in 2.6), and a
      `logging/README.md` cross-reference to `PropertyLogger` (finding 5) — all
      three done directly rather than left as tasks
- [ ] 7.4 Archive this change (`openspec archive
      add-identity-and-notification-capabilities`) once 1–6 and 8 are done;
      verify `openspec validate --specs` passes afterwards

  Not done — sections 1, 2, 3, 4, and 6 are fully complete; section 5 is
  complete except 5.6 (a real email/SMS provider), which is deliberately open
  pending a provider decision, not an oversight. Section 8 (multi-identifier
  accounts, design.md Decisions 17-23) was added after this task was last
  updated — also not done. This task's own wording means archiving now, with
  5.6 and all of §8 still open, would be premature — left for a follow-up
  once both are resolved.

## 8. Multi-identifier accounts (added after initial build — design.md Decisions 17-23)

Everything below modifies already-built, tested, committed code from §§1-6 —
including task 3.2/3.3's original `identifier` table, not just green-field
Account work (design.md Decision 23 replaces that table, not just the
not-yet-built account-linking design that was going to sit alongside it).
Baseline-check existing tests before touching them (as §6.1 did), and expect
to rewrite contracts describing either the old email-only or the old
identifier-table shape rather than extend them (see the Risk design.md
records for this section).

- [ ] 8.1 Replace `tn-auth-service`'s `identifier` table (built in 3.2/3.3)
      with an `account` table carrying `email`, `phone`, and `whatsapp` as
      individually-`UNIQUE`, nullable columns — no separate identifier
      entity survives (design.md Decision 23); update `generate(type, value)`
      to resolve `type` to its column, look up an account by that column's
      value, and mint the JWT with `sub` = account id; on no match, create a
      new account with that column set, via a race-safe upsert (`INSERT ...
      ON CONFLICT (<column>) DO UPDATE ... RETURNING *`, one variant per
      column, same discipline as `tn-user-service`'s existing find-or-create)
      (design.md Decisions 17-18, 23); verify with tests that signing in with
      a value already held by an account returns a session for it without
      duplicating anything, that a brand-new value creates a new account, and
      a concurrency test firing simultaneous first-sign-ins for the same new
      value asserts exactly one account results
- [ ] 8.2 Add `WHATSAPP` as the third column (`whatsapp`) on `account` and the
      third value of the shared `IdentifierType` enum (`tn-auth-service`,
      `tn-user-service`); verify a token pair can be issued for a WhatsApp
      identifier the same way as email/phone (design.md Decisions 22-23)
- [ ] 8.3 Implement "link an additional identifier to my account": given an
      authenticated caller and a `(type, value)`, set the matching column on
      the caller's account if it is currently unset, race-safe against a
      concurrent link attempt for the same value (same upsert discipline as
      8.1); reject if that value already belongs to a different account;
      no-op if the caller's own account already holds that exact value in
      that column; reject if that column already holds a *different* value on
      the caller's own account (design.md Decision 19); verify with tests
      covering all four outcomes, plus a concurrency test for two simultaneous
      first-links of the same new value by different accounts
- [ ] 8.4 Rekey `tn-user-service`'s `User` from `(identifierType,
      identifierValue)` to a single unique `accountId`; remove the identifier
      columns entirely — this service no longer stores or validates an
      identifier value (design.md Decision 21); verify with tests covering
      find-or-create by account id, duplicate-account rejection, and that the
      old identifier-keyed contract tests have been rewritten (not left
      passing against a shape that no longer exists) to describe the new one
- [ ] 8.5 Update both services' Java DSL contract tests and OpenAPI docs to
      describe the account-keyed shapes (request/response bodies, the new
      link endpoint); verify the generated contract tests pass against the
      reworked implementation, not the pre-rework `.java` contract files left
      unchanged
- [ ] 8.6 Add `StubWhatsAppChannel` to `tn-notification-service` (same
      no-op-but-logs-in-the-clear shape as `StubEmailChannel`/
      `StubSmsChannel`, same deliberate non-goal of a real provider — design.md
      Decision 22); verify with a test mirroring `StubEmailChannelTest`/
      `StubSmsChannelTest`
- [ ] 8.7 Re-run the existing find-or-create concurrency tests
      (`UserRepositoryFindOrCreateConcurrencyIntegrationTest`'s account-id
      equivalent, and a new one for 8.3's identifier-link) against the
      reworked schema; verify the race-safety claim is proven again, not
      assumed to still hold because the SQL pattern looks the same
