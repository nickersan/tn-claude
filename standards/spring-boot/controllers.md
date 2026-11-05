# Controller layout — `api` interfaces, `controller` implementations

**Every endpoint's contract (routing + OpenAPI annotations + request/response
shapes) lives on an interface in the `api` package; a plain `@RestController`
class in a `controller` package implements it and holds no annotations beyond
`@RestController` itself.** Springdoc-openapi's own documented pattern for
keeping API documentation separate from handler logic — Spring MVC's
`RequestMappingHandlerMapping` resolves `@RequestMapping`-family annotations
(`@GetMapping`/`@PostMapping`/etc.) via `AnnotatedElementUtils`, which looks at
interfaces a controller class implements, so nothing needs repeating on the
implementing method. Not a new invention — this is how Spring and SpringDoc
already expect controllers documented at scale; codifying it here so every
service in this layer does it the same way rather than each accreting its own
variant.

```java
// api/GenerateApi.java
package com.tn.auth.api;

public interface GenerateApi
{
  @PostMapping("/v1/generate")
  @Operation(summary = "Issue a token pair")
  @ApiResponse(responseCode = "200", description = "Token pair issued")
  TokenPair generate(@RequestBody GenerateRequest request);

  record GenerateRequest(String id, List<Claim> claims) {}
}

// controller/GenerateController.java
package com.tn.auth.controller;

@RestController
@AllArgsConstructor
public class GenerateController implements GenerateApi
{
  private final AuthService authService;

  @Override
  public TokenPair generate(GenerateRequest request)
  {
    return authService.generate(request.id(), request.claims());
  }
}
```

- `@Tag(name = "...")` goes on the interface, not the implementing class —
  it's part of the documented contract.
- Request/response records (and any endpoint-local types) are nested in, or
  live alongside, the interface in `api` — they're part of the contract, not
  the implementation.
- The implementing class in `controller` carries the dependencies
  (`@AllArgsConstructor` + `final` fields, as elsewhere in this layer) and
  nothing else — no `@RequestMapping`, no `@Tag`, no `@Operation`. If a
  reviewer finds a mapping or OpenAPI annotation on a class in `controller`,
  that's the signal something drifted from this convention.
- Applies to every controller in every `java-spring-service` component, not
  just ones being actively touched — new controllers are written this way
  from the start; existing controllers are restructured to match as the
  component they live in is next touched for other reasons (no blanket
  retrofit sweep mandated by this entry alone).
