## Why

Requested by `okayat-platform` / `initial-capabilities`, while starting `okayat-bff`.
Building the passwordless login on top of the tn layer surfaced three gaps that
every consumer of these services would share, so they belong here rather than in
one project's BFF:

- `tn-temporary-token-service` has no limit on wrong guesses. A six-digit numeric
  passcode can be brute-forced within its time-to-live: account takeover.
- Nothing limits how often a passcode can be generated for one owner. A consumer
  that sends each passcode by SMS or email can be used to flood someone's phone or
  inbox, or to run up delivery costs. `okayat-platform`'s `identity/passwordless-
  login` spec requires per-identifier throttling, and the throttle has to hold
  across every instance of the consumer. This service already keeps per-owner
  state in Postgres, which a stateless BFF doesn't have.
- `tn-auth-service`'s access tokens (10 minutes) and refresh tokens (30 days) carry
  identical claims. A service verifying an access token can't tell them apart, so
  a leaked refresh token works as a 30-day access token.

## What Changes

- `tn-temporary-token-service`: limit how many tokens can be generated for one owner
  within a time window. A generate over the limit is rejected, and the owner's
  existing token is left as it was. Generate gains a new failure response (429).
  That's not a breaking change under `standards/spring-boot/README.md`'s
  versioning rule, so it stays on `/v1`.
- `tn-temporary-token-service`: limit failed verification attempts per token. Once
  the limit is reached the token is invalidated, and even the correct value then
  fails until a new token is generated. The verify response is unchanged.
- `tn-temporary-token-service`: its endpoints move under `/v1` and, since none of
  them reads or writes a resource, under `/v1/actions/` (per
  `standards/spring-boot/README.md`'s versioning and actions rules):
  `POST /v1/actions/generate-token`, `POST /v1/actions/verify-token`, and
  `POST /v1/actions/check-expiry`, which replaces `GET /{owner}` and takes the
  owner in the body. It was the one tn service still serving unversioned paths.
  **BREAKING** for any caller of the old paths; none exists yet (`okayat-bff`
  isn't built).
- `tn-auth-service`: every issued token carries a claim stating whether it is an
  access or a refresh token, added by the service itself (still no caller-supplied
  claims). Refresh rejects a token that isn't a refresh token.
- `tn-auth-service`: its endpoints move under `/v1/actions/` for the same reason:
  `POST /v1/actions/generate-tokens` and `POST /v1/actions/refresh-tokens`.
  **BREAKING** for any caller of `/v1/generate` and `/v1/refresh`; none exists
  yet.

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `tn-temporary-token-service`: adds generation throttling per owner and a
  failed-attempt limit per token.
- `tn-auth-service`: every token states its type; refresh accepts only refresh
  tokens.

## Impact

- `tn-temporary-token-service`: a new Flyway migration (a per-owner generate log and
  a failed-attempt count on each token), and both limits as configuration
  properties with defaults.
- `tn-auth-service`: a new claim in both token kinds. Refresh tokens issued before
  this change lack the claim and will be rejected on refresh, so their holders
  must sign in again. Nothing is deployed yet, so no one is affected in practice.
- Consumers: `okayat-bff` maps a throttled generate (429) to its own "too many
  requests" response, and accepts only tokens whose type claim is `access` as
  bearer tokens. Tracked in `okayat-platform`'s `initial-capabilities`.
- `catalog.yaml`: `tn-temporary-token-service` and `tn-auth-service` point at this
  change until it's archived.
