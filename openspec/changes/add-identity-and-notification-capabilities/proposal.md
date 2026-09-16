## Why

Requested by `okayat-platform` / `initial-capabilities`
(`identity/passwordless-login`): Okayat needs sign-up/login via either an email
address or a phone number, verified by a one-time passcode. `tn-auth-service` and
`tn-user-service` are out of date and are being **completely overhauled**, not just
extended — this is not a backward-compatibility-constrained generalisation. Their
purpose stays the same and is worth stating precisely: issue and refresh the JWTs
that identify a user throughout a system, with the token/session concern kept
deliberately separate from user profile data (an existing design decision, retained
by direction, not by default). `tn-notification-service` (dispatching the passcode)
does not exist yet. This is the first time any capability in this layer has a formal
spec — write the full target contract for each, not just a delta.

Two standards are adopted for the first time as part of this overhaul, and apply
beyond just these services going forward:
- **TSID entity identifiers** (`tn-claude/standards/java/identifiers.md`, new) —
  replacing `GenerationType.SEQUENCE`.
- **Structured, masked logging** (`tn-claude/standards/logging/README.md`, new) —
  every `java-spring-service` logs JSON and never logs a token, passcode, or full
  identifier value unmasked.

## What Changes

- `tn-auth-service`: generalise from an `Email`-only domain model to a generic
  `Identifier` (type: EMAIL | PHONE). Not required to stay backward-compatible with
  the current email-only shape — this is a complete overhaul, not an additive
  change. **BREAKING** for any existing consumer of the current shape.
  Identifier records get TSID primary keys. Structured, masked logging.
- `tn-user-service`: same generalisation, same **BREAKING** note, same TSID and
  logging adoption. Also relaxes `fullName`/`preferredName` from required to
  optional (needed for okayat's minimum-detail sign-up).
- `tn-notification-service`: **new**. Dispatch a message to an email address or a
  phone number, behind one send interface. Provider choice is this service's own
  implementation detail, not part of the contract. Structured, masked logging from
  day one — this is the service the actual passcode value flows through.
- `tn-temporary-token-service`: no identity/data-model change. First formal spec of
  its existing (already generic) contract — which surfaces that its current logging
  (`log.info("Generated token for: {}; ...", owner)`) logs the owner unmasked; that
  gets corrected as part of adopting the new logging standard, everything else about
  it is unchanged.

## Capabilities

### New Capabilities
- `tn-auth-service`: JWT access/refresh token issuance for a generic identifier (email | phone).
- `tn-user-service`: user profile keyed by a generic identifier (email | phone).
- `tn-notification-service`: dispatch a message to an email address or phone number.
- `tn-temporary-token-service`: generic one-time-token generate/verify (owner + type + TTL).

### Modified Capabilities
- none — no capability in this tree has an existing spec yet.

## Impact

- **Code**: `tn-auth-service` (`com.tn.auth.domain.Email` → generic `Identifier`;
  JWT claims), `tn-user-service` (`User` entity + repository; unique constraint
  currently on `email` alone), new `tn-notification-service` repo.
- **Data**: `tn-auth-service`'s `email` table and `tn-user-service`'s `users.email`
  column both move to the generic identifier shape, and both move from
  `GenerationType.SEQUENCE` primary keys to TSID — see `design.md` Migration Plan.
- **Dependency**: `tn-parent` needs two additions to `dependencyManagement` (neither
  present today): `net.logstash.logback:logstash-logback-encoder` for structured
  JSON logging and field masking, and
  `io.hypersistence:hypersistence-utils-hibernate-71` for the `@Tsid` Hibernate
  annotation (the raw `io.hypersistence:hypersistence-tsid` generator is already
  present, but the JPA/Hibernate integration is a separate artifact — see
  `standards/java/identifiers.md`).
- **Deprecation**: `tn-oauth-service` (predecessor of `tn-auth-service`, already
  marked deprecated in `registry.yaml`) is not touched by this change and should not
  gain the same generalisation or TSID/logging adoption — it is being retired, not
  extended.
- **Consumers**: none yet — `okayat-bff` (planned, not built) will be the first
  real consumer of the new shape. Nothing in this workspace is in production
  (see `design.md` Context), so there is no existing consumer of the current
  email-only shape to break; this is a clean replacement, not a coordinated
  migration.
- **tn-claude records**: `catalog.yaml` entries for these four services move from
  `requested_changes` (pointing at this change) to reflecting the new contract once
  archived; `registry.yaml` gains an entry for `tn-notification-service`
  (`status: planned` → `active`).
