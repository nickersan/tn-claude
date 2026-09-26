## 1. tn-temporary-token-service

- [x] 1.1 Add a Flyway migration: a `generate_request` table (`owner`,
      `created`, indexed on both) and a `failed_attempts` column on `token`
      (design.md Decisions 1-2); verify it applies cleanly against Testcontainers
      Postgres
- [x] 1.2 Take a per-owner advisory lock at the start of generate and verify, each
      in one transaction (Decision 3); verify with integration tests that
      concurrent generates for one owner never exceed the limit, and that
      concurrent wrong verifies are all counted
- [x] 1.3 Reject a generate over the per-owner limit with 429, generating nothing
      and leaving the existing token verifiable; prune the owner's rows older than
      the window on each accepted generate; configurable limit and window
      (Decision 1); verify with tests for within the limit, over the limit, per
      owner, and allowed again after the window
- [x] 1.4 Count failed verifies on the token and delete it on reaching the limit;
      configurable limit (Decision 2); verify with tests that the correct value
      within the limit verifies, the correct value after the limit doesn't, and a
      new token starts a fresh count
- [x] 1.5 Document 429 on generate in its OpenAPI annotations and add a Java
      contract for it; verify `/v3/api-docs` and the contract tests

## 2. tn-auth-service

- [x] 2.1 Add the `token_use` claim (`access`/`refresh`) to every issued token,
      including a refreshed access token (Decision 4); verify with tests
      decoding each token's claims
- [x] 2.2 Reject a refresh whose token's `token_use` isn't `refresh`; verify with a
      test that presenting an access token as a refresh token is rejected

## 3. API paths and controller layout

- [x] 3.1 Move `tn-temporary-token-service`'s endpoints to
      `/v1/actions/generate-token`, `/v1/actions/verify-token`, and
      `POST /v1/actions/check-expiry` (owner in the body, replacing
      `GET /{owner}`), and restructure its controllers into `api` interfaces
      implemented in a `controller` package (design.md Decision 5); verify the
      contracts, the integration tests, and `/v3/api-docs` against the new paths
- [x] 3.2 Move `tn-auth-service`'s endpoints to `/v1/actions/generate-tokens`
      and `/v1/actions/refresh-tokens` (Decision 5); verify the contracts, the
      integration tests, and `/v3/api-docs` against the new paths
- [x] 3.3 Apply the singular `controller` package name across the tn layer:
      rename `tn-auth-service`'s and `tn-user-service`'s `controllers` packages,
      and move `tn-notification-service`'s controller from `api` into an `api`
      interface plus a `controller` implementation (Decision 5); verify each
      service's full build and tests pass unchanged

## 4. Catalog and consumers

- [x] 4.1 Point `catalog.yaml`'s `tn-temporary-token-service` and
      `tn-auth-service` entries at this change (`spec_change`); verify
      `openspec validate harden-otp-and-token-type --strict` passes
- [x] 4.2 Record the consumer-side follow-ups in `okayat-platform`'s
      `initial-capabilities` (the BFF maps 429 and checks `token_use`); verify by
      reading its tasks.md
