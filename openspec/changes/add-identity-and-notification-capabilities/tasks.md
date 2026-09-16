## 1. tn-parent: new managed dependencies

- [ ] 1.1 Add `net.logstash.logback:logstash-logback-encoder` to `tn-parent`'s
      `dependencyManagement`; verify `mvn clean install` on `tn-parent` still
      succeeds.
- [ ] 1.2 Add `io.hypersistence:hypersistence-utils-hibernate-71:3.15.5` to
      `tn-parent`'s `dependencyManagement` (the `@Tsid` Hibernate annotation —
      see `standards/java/identifiers.md` for why `-71`, not `-72` or `-73`, is
      correct for `tn-parent`'s Hibernate `7.2.7.Final`); verify `mvn clean
      install` still succeeds. (`io.hypersistence:hypersistence-tsid`, the raw
      generator, is already managed — no change needed there.)

## 2. Cross-service hygiene (from `standards-audit.md`, before the overhaul itself)

- [ ] 2.1 Add `<relativePath/>` to the `<parent>` block in all three POMs
      (`standards-audit.md` finding 2); verify a clean checkout (no sibling
      `tn-parent` directory) still resolves the parent
- [ ] 2.2 Set `groupId` to `com.tn.service` on `tn-auth-service` and
      `tn-temporary-token-service`, matching `tn-user-service` and the documented
      family scheme (finding 3); verify `mvn clean install` and update
      `tn-claude/registry.yaml`'s `groupId` entries for both
- [ ] 2.3 Bump `tn-temporary-token-service`'s parent from `2.2.0-SNAPSHOT` to a
      released version (finding 1); verify `mvn clean install`
- [ ] 2.4 Bump `tn-user-service`'s parent from `1.0.1` to the current released
      version — as its own reviewable step, separate from the identifier/TSID/
      logging work in §4, given how far behind it is (finding 1, design.md Risk);
      verify `mvn clean install` and that existing tests still pass unchanged
      before any overhaul work starts on top of it
- [x] 2.5 Remove `var` from all three services — production code and tests
      (finding 6, design.md Decision 10); verified with
      `grep -rn '\bvar \b' src --include='*.java'` returning nothing in any of the
      three
- [x] 2.6 Remove the redundant `<repositories>` block from `tn-user-service`'s POM
      (finding 8, design.md Decision 11); `tn-auth-service`/
      `tn-temporary-token-service` already omitted it correctly. Updated
      `maven/pom-style.md`'s skeleton to match

## 3. tn-auth-service: overhaul

- [ ] 3.1 Finish the oauth→auth rename: `oauthService` → `authService`
      (bean/field/variable names in `ServiceConfig`, `RefreshController`,
      `AuthServiceTest`), `pilch.oauth-service.*` → `tn.auth-service.*` properties
      (finding 4); verify no reference to either old name remains
      (`grep -ri oauthservice`/`pilch` across the module)
- [ ] 3.2 Replace the `Email` domain model/table with a generic `Identifier` (type
      EMAIL | PHONE, value), primary key via `@Id @Tsid private Long id;` (see
      `standards/java/identifiers.md`); verify with a unit test per identifier
      type and a persistence test asserting the generated id is TSID-shaped
- [ ] 3.3 Migrate `generate`/`refresh` to the new table, carrying over existing
      `email` rows' id values unchanged (see design.md Migration Plan); verify with
      an integration test against a database seeded with pre-migration rows
- [ ] 3.4 Issue `identifierType` + `identifier` JWT claims; do not keep the old
      `email` claim (this overhaul is not required to stay backward-compatible —
      see design.md Decision 2); verify with a test asserting the JWT for each
      identifier type carries exactly the new claims
- [ ] 3.5 Confirm the service does not require, store, or return any profile field
      (name etc.) — verify by reviewing the request/response shapes against
      `specs/tn-auth-service/spec.md`'s "Token/session records are separate from
      profile data" requirement
- [ ] 3.6 Configure structured JSON logging (`logback-spring.xml`,
      `LogstashEncoder`) with `MaskingJsonGeneratorDecorator` masking the access
      token, refresh token, and identifier value fields; verify with a test that
      captures a log line for a generate/refresh call and asserts none of those
      values appear unmasked
- [ ] 3.7 Register `com.tn.service.PropertyLogger` in `Application.java` (masking
      at minimum `REGEX_PASSWORD`/`REGEX_SECRET`, plus the JWT signing-key
      property names) — currently absent, so every resolved config property logs
      unmasked at startup (finding 5); verify by checking startup log output
      contains no unmasked key material
- [ ] 3.8 Drop the old `Email` table once 3.2–3.4 are confirmed working; verify
      with a clean-database integration test
- [ ] 3.9 Create `tn-auth-service-container` (type `java-service-container`, per
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
- [ ] 4.6 Create `tn-user-service-container` — no container repo exists for this
      service either (see 3.9); verify it produces a runnable image

## 5. tn-notification-service (new)

- [ ] 5.1 Scaffold tn-notification-service (`java-spring-service`) from the
      tn-claude conventions; verify it builds via `mvn clean install`
- [ ] 5.2 Implement `send(Identifier, message)` routing to an email or SMS channel
      by identifier type; verify with a unit test per channel
- [ ] 5.3 Surface a delivery failure to the caller rather than swallowing it;
      verify with a test simulating a provider error
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
      as 3.9; verify it produces a runnable image

## 6. tn-temporary-token-service: logging fix only

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

## 7. tn-claude records

- [ ] 7.1 Update `catalog.yaml`: move the four services' entries from
      `requested_changes`/`status: requested` to reflecting the archived contract;
      verify the entries link to `openspec/specs/<service>/spec.md`
- [ ] 7.2 Add/confirm `registry.yaml` entries, including `tn-notification-service`
      moving from `status: planned` to `active`, and the `groupId` fixes from §2.2;
      verify against the actual repos
- [ ] 7.3 Fold the resolved `standards-audit.md` findings back into the standards
      themselves: the `idioms.md` final-field JPA exception (finding 7), the
      `pom-style.md` `<repositories>` skeleton (finding 8, pending the Open
      Questions decision), and a `logging/README.md` cross-reference to
      `PropertyLogger` (finding 5); verify each referenced file is updated
- [ ] 7.4 Archive this change (`openspec archive
      add-identity-and-notification-capabilities`) once 1–6 are done; verify
      `openspec validate --specs` passes afterwards
