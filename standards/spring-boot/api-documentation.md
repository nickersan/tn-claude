# API documentation — SpringDoc / OpenAPI

**Every `@RestController` endpoint is annotated so SpringDoc can generate accurate
OpenAPI docs from it — annotations aren't optional decoration.**

- Dependency: `org.springdoc:springdoc-openapi-starter-webmvc-ui`, already managed
  by `tn-parent` — but bump the pin. `tn-parent` currently has `3.0.1`, which has a
  known Jackson 2/Jackson 3 mismatch on Spring Boot 4
  ([springdoc/springdoc-openapi#3200](https://github.com/springdoc/springdoc-openapi/issues/3200))
  — real for us, since `tn-parent` already runs Jackson 3
  (`tools.jackson.core:jackson-databind:3.1.2`). Move to `3.1.1` (current latest at
  time of writing) in `tn-parent`'s `dependencyManagement`.
- Annotate with `io.swagger.v3.oas.annotations.*`:
  - `@Tag(name = "...")` on the controller class.
  - `@Operation(summary = "...")` on each mapped method — one sentence, what it
    does.
  - `@ApiResponse(responseCode = "...", description = "...")` for the success case
    and every distinct error case the endpoint can return (not just 200 — a
    consumer reading the generated docs needs the 4xx shapes too).
  - Request/response records get field-level `@Schema(description = "...")` where
    the field name alone doesn't say enough (e.g. what format an identifier value
    must be in) — don't annotate fields that are already self-explanatory.
- No hand-written OpenAPI YAML/JSON — it's generated from the annotated code, so
  there's one source of truth and it can't drift.
- Docs are served at SpringDoc's defaults (`/v3/api-docs`, Swagger UI at
  `/swagger-ui.html`) — don't relocate them without a reason.
