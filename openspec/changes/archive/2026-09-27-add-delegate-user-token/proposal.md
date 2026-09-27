## Why

Requested by `okayat-platform` / `initial-capabilities`. When a front-facing
service (a BFF) calls an internal service on a user's behalf, the internal service
needs to know who the user is. So far `okayat-bff` has sent the user id it read
from the access token as a plain `X-User-Id` header. That isn't a standard header,
and the receiving service has to trust it blindly: anything that can reach the
service can claim to be any user.

Passing the user's access token instead lets the receiving service verify the
signature itself, so the user's identity is proven rather than asserted. Every
tn consumer with an internal service needs the same verification, so it belongs
in the tn layer rather than being copied into each service.

## What Changes

- `tn-service` gains access-token verification: it checks a `tn-auth-service`
  access token's RS256 signature against that service's public key, then its
  expiry and issuer, and requires `token_use` = `access`. It returns the token's
  subject. An invalid token is rejected with 401.
- `tn-service` names the header a delegated call carries the user's token in:
  `X-Delegate-User-Token`, holding the raw JWT with no `Bearer ` prefix.
- Nothing is auto-configured. A service that needs the verifier creates one from
  the public key (a `PublicKey`, or base64 X.509 text) and the issuer, injected
  from properties the service names itself.
- `standards/spring-boot/README.md` gains a "Delegated calls" rule. A service
  acting for a user passes the user's access token downstream in
  `X-Delegate-User-Token`. The receiving service verifies it, and never trusts a
  user id sent in a header. The internal member-resource rule stops referring to
  `X-User-Id`.

## Capabilities

### New Capabilities
- `tn-service`: verifies `tn-auth-service` access tokens, and defines the
  delegate-user-token header.

### Modified Capabilities
- none

## Impact

- `tn-service`: depends on `jjwt-api`, plus `jjwt-impl` and `jjwt-jackson` at
  runtime (all already managed by `tn-parent`). Nothing runs unless a service
  creates a verifier, so existing consumers are unaffected.
- Consumers: `okayat-bff` replaces its own verifier with this one and forwards
  the caller's token. `okayat-location-service` verifies the header instead of
  reading `X-User-Id`. Tracked in `okayat-platform`'s `initial-capabilities`.
- `catalog.yaml`: a `tn-service` entry pointing at this change until it's archived.
