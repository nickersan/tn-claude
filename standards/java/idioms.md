# Java — language idioms

## Language level

Set by `tn-parent` only. As of `tn-parent` 2.2.x, `maven.compiler.release` is **25**.
Never set `maven.compiler.source/target/release` in a component POM. CI `setup-java`
must match the parent (some existing workflows still say `21` — align them to the
parent when you touch them).

## Explicit types — no `var`

`var` is **not used** in this codebase. Declare locals with explicit types, including
in streams and try-with-resources.

## Guard clauses and early return

Prefer flat code with early returns and early throws over nested `if`. This is the
dominant style:

```java
ComparisonNode parse(@Nonnull String queryPart) throws QueryParseException
{
  if (!matches(queryPart)) throw new IllegalArgumentException("Unmatched query: " + queryPart);

  String[] tokens = queryPart.split(symbol);
  if (tokens.length != EXPECTED_TOKENS) throw new QueryParseException("Invalid query part: " + queryPart);

  return nodeFactory.apply(tokens[INDEX_LEFT].trim(), tokens[INDEX_RIGHT].trim());
}
```

Ternaries — including nested ones — are used freely for value selection. Keep each
branch simple.

## No `this.` unless it's required

Access fields and call instance methods without `this.` (`mappers`,
`predicateFactory.parenthesis(...)`). Use `this.` only where the language needs it,
which is where a parameter or local shadows a field:

```java
public Tag(String name)
{
  this.name = name;
}

public void replaceTags(Collection<Tag> tags)
{
  this.tags.clear();
  this.tags.addAll(tags);
}
```

Take care when removing `this.` from existing code. Where a parameter shadows the
field, `tags.addAll(tags)` still compiles, but it reads the parameter twice and
silently leaves the field alone. Check every method with a parameter named like a
field before removing a qualifier from it. (This reverses the earlier rule, distilled
from `tn-lang`/`tn-query`, of qualifying every field access. Existing code is brought
into line as it's next touched.)

## Composed methods

A public method should read as the steps of the operation it performs. Give each step
that's more than a single self-explanatory call its own private method, named in the
domain's vocabulary, for what it achieves rather than how:

```java
public void requestPasscode(Identifier identifier)
{
  String passcode = generatePasscode(identifier);
  sendPasscodeNotification(identifier, passcode);

  log.info("Passcode sent", kv("identifierType", identifier.type()));
}
```

`generatePasscode`, not `generate` or `callTokenService`. A reader should understand the
public method without opening the private ones, and each private method should do the
one thing its name says.

## Immutability

- Value and AST types are immutable: `final` fields, no setters, defensive copies on
  the way in (`Page` wraps its collection with `unmodifiableCollection(...)`).
- Return an unmodifiable or copied view rather than the internal collection.
- To "change" an immutable object, return a new instance from a `withX` method.
- **Exception: JPA entities don't use `final` fields.** `@NoArgsConstructor` plus
  Hibernate's reflection-based field access requires mutable fields — every JPA
  entity in this codebase (`Email`, `Token`, `User`, `RefreshToken`, ...) is
  built this way, consistently. This is the correct pattern for an entity, not a
  gap to close; the immutability rule above is for value/AST types, not entities.

## Records

Use `record` for small, purely-structural data carriers:

```java
public record Field(String name, Class<?> type) {}
```

Nest them inside the type that owns them when that is their only use
(`ValueMappers.Field`). Larger value types that need a hand-written `equals`
semantics (e.g. collection-content equality, `getClass()` checks) stay as classes —
see `equals`/`hashCode` below.

## Streams and collections

- Terminal collect to an immutable list: prefer `.toList()` over
  `.collect(Collectors.toList())` in new code. `toMap` / `toSet` are still
  static-imported from `java.util.stream.Collectors` where needed.
- `Iterables` (in `tn-lang`) exists for `Iterable`-level operations — use
  `Iterables.asStream(...)`, `Iterables.isEmpty(...)` rather than re-implementing.
- Return `emptyList()` / `emptyMap()` (static-imported from `java.util.Collections`),
  never `null`, for "no results" from a collection-returning method.

## `instanceof`

Existing code uses classic `instanceof` followed by an explicit cast
(`node instanceof Parenthesis` … `((Parenthesis)node).getNode()`). Pattern-matching
`instanceof` and pattern `switch` are permitted in new code and preferred where they
remove a cast — but match the surrounding method's style when editing existing code.

## null vs Optional

- `Optional` is used as a **stream/pipeline** result
  (`findFirst().map(...).orElseThrow(...)`), not stored in fields or accepted as a
  parameter.
- A public method whose result can legitimately be absent returns `Optional`, never
  `null`. When callers usually need the value, add a companion method that throws
  a meaningfully named exception instead, e.g.
  `AccessTokenVerifier.subject(token)` returns `Optional<String>`, and
  `subjectRequired(token)` throws `InvalidAccessTokenException("no subject")`.
  The companion keeps the base name and adds `Required` as a suffix
  (`subjectRequired`, not `requiredSubject`), so code completion shows the two
  together.
- Internal helper methods may return `null` as a "not applicable" signal when the
  caller immediately filters it (`ValueMappers.toMapper` returns `null`, then
  `.filter(Objects::nonNull)`). Keep this local and obvious; do not leak nullable
  returns across public API boundaries — throw or return an empty collection instead.
- Annotate genuinely non-null public parameters and returns with
  `jakarta.annotation.Nonnull`.

## Functional style

- Pass behaviour as `Function` / `BiFunction` / `Supplier` / `Predicate` and compose
  with method references (`Equal::new`, `Mapper::name`,
  `ComparisonOperator::matchesEqual`).
- `enum` constants can carry function-valued fields (see `ComparisonOperator`: each
  constant holds a matcher `Predicate<String>` and a node factory
  `BiFunction<Object, Object, ComparisonNode>`).
- For "run something around" logic, use the `tn-lang` `Then` helper
  (`beforeThen` / `thenAfter` / `beforeThenAfter`) rather than ad-hoc try/finally.

## Lombok — use it wherever it's available

Where a module has Lombok on its classpath (tn-parent manages it, and every service
and most libraries have it), use it instead of writing boilerplate by hand:
- A class that's never instantiated (static helpers, constants):
  `@NoArgsConstructor(access = AccessLevel.PRIVATE)`, not `private Foo() {}`.
- Constructors that only assign fields: `@AllArgsConstructor` or
  `@RequiredArgsConstructor`.
- `equals`/`hashCode`/`toString`: `@EqualsAndHashCode`/`@ToString`. Prefer a
  `record` when the type is plain data.
- Loggers: `@Slf4j`.

Hand-write only where Lombok isn't on the classpath, or where the generated form
would be wrong (for example, `equals` over a subset of fields that Lombok's
annotations can't express cleanly).

## equals / hashCode / toString

Where written by hand (modules without Lombok, or the exceptions above):

- `equals` pattern: identity check, then `getClass()` equality (not `instanceof`), then
  field-by-field `Objects.equals`:

  ```java
  @Override
  public boolean equals(Object other)
  {
    return this == other || (
      other != null &&
        getClass().equals(other.getClass()) &&
        Objects.equals(this.left, ((AbstractNode)other).left) &&
        Objects.equals(this.right, ((AbstractNode)other).right)
    );
  }
  ```

- `hashCode`: `Objects.hash(...)` over the same fields used in `equals`.
- `toString`: value types concatenate (`"Page{number=" + number + ...}"`); node types
  use a `private static final String TEMPLATE_TO_STRING` and `String.format`.
- Test `equals`/`hashCode` with Guava's `EqualsTester` (see `testing.md`).
