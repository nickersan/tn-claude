# Contract testing — Java DSL, not Groovy

**New and touched contracts are written in Java, under `src/ct/java/contracts`,
using `tn-parent`'s existing `contracts-producer-java` profile** — not the Groovy
DSL under `src/ct/resources/contracts` (the `contracts-producer-groovy` profile).
Both profiles remain valid in `tn-parent` (other components may still use Groovy),
but Java is the standard going forward: one language for test code, not two, and
no separate Groovy toolchain to reason about.

Shape (verified against the current Spring Cloud Contract reference, not
guessed):

```java
package contracts;

import java.util.Collection;
import java.util.Collections;
import java.util.function.Supplier;

import org.springframework.cloud.contract.spec.Contract;
import org.springframework.cloud.contract.verifier.util.ContractVerifierUtil;

public class ShouldGenerateTokenPair implements Supplier<Collection<Contract>>
{
  @Override
  public Collection<Contract> get()
  {
    return Collections.singletonList(Contract.make(c ->
    {
      c.description("should generate token pair");
      c.request(r ->
      {
        r.method(r.POST());
        r.url("/generate");
        r.headers(h -> h.contentType(h.applicationJson()));
        r.body(ContractVerifierUtil.map().entry("identifierType", "EMAIL").entry("identifier", "test@testing.com"));
      });
      c.response(r ->
      {
        r.status(r.OK());
        r.headers(h -> h.contentType(h.applicationJson()));
        r.body(ContractVerifierUtil.map().entry("refresh", "REFRESH").entry("access", "ACCESS"));
      });
    }));
  }
}
```

- One contract (one `Supplier<Collection<Contract>>` implementation) per
  `.groovy` file being migrated — same test name/description, same
  request/response shape, translated to the class's own current API (a contract
  being migrated during a change that also alters the API — like this one — should
  describe the *new* shape, not the old one; don't migrate format and defer the
  content update).
- Base test class (`AbstractContractTest`, `contract-producer.base-test-class`
  property) stays exactly as it already works — that part isn't Groovy-specific.
- `tn-parent`'s `contracts-producer-java` profile already sets
  `testFramework: JUNIT5` and reads `contract-producer.base-package.tests` /
  `contract-producer.base-class.tests` — no new build config needed, just the file
  move and the trigger directory (`src/ct/java/contracts` instead of
  `src/ct/resources/contracts`).
