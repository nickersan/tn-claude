# Java — testing

## Frameworks

- **JUnit 5 (Jupiter)** — provided by `tn-parent` (`junit-jupiter-api`, `-engine`,
  `-params`).
- **Mockito** — `mockito-core` and `mockito-junit-jupiter`.
- **Guava testlib** — `EqualsTester` for `equals`/`hashCode` contracts.
- Assertions: JUnit `org.junit.jupiter.api.Assertions`. Do not add AssertJ or Hamcrest
  to a component without a standards change.

## Test class conventions

- **Package-private** (`class StringsTest`), never `public`.
- Same package as the type under test, mirrored under the test source root
  (`com.tn.query.DefaultQueryParser` -> `src/test/java/com/tn/query/DefaultQueryParserTest.java`).
- Name: `<TypeUnderTest>Test`. Integration tests: `<Type|Feature>IntegrationTest`.

## Test method conventions

- Package-private, `void`, no exceptions in the name.
- Named `should<Behaviour>` optionally followed by `When<Condition>`:
  `shouldParseEqual`, `shouldTrueWhenNull`, `shouldMatchBoolean`, `shouldBeEqual`.
- Legacy `test<Thing>` names exist in older node tests — use `should…` for anything new.
- Arrange / act / assert, separated by blank lines. Shared literals go in
  `private static final` constants at the top of the class (`LEFT`, `RIGHT`,
  `PREDICATE`).
- Static-import each assertion method used
  (`import static org.junit.jupiter.api.Assertions.assertEquals;`). Prefer the static
  import to `Assertions.assertEquals(...)`.

## Mockito

- Explicit `mock(Foo.class)` + `when(...).thenReturn(...)` is the common form.
- `@ExtendWith(MockitoExtension.class)` with `@Mock` fields is acceptable
  (`mockito-junit-jupiter` is on the path) — pick one style per class.
- Generic mocks carry `@SuppressWarnings("unchecked")` on the local, not the method.

## Parameterised tests

`@ParameterizedTest` with `@MethodSource` supplying `Stream<Arguments>` from a
`private static` method named after the parameter:

```java
@ParameterizedTest
@MethodSource("nanos")
void shouldRound(int nanos, int roundedNanos)
{
  ...
}

private static Stream<Arguments> nanos()
{
  return Stream.of(
    Arguments.arguments(0, 0),
    Arguments.arguments(123456500, 123457000)
  );
}
```

## equals / hashCode

```java
new EqualsTester()
  .addEqualityGroup(new And(left, right), new And(left, right))
  .addEqualityGroup(new And(new NotEqual("A", "B"), right))
  .testEquals();
```

## Test levels and where they live

`tn-parent` wires three source roots so fast tests can run without the slow ones:

| Level | Source root | Naming | Runner / phase | Notes |
|-------|-------------|--------|----------------|-------|
| **Unit** | `src/test/java` | `*Test.java` | Surefire, `test` phase | `**/*IntegrationTest.java` is explicitly excluded. No network, no containers, no disk beyond temp. |
| **Integration** | `src/it/java` | `*IntegrationTest.java` | Failsafe (+ a Surefire execution), `integration-test` / `verify` | Added as a test source by `build-helper-maven-plugin`. May use in-memory H2 or Testcontainers PostgreSQL. |
| **Contract** | `src/ct/java` | Spring Cloud Contract | contract producer profile | Auto-activates when `src/ct/java/contracts` (or `src/ct/resources/contracts`) exists. Consumer side uses the stub runner. |

- `src/it/resources` and `src/ct/resources` are filtered resource roots.
- Integration-test idioms: `@BeforeAll` / `@AfterAll` `static` lifecycle, resources via
  try-with-resources, small private `assertMatch` / `assertNoMatch` helpers, a nested
  `Target` fixture class.

## Contracts are unambiguous

- No two contracts for a path may match the same request. A consumer's stub runner loads every stub of a producer into one WireMock, and
  where several match it answers with whichever loaded last, an order that differs between Windows and Linux: a consumer's build then
  passes on one machine and fails on the other.
- Separate contracts by what they match: a different query value, path, header value or body. A contract for a request without a header
  matches one that carries it too, so give it its own value (its own search text, id) rather than relying on the others being preferred.
- Do not use `priority`. It hides the overlap instead of removing it, and makes a stub's answer depend on a rule nobody reads. A contract's
  description says what sets it apart.

## Every component is tested completely on its own

- Each component, library or service, carries complete tests of its own: every class, every
  branch, every error and shutdown path, at unit or integration level. Never rely on a
  project's acceptance suite to catch a component's defects. Acceptance proves the parts fit
  together; it does not stand in for testing the parts, and its coverage never counts.
- Wiring is code too: auto-configuration (conditions, back-off, property switches) and
  lifecycle beans (start, stop, loop, failure) get tests, e.g. with `ApplicationContextRunner`
  and a fake collaborator. Do not leave them to be exercised only when a service starts.
- Read the JaCoCo report (`target/site/jacoco/jacoco.csv`) before calling a component done; a
  class with no coverage, or an uncovered branch, is a missing test, not an exclusion. Exclude
  only what cannot be tested (`**/Application.class`).

## Coverage and mutation testing

- **JaCoCo** runs on every `test`; unit and integration executions are merged into one
  report (`target/site/jacoco`). There is currently **no enforced threshold**, but that is
  not licence to leave gaps: aim for every line and branch, and cover every branch of
  parsing / comparison / error paths (as the `tn-query` integration tests do exhaustively).
- **Pitest** mutation testing is available on demand: `mvn test -Dpitest`
  (targets `com.tn.*`). Use it when hardening a critical algorithm.
