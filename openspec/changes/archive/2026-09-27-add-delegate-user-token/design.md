## Context

`tn-auth-service` signs RS256 access tokens (10 minutes) and refresh tokens
(30 days), and every token carries `token_use`. `okayat-bff` already verifies
access tokens locally with a small jjwt-based class. `okayat-location-service` now
needs the same check for tokens the BFF passes on. `tn-service` is the library
every tn-based service already depends on, and it already carries shared
auto-configuration.

## Goals / Non-Goals

**Goals:** one implementation of access-token verification that any tn-based
service can use, and one agreed header for delegated calls.

**Non-Goals:**
- Spring Security integration or filters. Services read the header and call the
  verifier where they need the user, which keeps anonymous endpoints simple.
- Minting delegation-specific tokens (token exchange, narrower audiences). The
  user's own access token is passed as it is.
- Mapping the subject to a type. The subject is returned as the string it is;
  converting it to a numeric user id is the consumer's decision.

## Decisions

**1. Verification lives in `tn-service`, package `com.tn.service.security`.**
`AccessTokenVerifier(PublicKey, String issuer)` checks the signature, expiry and
issuer, then that `token_use` is a string equal to `access`. It has two methods:
- `Optional<String> subject(String token)`: a token can be valid and still have no
  (or a blank) subject, so absence is an empty `Optional`, never `null`.
- `String subjectRequired(String token)`: for callers that need the subject. It
  fails with `InvalidAccessTokenException("no subject")` when there isn't one.

Both throw `InvalidAccessTokenException` for an invalid token.
`InvalidAccessTokenException` is annotated 401 and never carries the cause, so an
MVC handler matching on the cause chain can't turn it into another status. A
separate artifact was considered, but every consumer already depends on
`tn-service`, and jjwt is small.

**2. The header is `X-Delegate-User-Token`, holding the raw JWT.** Its name is
the constant `DelegateUserToken.HEADER`. There's no `Bearer ` prefix: the header
only ever carries this one kind of token. The `X-` prefix is discouraged by
RFC 6648 but still common for custom headers, and the name makes the purpose
plain.

**3. Each service creates its own verifier; nothing is auto-configured.** A
service that needs one declares the bean itself, injecting the key and issuer from
properties it names for its own purpose. There's no hidden `tn.*` property that
switches behaviour on. Besides `(PublicKey, String issuer)`, the verifier has a
`(String publicKey, String issuer)` constructor taking the key as base64 X.509,
ignoring whitespace so a PEM body can be pasted in. That keeps key decoding out of
every service. Services that don't create one are unaffected.

**4. The receiving service verifies; it never trusts an id header.** Verifying
locally costs one signature check and no network hop. The token's 10-minute life
bounds how long a captured token is useful, the same as at the BFF.

## Risks / Trade-offs

- **A token that expires between the BFF and the downstream service fails with
  401.** The window is milliseconds, and the client refreshes and retries as it
  would for any 401.
- **Every downstream service needs `tn-auth-service`'s public key.** It's public,
  so configuring it more widely is harmless.
