# Delegated calls — pass the user's token, never a user id

**A service calling another on a user's behalf passes that user's access token in
`X-Delegate-User-Token`** (the raw JWT, no `Bearer ` prefix;
`com.tn.service.security.DelegateUserToken.HEADER`). The receiving service
identifies the user only by verifying the token with `tn-service`'s
`AccessTokenVerifier`. It checks the signature, expiry, issuer and
`token_use` = `access`. `subjectRequired(token)` returns the user, and
`subject(token)` returns an `Optional` for the rare caller that can do without one.
An invalid token, or a missing subject where one is required, is a 401
(`InvalidAccessTokenException`).

Nothing is auto-configured. The service declares the verifier bean itself, from
`tn-auth-service`'s public key (base64 X.509) and issuer. The key and issuer are the
same for every service in a project, so they're project-level properties,
`<project>.access-token.public-key` and `<project>.access-token.issuer`, declared
once and used by each service that verifies tokens:

```java
@Bean
AccessTokenVerifier accessTokenVerifier(
  @Value("${okayat.access-token.public-key}")
  String publicKey,
  @Value("${okayat.access-token.issuer}")
  String issuer
)
  throws NoSuchAlgorithmException, InvalidKeySpecException
{
  return new AccessTokenVerifier(publicKey, issuer);
}
```

**Never accept a user id asserted in a header** (`X-User-Id` and the like). The
receiving service can't tell a real one from a forged one, so anything that can
reach it could act as any user. A verified token proves who the user is.

A call with no user (an anonymous read) simply omits the header. An endpoint that
needs a user returns 401 when the header is missing or its token fails
verification.
