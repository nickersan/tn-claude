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
- [ ] 3.11 Remove the `h2` runtime dependency from this service's POM; verify
      `mvn clean install` still succeeds with it gone
- [ ] 3.12 Convert `EmailRepositoryTest`/`RefreshTokenRepositoryTest` (renamed to
      match the new `Identifier` entity) to run against Testcontainers PostgreSQL
      via `@ServiceConnection` instead of H2 (design.md Decision 14); verify they
      pass against the container and check whether the bare annotation needs an
      explicit name on this Spring Boot version (design.md Risk)
- [ ] 3.13 Create `tn-auth-service-container` (type `java-service-container`, per
      `standards/kubernetes/README.md` and `standards/maven/build-and-ci.md`) —
      the oauth→auth rename moved the jar repo but never replaced
      `tn-oauth-service-container`, so no image can be built for this service
      today; verify `mvn clean install` (the `assembly`/`docker` profiles
      auto-activate on the presence of `src/main/assembly/assembly.xml` and
      `Dockerfile`) produces a runnable image

## 4. tn-user-service: overhaul

- [ ] 4.1 Replace the `email` column with `identifierType` + `identifierValue`
      (unique together), primary key via TSID (same approach as 3.2); verify with
      a repository test covering both identifier types and asserting the
      generated id is TSID-shaped
- [ ] 4.2 Relax `fullName`/`preferredName` from `@NotNull` to optional; verify a
      profile can be created with only an identifier
- [ ] 4.3 Enforce one profile per (type, value) pair; verify a duplicate-identifier
      creation is rejected
- [ ] 4.4 Confirm the service exposes no token-issuing endpoint or field; verify by
      reviewing the API against `specs/tn-user-service/spec.md`'s "This service
      does not issue or verify tokens" requirement
- [ ] 4.5 Configure structured JSON logging with the identifier value masked (same
      approach as 3.6); verify with a test asserting a profile-creation log line
      does not contain the unmasked identifier
- [ ] 4.6 Write `tn-user-service` an explicit `api`/controller package,
      replacing `tn-data-service`'s fully-generic `DataController` (design.md
      Decision 16 — resolved, not left as an investigation): REST-conventional
      `GET`/`POST`/`PUT`/`DELETE` on `/v1/users` for standard CRUD, filtering via
      `tn-query`/`QueryBuilder` (`?q=<expression>`) same as before, but hand-written
      so it's annotatable and has an explicit field-exposure surface; verify with
      controller tests covering get/create/update/delete
