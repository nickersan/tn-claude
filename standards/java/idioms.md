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

  String[] tokens = queryPart.split(this.symbol);
  if (tokens.length != EXPECTED_TOKENS) throw new QueryParseException("Invalid query part: " + queryPart);

  return this.nodeFactory.apply(tokens[INDEX_LEFT].trim(), tokens[INDEX_RIGHT].trim());
}
```

Ternaries — including nested ones — are used freely for value selection. Keep each
branch simple.

## `this.` for field access

Qualify instance field and instance method access with `this.` in classes that hold
state (`this.mappers`, `this.predicateFactory`, `this.queryParser`). Apply it
consistently within a class.

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

## equals / hashCode / toString

Hand-written in these libraries (Lombok is available via the parent and used in
services, but the core libs write them out).

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
