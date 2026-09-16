## Context

See `proposal.md` for motivation. Current state, read directly from source (not
assumed):

- `tn-auth-service.AuthServiceImpl.generate(String emailAddress)` finds-or-creates
  an `Email` row and mints a JWT with `subject = email.id()` and a `CLAIM_EMAIL =
  "email"` claim carrying the address. `refresh(String token)` looks the email back
  up by the subject id. There is no non-email path anywhere in this service.
- `tn-user-service.User` has `@Column(nullable = false, unique = true) @Email
  @NotNull private String email;` — the uniqueness constraint and the validation
  annotation are both hard-coded to email.
- `tn-temporary-token-service.Token` is already identifier-agnostic: `owner` is an
  arbitrary string, `value` the code, `timeToLiveMinutes` the TTL. No identity-model
  change needed — but its `GenerateController`/`VerifyController` currently log
  `owner` unmasked (`log.info("Generated token for: {}; ...", owner)`), which fails
  the new logging standard whenever `owner` is an email/phone.
- Nothing in `tn` today dispatches anything to a person.
- Both `tn-auth-service` and `tn-user-service` currently generate primary keys via
  `GenerationType.SEQUENCE`. `tn-parent` already manages
  `io.hypersistence:hypersistence-tsid`, unused today.
- This is a **complete overhaul** of `tn-auth-service` and `tn-user-service`, not a
  backward-compatible extension — direction from the requester, not a default we
  chose. That removes the "must not break unknown consumers" constraint an additive
  generalisation would otherwise carry.