- [ ] 4.7 Add `POST /v1/actions/find-or-create` (`standards/spring-boot/
      README.md`'s action-endpoint convention): request body the identifier,
      response the resulting profile whether pre-existing or just created;
      implement as a single Postgres upsert (`INSERT ... ON CONFLICT
      (identifier_type, identifier_value) DO UPDATE ... RETURNING *`), not
      check-then-insert — this must be race-safe across the multiple instances
      that run in any real environment, and in-process locking provides no such
      safety; verify with a test that fires concurrent find-or-create calls for
      the same new identifier and asserts exactly one profile results
- [ ] 4.8 Paginate the list endpoint with `Pageable` (bound directly as a
      controller parameter) wrapped in `PagedModel<T>` for the response — not
      `tn-data-service`'s `$pageNumber`/`$pageSize`/`$direction` params or a raw
      `Page<T>` body (`standards/spring-boot/README.md`); verify the standard
      `page`/`size`/`sort` request params work and the response shape is stable
      across a repeated call
- [ ] 4.9 Annotate the new controller for OpenAPI; verify `/v3/api-docs`
      describes every endpoint, including the action endpoint, with the new
      identifier-based shape
- [ ] 4.10 Migrate the Groovy contracts under `src/ct/resources/contracts/user/
      {get,post,put}/*.groovy` to Java contracts describing the new
      identifier-based request/response shape, plus a new contract for the
      find-or-create action (design.md Decision 13); verify the generated
      contract tests pass and delete the `.groovy` files
- [ ] 4.11 Remove the `h2` runtime dependency from this service's POM; verify
      `mvn clean install` still succeeds with it gone
- [ ] 4.12 Convert `UserRepositoryIntegrationTest` to run against Testcontainers
      PostgreSQL via `@ServiceConnection` instead of H2 (same approach as 3.12);
      verify it passes against the container
- [ ] 4.13 Create `tn-user-service-container` — no container repo exists for this
      service either (see 3.13); verify it produces a runnable image

## 5. tn-notification-service (new)

- [ ] 5.1 Scaffold tn-notification-service (`java-spring-service`) from the
      tn-claude conventions; verify it builds via `mvn clean install`
- [ ] 5.2 Implement `send(Identifier, message)` routing to an email or SMS channel
      by identifier type; verify with a unit test per channel
- [ ] 5.3 Surface a delivery failure to the caller rather than swallowing it;
      verify with a test simulating a provider error
- [ ] 5.3a Annotate its controller for OpenAPI and write its contract tests in
      Java under `src/ct/java/contracts` from the start (design.md Decisions
      12/13/15 — nothing to migrate later if it's never non-compliant); verify
      `/v3/api-docs` describes the send endpoint and the contract tests pass
- [ ] 5.3b If this service ends up persisting anything (a delivery-record table,
      say) it uses PostgreSQL/Testcontainers from the start, never H2 (design.md
      Decision 14/15); not applicable if it turns out to be stateless — confirm
      which before treating this as done or skipped
- [ ] 5.4 Configure structured JSON logging with the message content and the
      identifier value masked from the start (this is the service the OTP flows
      through — see spec.md's rationale); verify with a test asserting a dispatch
      log line contains neither
- [ ] 5.5 Register `com.tn.service.PropertyLogger` in `Application.java` from the
      start (see 3.7 — new services should never end up without it); verify
      startup log output contains no unmasked key material
- [ ] 5.6 Integrate a real email and SMS provider (choice is this service's own
      decision — see design.md Open Questions); verify with an integration test
      against a sandbox/test account
- [ ] 5.7 Create `tn-notification-service-container`, following the same pattern
      as 3.13; verify it produces a runnable image

## 6. tn-temporary-token-service: logging, docs, contracts, and database

No identity/data-model change (its API is already identifier-agnostic) — but it
picks up the same cross-cutting cleanup as the other two: logging (already
planned), plus OpenAPI, Java contracts, and PostgreSQL/Testcontainers.

- [ ] 6.1 Confirm the written spec matches current generate/verify behaviour
      exactly — no data-model change; verify by reading
      `TokenGenerator`/`TokenVerifier` against `specs/tn-temporary-token-service/
      spec.md`
- [ ] 6.2 Fix `GenerateController`/`VerifyController` to stop logging `owner`
      unmasked (`log.info("Generated token for: {}; ...", owner)` today); adopt
      structured JSON logging with the token value and owner masked; verify with a
      test asserting neither appears unmasked in a generate/verify log line
- [ ] 6.3 Register `com.tn.service.PropertyLogger` in `Application.java` (finding
      5 — currently absent here too); verify startup log output contains no
      unmasked key material
- [ ] 6.4 Annotate `GenerateController`/`GetController`/`VerifyController` for
      OpenAPI (design.md Decision 12); verify `/v3/api-docs` describes all three
      endpoints
- [ ] 6.5 Migrate the eight Groovy contracts under `src/ct/resources/contracts/
      *.groovy` to Java contracts under `src/ct/java/contracts` — same
      request/response content, format only (this API doesn't change, unlike
      auth/user's — design.md Decision 13); verify the generated contract tests
      pass and delete the `.groovy` files
- [ ] 6.6 Remove the `h2` runtime dependency from both this service's POM *and*
      `tn-temporary-token-service-container`'s (design.md Context — it's
      currently declared in both); verify `mvn clean install` for each
- [ ] 6.7 Convert `TokenRepositoryTest` to run against Testcontainers PostgreSQL
      via `@ServiceConnection` instead of H2 (same approach as 3.12); verify it
      passes against the container

## 7. tn-claude records

- [ ] 7.1 Update `catalog.yaml`: move the four services' entries from
      `requested_changes`/`status: requested` to reflecting the archived contract;
      verify the entries link to `openspec/specs/<service>/spec.md`
- [ ] 7.2 Add/confirm `registry.yaml` entries, including `tn-notification-service`
      moving from `status: planned` to `active`, and the `groupId` fixes from §2.2;
      verify against the actual repos
- [x] 7.3 Fold the resolved `standards-audit.md` findings back into the standards
      themselves: the `idioms.md` final-field JPA exception (finding 7), the
      `pom-style.md` `<repositories>` skeleton (finding 8, resolved in 2.6), and a
      `logging/README.md` cross-reference to `PropertyLogger` (finding 5) — all
      three done directly rather than left as tasks
- [ ] 7.4 Archive this change (`openspec archive
      add-identity-and-notification-capabilities`) once 1–6 are done; verify
      `openspec validate --specs` passes afterwards
