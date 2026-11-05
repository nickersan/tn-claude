# API versioning — every path starts `/v<n>`

**Every API path starts with its major version: `/v1/...`.** An API stays on
its version for as long as its changes are backwards compatible. A breaking
change to an existing API moves it to the next version (`/v1` → `/v2`, `/v2` →
`/v3`, and so on) rather than changing the existing version in place.

Breaking changes include:
- removing or renaming an endpoint, a field, or a query parameter;
- changing a field's type or meaning;
- making an optional request field required;
- removing an enum value a caller may send or receive.

Adding an endpoint, an optional request field, or a response field is not
breaking, and stays on the current version. So is a new error response for a
case that previously succeeded only by accident (e.g. a new 429 when a limit
is exceeded).

- The version is part of the path in the `api` interface's mapping (for
  example `@RequestMapping("/v1/users")`, or `/v1/...` on each method). It is
  never a header or a query parameter.
- When an API moves to a new version, keep serving the previous one until its
  consumers have moved, then remove it. Don't break it in place to save the
  bump.
- Operational endpoints are not API and carry no version: the health probe
  (`/noop`, see `../kubernetes/README.md`), `/actuator/**`, and SpringDoc's
  `/v3/api-docs` and `/swagger-ui.html` (whose `v3` is the OpenAPI spec's version,
  not the service's).