- A standards-compliance pass over all three services (per the "flag deviations
  before modifying existing code" working agreement) surfaced more than the
  identity model — see `standards-audit.md` in this change directory. The findings
  that change what this change must do are folded into Decisions/Risks/Tasks below;
  it also found `tn-service.PropertyLogger`, an existing startup-config masking
  mechanism the new logging standard needs to account for rather than duplicate.
- Deployment conventions (requested for `standards/kubernetes/README.md` and
  `standards/maven/build-and-ci.md`) were distilled from `X:\projects\pilch`, the
  system `tn` descended from — not invented fresh. Confirmed pattern: every
  deployable service has a separate `<name>-container` repo (jar stays an
  independent artifact; the container repo can weave in runtime-only
  dependencies, e.g. H2 for local); one layered Kustomize repo per *project*
  composes base + per-environment overlays. Checking `tn`'s existing repos
  against that pattern surfaced a real gap: `tn-temporary-token-service-
  container` exists and is current (previously miscatalogued as deprecated here
  — corrected in `registry.yaml`), but there is no `tn-auth-service-container` or
  `tn-user-service-container` — the oauth→auth rename moved the jar but never
  replaced the container repo, and `tn-user-service` never had one. Neither
  service can be deployed until its container repo exists — added as tasks.
- All three services currently: use the Groovy contract DSL (`src/ct/resources/
  contracts/*.groovy`, confirmed by reading `tn-auth-service`'s
  `shouldGenerateTokenPair.groovy`/`shouldRefreshTokenPair.groovy` and the file
  lists for the other two); depend on H2 (`runtime`-scope) *directly on the
  service POM itself* for `tn-auth-service` and `tn-user-service` (neither has a
  container repo yet — see Context above and `tasks.md` §3.9/§4.6);
  `tn-temporary-token-service` has it in both places at once — its own service
  POM *and* its existing `tn-temporary-token-service-container` — a small,
  separate instance of the same "runtime-only deps belong in the container repo
  only" violation, worth fixing while removing H2 anyway; have `springdoc-
  openapi-starter-webmvc-ui` available via `tn-parent` but unused — no
  controller carries an OpenAPI annotation anywhere in the three services.
- `tn-user-service` has no `api`/controller package of its own — its REST
  endpoints come entirely from `tn-data-service`'s generic
  `DataRepositoryAdaptor` CRUD framework (confirmed:
  `com.tn.user`'s only classes are `Application`, `ServiceConfiguration`,
  `User`, `UserRepository`, `UserRepositoryImpl`). That's why its Groovy
  contracts describe a generic get/post/put API rather than hand-written
  endpoints like the other two services. This means Decision 12 (OpenAPI
  annotations) may need to land on `tn-data-service` itself rather than
  per-service — not yet resolved, see `tasks.md` §4.6.
- **Nothing in `tn` (or anywhere else in this workspace) is in production.**
  These have been practice/exploratory projects; Okayat is the first one
  actually going live. That changes the weight of some caution below: there is
  no real deployed data to preserve and no unknown production consumer to
  protect — "breaking" `tn-auth-service`'s current shape costs nothing today.
  The discipline (standards, specs, testing, the audit habit) is still worth
  doing properly *because* Okayat is going live on top of it, not because tn
  already has something to lose.

## Goals / Non-Goals

**Goals:**
- A generic `Identifier` concept for `tn-auth-service` and `tn-user-service`,
  replacing the email-only model outright.
- A minimal, provider-agnostic dispatch capability new services can depend on.
- Both overhauled services (and the new one) adopt TSID identifiers and structured,
  masked logging as their first real implementations of those standards.
- Retain the existing split between token/session (`tn-auth-service`) and profile
  (`tn-user-service`) — an explicit instruction, not a default.

**Non-Goals:**
- Choosing an SMS/email provider — that's `tn-notification-service`'s own
  implementation detail (see Open Questions).
- Linking more than one identifier to a single account — out of scope until a
  consumer actually needs it.
- Changing `tn-temporary-token-service`'s data model — already generic. (Its
  logging does change — see Context.)
- Merging `tn-auth-service` and `tn-user-service` into one service — considered and
  explicitly rejected; see Decisions.
- Retrofitting TSID onto `tn-temporary-token-service` or any other existing
  service not otherwise touched by this change — per
  `tn-claude/standards/java/identifiers.md`, adopted incrementally, not as a
  blanket migration.

## Decisions

**1. `Identifier` is a value shape, not a new entity hierarchy:** `{type: EMAIL |
PHONE, value: string}`. `tn-auth-service`'s `Email` table becomes an `identifier`
table with a `type` column; `tn-user-service`'s `email` column becomes `identifier_
type` + `identifier_value`. Alternative considered: separate `PhoneAuthService` /
parallel code path — rejected, it would duplicate JWT issuance and refresh-token
logic that already exists and works for email.

**2. JWT claims are clean, not additive.** The token carries `identifierType` and
`identifier` claims only — no legacy `email` claim kept alongside for compatibility.
Alternative considered (and what an earlier draft of this change proposed): keep
the old `email` claim populated for `type = EMAIL` so unknown existing consumers
don't break — rejected once this was confirmed as a complete overhaul rather than
an additive change; carrying a compatibility shim nobody asked for adds permanent
complexity for a constraint that no longer applies. See Risks for the trade-off
this accepts.

**3. `tn-notification-service` exposes one capability, two channels.** A single
`send(Identifier, message)` — the service resolves EMAIL vs PHONE internally to an
email or SMS provider. Consumers never choose a provider or a channel-specific API.

**4. Uniqueness moves from `(email)` to `(identifier_type, identifier_value)`.**
Same account-per-identifier model as today, just widened to two types instead of
one.

**5. `fullName` and `preferredName` become optional.** They are currently
`@NotNull` on `tn-user-service`'s `User` entity. Okayat's minimum-detail sign-up
(`identity/passwordless-login` in `okayat-platform`) needs a profile to exist with
only a verified identifier. Relaxing a `NOT NULL` constraint to nullable is
backward-compatible for any existing rows (they already have values); no migration
risk beyond the column-nullability change itself. Existing callers that always
supplied both fields are unaffected.

**6. TSID replaces `GenerationType.SEQUENCE` for both services' primary keys, via
the `@Tsid` Hibernate annotation.** Per `tn-claude/standards/java/identifiers.md`:
`@Id @Tsid private Long id;`, backed by
`io.hypersistence:hypersistence-utils-hibernate-71:3.15.5` — the artifact the
hypersistence-utils project itself documents as covering Hibernate 7.1 *and* 7.2,
which matches what `tn-parent` (Spring Boot 4.0.5) manages exactly. Not a
version-mismatch guess. Column type stays `BIGINT`; no change to how ids are used
elsewhere.

**7. `tn-auth-service` and `tn-user-service` stay separate services.** Explicitly
retained by direction, considered and rejected merging them despite this being a
complete overhaul: the token/session concern (short-lived, security-sensitive,
no PII beyond the identifier) and the profile concern (longer-lived, will
accumulate more PII-shaped fields over time) have different access patterns and
different consumers-of-consumers — a resource server needs the former to validate
a request; nothing needs the latter just to authenticate one. Keeping them apart
keeps each one's blast radius smaller.

**8. Both services adopt structured, masked logging per
`tn-claude/standards/logging/README.md`.** Concretely: mask the access/refresh
token value, and mask (or replace with the internal id) the full identifier value,
in every log line either service emits. This is in addition to, not instead of,
registering `tn-service.PropertyLogger` for startup config-property masking (see
`standards-audit.md` finding 5) — `tn-user-service` already does this,
`tn-auth-service` does not; both should as part of this overhaul.

**9. Finish the oauth→auth rename inside `tn-auth-service`.** `standards-audit.md`
finding 4: the bean/field/variable name `oauthService` and the
`pilch.oauth-service.*` property prefix are leftovers from before the service was
renamed. Rename to `authService` and `tn.auth-service.*` throughout as part of
this overhaul, not left for later — carrying a half-finished rename into a
"complete overhaul" defeats the point of doing one.

**10. `var` removed from `tn-auth-service`, `tn-user-service`, and
`tn-temporary-token-service`, no rescoping of the rule.** Resolves
`standards-audit.md` finding 6: `java/idioms.md`'s "no `var`" rule stands as
written and applies layer-wide, not just to `tn-lang`/`tn-query`. Every occurrence
across all three services (production code and tests, ~90 instances) has been
replaced with an explicit type. Done ahead of the identifier/TSID work in §3/§4 —
not bundled into that diff — so those tasks start from a compliant baseline
instead of extending a violation.

**11. `<repositories>` removed from `tn-user-service`'s POM, not re-added
anywhere.** Resolves `standards-audit.md` finding 8: it's inherited from
`tn-parent` and was redundant. `maven/pom-style.md`'s skeleton updated to match
(no longer shows repeating it). `tn-auth-service` and `tn-temporary-token-service`
already omitted it correctly. `tn-lang`/`tn-query` still repeat it — out of scope
here (they weren't part of this audit), worth the same cleanup later.

**12. All three services' REST APIs get real OpenAPI docs via SpringDoc.**
Per `standards/spring-boot/README.md`: `@Tag`/`@Operation`/`@ApiResponse` on
every controller/endpoint, bumping `tn-parent`'s `springdoc-openapi-starter-
webmvc-ui` pin from `3.0.1` to `3.1.1` (known Jackson 2/3 mismatch on the
current pin — see Risks). Requested alongside the other cleanup, not because
the identity model needs it — but doing it now, while these controllers are
already being rewritten for the `Identifier` shape, is cheaper than a separate
pass later.

**13. Contract tests move from the Groovy DSL to the Java DSL.** Per
`standards/spring-boot/README.md`: `src/ct/java/contracts/*.java` (`tn-parent`'s
existing `contracts-producer-java` profile), not `src/ct/resources/contracts/
*.groovy`. All three services currently use Groovy. For `tn-auth-service` and
`tn-user-service`, the migrated contracts describe the *new* (post-overhaul)
request/response shape — there is no reason to faithfully port a contract for an
API this same change is deleting. For `tn-temporary-token-service`, whose API
doesn't change, it's a straight format migration.

**14. PostgreSQL replaces H2 everywhere — runtime and test.** Per
`standards/database/README.md`: no more embedded/file-backed H2, in any of the
three services or their container repos. `src/it` integration tests that need a
real database use Testcontainers PostgreSQL with `@ServiceConnection` (new
`tn-parent` managed dependencies: `spring-boot-testcontainers`,
`org.testcontainers:junit-jupiter`); local Kubernetes deployment uses a real
containerised Postgres instead of the file-backed H2 the `local` Kustomize
overlay used to rely on (`standards/kubernetes/README.md`, revised). Rationale:
matches what every real environment actually runs (AWS RDS PostgreSQL) — H2 was
never meaningfully testing or running what production runs. `tn-user-service`'s
current `h2` dependency lives directly in the service POM (not a container
repo, since it never had one) — that's itself a smaller instance of the
container-split violation `standards-audit.md` already flagged; removing `h2`
here also fixes that. `tn-parent` keeps managing `h2` for other, untouched
components — not removed layer-wide, just dropped from every component this
change touches.

**15. `tn-notification-service` and the new `tn-user-service-container`/
`tn-auth-service-container` start compliant with 12–14 from day one.** No
Groovy contracts, no H2, no un-annotated endpoints to begin with — same
reasoning as Decision 7 in `okayat-platform`'s `initial-capabilities` change:
nothing to migrate later if it's never non-compliant in the first place.

## Risks / Trade-offs

Not treated as a risk: breaking the current `email`-only shape. Nothing in this
workspace is in production (see Context) — there is no real consumer to protect
and no real data to lose, so this is a clean, one-way change rather than a
migration with a rollback story. Worth re-reading this section for real risk
once Okayat (or anything else depending on these services) actually ships.

- [`tn-notification-service` is a new dependency before a provider is chosen] →
  Mitigation: the contract (`send(Identifier, message)`) is provider-agnostic, so
  provider selection cannot block consumers.
- [Masking is only as good as the path list configured per service — a new field
  added later (e.g. a second token type) silently logs unmasked if nobody updates
  the decorator config] → Mitigation: no automatic enforcement exists yet; treat
  "does this log line contain a token, passcode, or full identifier?" as a required
  code-review question for these services, per `standards/logging/README.md`.
- [`@Tsid` is documented for Hibernate 7.1/7.2 but not tested by this project
  against `tn-parent`'s exact `7.2.7.Final`] → Mitigation: cover it with a
  repository/persistence test per entity that asserts a generated id is non-null
  and TSID-shaped; if the annotation ever proves incompatible in practice, fall
  back to explicit assignment (`id = TSID.Factory.getTsid().toLong()` in
  `@PrePersist`) using the already-managed `hypersistence-tsid` artifact alone.
- [Forgetting `@Tsid` on a new entity's `@Id` field leaves Hibernate without an
  identifier generation strategy] → Mitigation: this fails loudly at insert time
  (Hibernate rejects a null identifier) rather than silently producing a bad id, so
  it surfaces immediately in any test that persists the entity.
- [`tn-user-service` is pinned to `tn-parent 1.0.1`, drastically behind — see
  `standards-audit.md` finding 1] → Mitigation: bump it to the current parent as
  its own first, separately-reviewable task before the identifier/TSID/logging
  work in §3, rather than folding a large parent-version jump into the same diff
  as the overhaul.
- [`springdoc-openapi` 3.0.1, currently pinned in `tn-parent`, has a known
  Jackson 2/Jackson 3 mismatch that's real for us (`tn-parent` runs Jackson 3) —
  see Decision 12] → Mitigation: bump the pin to `3.1.1` as part of this change,
  not a follow-up.
- [`@ServiceConnection` on a bare `PostgreSQLContainer` field has a reported
  connection-resolution failure specifically on Spring Boot 4 — see Decision 14]
  → Mitigation: `database/README.md` documents the explicit-name workaround;
  confirm which is actually needed against `tn-parent`'s exact version when this
  is implemented, don't assume untested.
- [Migrating a contract's *format* (Groovy → Java) and its *content* (old API
  shape → new) in the same change makes it harder to tell a translation mistake
  from an intentional behaviour change] → Mitigation: write each migrated
  contract to describe the new, already-decided API shape directly (Decisions
  1–4), and verify it via the generated contract test passing against the real
  implementation — not by diffing against the old `.groovy` file.

## Migration Plan

No real data to migrate (see Context — nothing in this workspace is in
production). This is schema replacement, not data migration:

- `tn-auth-service`: replace the `email` table with the new `identifier` table
  (`BIGINT` primary key via `@Tsid`); drop `email`. New Flyway script, no
  backfill step.
- `tn-user-service`: replace the `email` column with `identifier_type` +
  `identifier_value` on `users`. New Flyway script, no backfill step.
- No rollback complexity beyond the usual Flyway `undo`/point-in-time restore.
- If this is ever repeated against a service that *does* have real deployed
  rows (i.e. after Okayat or anything else has shipped on top of it), redo this
  plan as an actual data migration — don't reuse this one by analogy.

## Open Questions

- Which SMS/email provider(s) `tn-notification-service` integrates with first —
  implementation detail of that service, doesn't change this contract.
