# Standards audit — tn-auth-service, tn-user-service, tn-temporary-token-service

Read-only pass against `tn-claude/standards/**`, done before touching any of the
three services this change modifies. Findings below; which ones become tasks in
*this* change vs. get raised separately was a decision for the user, not assumed
here. **Findings 6 and 8 are now resolved** (see each) — everything else is still
open/tracked in `tasks.md`.

## Findings requiring a decision or fix

### 1. Parent version drift (severe on tn-user-service)
- `tn-auth-service` → `tn-parent 2.2.0` (current released)
- `tn-temporary-token-service` → `tn-parent 2.2.0-SNAPSHOT` — pinned to a
  **snapshot**, contradicting `maven/project-structure.md`: "Pin an explicit
  released parent version."
- `tn-user-service` → `tn-parent 1.0.1` — drastically behind. Predates Java 25,
  TSID, most of the current managed-dependency set, and the current plugin
  config. This service cannot pick up the `@Tsid` annotation or
  `logstash-logback-encoder` from `dependencyManagement` until it's bumped.

**This blocks the change as planned** — `tasks.md` §3 (tn-user-service overhaul)
assumes the current parent's managed dependencies are available. Recommend adding
a task to bump `tn-user-service` to `tn-parent 2.2.0` (or whatever is current when
implemented) before anything else in that section, and treat that bump as its own
reviewable step given how far behind it is.

### 2. `<relativePath/>` missing on all three
`maven/project-structure.md`: the empty `<relativePath/>` tag is required so the
parent resolves from the Maven repository, not a sibling checkout. None of the
three `<parent>` blocks have it — Maven's default (`../pom.xml`) applies instead.
Works by accident on a machine with a sibling `tn-parent` checkout; not guaranteed
to work elsewhere (fresh clone, CI).

### 3. `groupId` inconsistent with the documented family scheme
`maven/project-structure.md` documents `com.tn.service` as the services-family
groupId (and `tn-user-service` already uses it: `<groupId>com.tn.service</groupId>`).
`tn-auth-service` and `tn-temporary-token-service` both omit `groupId`, inheriting
the bare `com.tn` from the parent instead. `tn-claude/registry.yaml` currently
records this as-is (`groupId: com.tn`) rather than flagging it — that entry
describes current reality accurately, but the reality itself is inconsistent with
our own documented convention.

### 4. Incomplete oauth→auth rename, inside `tn-auth-service` itself
`SecurityConfig.java` uses `${tn.auth-service.token.signing.*}` properties (the
new name), but `ServiceConfig.java` — same service — still:
- names the bean method `oauthService`
- reads `${pilch.oauth-service.token.issuer:tn}`,
  `${pilch.oauth-service.token.refresh.time-to-live:...}`,
  `${pilch.oauth-service.token.access.time-to-live:...}` (the *old* `pilch`-project
  property namespace, inherited verbatim from `tn-oauth-service`, not even
  `tn.oauth-service`)
- `RefreshController`'s field and `AuthServiceTest`'s variables are all named
  `oauthService` despite being typed `AuthService`

This is exactly the kind of half-finished rename a "complete overhaul" should
clean up, not carry forward. Property prefix should be `tn.auth-service.*`
throughout; naming should be `authService` throughout.

### 5. `tn-service.PropertyLogger` used inconsistently — and is directly relevant to the new logging standard
`tn-service` (not yet catalogued — see `catalog.yaml`) already has
`com.tn.service.PropertyLogger`: an `ApplicationListener` that logs every resolved
Spring `Environment` property at startup, masking any whose **name** matches a
regex (ships with `REGEX_PASSWORD`, `REGEX_SECRET`). `tn-user-service`'s
`Application.java` registers it. **`tn-auth-service` and
`tn-temporary-token-service` do not** — both currently log every resolved
config property, including JWT signing keys and DB credentials, unmasked at
startup.

This is a different layer from what `standards/logging/README.md` currently
covers (that standard is about *business-event* logging — "issued a token",
"dispatched a message" — via `logstash-logback-encoder` +
`MaskingJsonGeneratorDecorator`; `PropertyLogger` is about *startup config*
logging). They're complementary, not duplicative, but the logging standard
should say so explicitly and require `PropertyLogger` registration alongside the
new business-log masking — otherwise a reader implementing "structured, masked
logging" from that doc alone would miss this existing, load-bearing mechanism
entirely, as two of these three services already have.

### 6. `var` used pervasively in `tn-auth-service` and `tn-temporary-token-service` — including production code
`java/idioms.md` states "`var` is not used in this codebase," distilled from
`tn-lang`/`tn-query`. That's not true of these two services:
- `AuthServiceTest.java`: every local uses `var` (one exception —
  `KeyPairGenerator generator = ...` in `keyPair()` — so even internally
  inconsistent)
- `TokenGeneratorImpl.generate()` / `TokenVerifierImpl.verify()`: `var token = ...`
  in **production** code, not just tests
- `tn-user-service.Application.java`: one instance (`var application = ...`)

This isn't a one-off slip — it's the norm in two of the three services under
review. Flagging as a genuine open question rather than a code defect: either
these services should be brought into line with the documented rule as part of
the overhaul, or the rule itself needs to be scoped ("true for `tn-lang`/
`tn-query`, not a layer-wide rule") rather than presented as universal. Worth a
decision before more code gets written either way.

**Resolved**: rule stands as written, layer-wide. All ~90 occurrences across all
three services replaced with explicit types — see `tasks.md` §2.5 and design.md
Decision 10.

## Findings that are standards-doc gaps, not code violations

### 7. JPA entities never use `final` fields
`Email`, `Token`, `User`, `RefreshToken` all have mutable (non-`final`) fields —
necessary because `@NoArgsConstructor` + Hibernate reflection-based field access
requires it. `java/idioms.md`'s "instance fields that are never reassigned are
`final`" rule doesn't carve out this exception, even though it's universal across
every JPA entity in the codebase. This is the code being consistently correct and
the standard being incomplete — recommend adding the exception to `idioms.md`
rather than treating any entity as non-compliant.

### 8. Repeating `<repositories>` in a component POM is likely redundant
`tn-parent` already declares `<repositories>` (the GitHub Packages entry), and
Maven inherits `<repositories>` from a parent automatically. `tn-lang`, `tn-query`,
and `tn-user-service` all repeat it in the child POM anyway (and
`maven/pom-style.md`'s own skeleton example currently shows repeating it);
`tn-auth-service` and `tn-temporary-token-service` correctly omit it and still
resolve fine. Worth picking one and updating `pom-style.md`'s skeleton — right now
it documents the redundant pattern as the model to follow.

**Resolved**: removed from `tn-user-service`'s POM; `pom-style.md`'s skeleton
updated to not repeat it. `tn-lang`/`tn-query` still have it — not part of this
audit's scope, same cleanup applies whenever they're next touched. See `tasks.md`
§2.6 and design.md Decision 11.

## Compliant (noted for balance, not just failures)

- Import grouping/ordering (`imports.md`) — followed correctly in every file read
  across all three services, including the jakarta/third-party/first-party
  ordering in Spring `@Configuration` classes.
- Test method naming (`should<Behaviour>When<Condition>`) — followed correctly.
- Lombok fluent accessors (no `get` prefix) — matches the documented "new
  direction" in `naming.md`.
- Interface naming (no `I` prefix), exception shape (`RuntimeException`, message
  format) — compliant.
