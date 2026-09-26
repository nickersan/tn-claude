## Context

See `proposal.md` for why. Two services change; neither gains a new dependency.
`tn-temporary-token-service` keeps one row per owner in `token` (a generate deletes
the owner's previous row) and runs as multiple instances against one Postgres
database. `tn-auth-service` mints RS256 JWTs with jjwt.

## Goals / Non-Goals

**Goals:**
- Both limits hold across every instance of `tn-temporary-token-service`, not per
  process.
- No change to the verify response shape, and nothing that tells a caller *why* a
  verify failed (wrong, expired, or locked out all look the same).

**Non-Goals:**
- Per-IP or global rate limiting. That's the edge's job (e.g. a CDN in front of
  the consumer), and complementary to the per-owner limits here.
- Rotating refresh tokens on refresh. The current behaviour (the same refresh
  token is returned) is unchanged.
- Any change to `tn-notification-service`. Throttling generation throttles what
  a consumer can send, since a passcode is only sent after it's generated.

## Decisions

**1. The generate limit is a rolling window over a per-owner log.**
A new `generate_request` table records `(owner, created)` for each accepted
generate. A generate counts the owner's rows newer than `now - window`. If the
count has reached the limit it's rejected with 429 before anything else happens,
so the existing token is untouched. Otherwise it's accepted and logged, and the
owner's rows older than the window are deleted in the same transaction, so the
table stays small without a scheduled job. Considered: a counter column on
`token`. Rejected because a generate deletes and replaces the owner's token row,
which would reset the count.

Defaults: 5 generates per 60 minutes
(`tn.temporary-token-service.generate.limit`, `...generate.window-minutes`).

**2. The failed-attempt limit is a count on the token row.**
`token` gains `failed_attempts` (default 0). A verify with the wrong value
increments it. When it reaches the limit the token is deleted, which is how an
expired token is already handled, so nothing verifies until a new generate. The
count is per token, not per owner, so a new token starts fresh. That's safe
because Decision 1 caps how many tokens an owner can get: with the defaults, at
most 5 guesses × 5 tokens = 25 guesses per hour against 900,000 six-digit values.

Default: 5 failed attempts (`tn.temporary-token-service.verify.max-failed-attempts`).

**3. Per-owner operations serialize on a Postgres advisory lock.**
Both limits are check-then-act, and the service runs as multiple instances, so an
in-process lock is no protection (`tn-claude/standards/spring-boot/README.md`).
Generate and verify each run in one transaction that first takes
`pg_advisory_xact_lock(hashtextextended('temporary-token:' || owner, 0))`. Two
requests for the same owner, on any instances, then run one after the other, and
each sees the other's committed writes. Requests for different owners don't
contend, apart from rare hash collisions, which only serialize them. This is the
same pattern `okayat-location-service` uses for tag names. Considered: `SELECT ...
FOR UPDATE` on the token row. Rejected because generate must also serialize when
the owner has no token row yet.

**4. The token type is a `token_use` claim.**
`access` or `refresh`, set by `tn-auth-service` alone. Refresh checks it before
its existing "matches the most recently issued refresh token" check. Considered:
the RFC 9068 `typ: at+jwt` header. Rejected because it only marks access tokens
(refresh tokens have no standard marker), and a claim is what verifying code
already reads. `token_use` is the name AWS Cognito uses for the same purpose.

**5. Both services' endpoints move under `/v1/actions/`, and their controllers
follow the standard layout.** Two rules in `standards/spring-boot/README.md` were
settled during this change. Every path starts with its major version. An
operation that doesn't read or write a resource is `POST /v1/actions/<name>`
with its parameters in the body. None of the endpoints these two services expose
is a resource operation, so:
- `tn-temporary-token-service`: `/generate` becomes `/v1/actions/generate-token`,
  `/verify` becomes `/v1/actions/verify-token`, and `GET /{owner}` becomes
  `POST /v1/actions/check-expiry`, with the owner moving from the path to the
  body.
- `tn-auth-service`: `/v1/generate` becomes `/v1/actions/generate-tokens`, and
  `/v1/refresh` becomes `/v1/actions/refresh-tokens`.

These are breaking changes made while nothing consumes the new contract. Once
something does, a change like this means a `/v2`. The new 429 is not breaking,
and stays on `/v1`. `tn-temporary-token-service`'s controllers, touched here, are
also restructured to the standard's layout (an `api` interface per endpoint,
implemented in a `controller` package). While settling that layout, the
singular package name (`java/naming.md`) was applied across the tn layer:
`tn-auth-service`'s and `tn-user-service`'s `controllers` packages become
`controller`, and `tn-notification-service`'s controller moves out of `api` to
match. No behaviour changes.

## Risks / Trade-offs

- [A throttled owner can't get a new passcode for up to an hour] → Mitigation: the
  defaults are configurable per deployment. The limit protects the owner's own
  inbox or phone as much as it inconveniences them.
- [An attacker can lock a victim out by exhausting their generate limit] →
  Mitigation: an unavoidable trade-off of per-owner limits. Edge per-IP limits
  make it more expensive, and the lockout is temporary and self-clearing.
- [Refresh tokens issued before this change are rejected on refresh] → Mitigation:
  none needed. Nothing is deployed, and the fix is signing in again.
