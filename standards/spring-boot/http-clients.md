# HTTP clients — `@HttpExchange` interfaces, not Feign or hand-written calls

**Call another service through a Spring HTTP interface**: an interface in the
consumer's `client` package, its methods annotated `@GetExchange`,
`@PostExchange`, `@PutExchange`, `@DeleteExchange` and so on. Register it with
`@ImportHttpServices`, one group per downstream service, and set the group's base
URL in configuration:

```java
@HttpExchange("/v1/spots")
public interface SpotServiceClient
{
  @GetExchange("/{id}")
  Spot get(@PathVariable long id);

  @PutExchange("/{id}/followers/{userId}")
  void follow(@RequestHeader(DelegateUserToken.HEADER) String delegateUserToken, @PathVariable long id, @PathVariable long userId);
}

@Configuration
@ImportHttpServices(group = "spot-service", types = SpotServiceClient.class)
class ClientConfiguration {}
```

```yaml
spring:
  http:
    serviceclient:
      spot-service:
        base-url: ${SPOT_SERVICE_URL:http://localhost:8093}
```


- **Every service that calls another depends on `tn-resilience`.** It configures each `@ImportHttpServices` group with a timeout, circuit
  breaker, bulkhead and rate limiter (retrying only calls declared safe to repeat), and serves the `resilience` Actuator endpoint, so a
  slow or down dependency does not hold up the caller. A service with an `@ImportHttpServices` client and no `tn-resilience` makes
  unprotected calls: add the dependency when adding the first client, and cover it with a test that reads the `resilience` endpoint and
  finds one group per service called.
- **Not Feign.** Spring Cloud OpenFeign is feature-complete, and it pulls in the
  Spring Cloud release train for something Spring Framework 7 and Boot 4 now do
  natively, backed by the same `RestClient`. Feign must not be used in new or
  changed code. `tn-client-feign` and the Feign dependencies still managed in
  `tn-parent` are kept for reference only.
- **Not hand-written `RestClient` calls.** They repeat URI building, headers and
  body handling in every method, and `body(...)` returns a nullable value that
  every caller then has to guard.
- **Errors come from `RestClient`'s own exceptions**, whose class names already
  carry the status: `HttpClientErrorException.NotFound`,
  `HttpClientErrorException.TooManyRequests`, `HttpServerErrorException` and so
  on. The caller catches the one that means something to it and translates it
  into its own meaningfully named exception (a 429 from a token service becomes
  `PasscodeThrottledException`). Declare those exceptions in the interface
  method's `throws` so the caller can see them. For group-wide behaviour
  (timeouts, a shared error mapping), use a `RestClientHttpServiceGroupConfigurer`
  bean, not per-call code.
- **Return the body type the API promises.** Where the API allows no body (for
  example, a lookup that can find nothing without it being an error), return
  `Optional<T>`, which HTTP interfaces support directly. Never return `null` for
  "absent" (see `standards/java/idioms.md`).
- **The delegate user token is a parameter**, `@RequestHeader(value =
  DelegateUserToken.HEADER, required = false)` where anonymous calls are allowed,
  and required otherwise.
- **Don't share the producer's API interface.** The consumer declares its own
  interface and records, so the two services build independently. The producer's
  contracts, run against the consumer through the stub runner, catch any drift.
