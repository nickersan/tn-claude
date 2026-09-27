## 1. tn-service

- [x] 1.1 Add `AccessTokenVerifier`, `InvalidAccessTokenException` (401, no cause)
      and `DelegateUserToken.HEADER` under `com.tn.service.security` (design.md
      Decisions 1-2); verify with unit tests for a valid access token, a refresh
      token, a missing or non-string `token_use`, a missing subject (empty from
      `subject`, rejected by `subjectRequired`), an expired token, another key,
      another issuer and a malformed token
- [x] 1.2 Add a `(String publicKey, String issuer)` constructor taking base64
      X.509 text, with no auto-configuration (Decision 3); verify with a unit test
      that a MIME-encoded key (with line breaks) verifies a token

## 2. Standards and catalog

- [x] 2.1 Add the "Delegated calls" rule to `standards/spring-boot/README.md`, and
      remove `X-User-Id` from the internal member-resource rule (Decision 4);
      verify `X-User-Id` appears in the standards only as the thing not to do
- [x] 2.2 Add a `tn-service` entry to `catalog.yaml` pointing at this change;
      verify `openspec validate add-delegate-user-token --strict`
