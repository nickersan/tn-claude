# Java — formatting

## Indentation and width

- **Two spaces** per level. No tabs anywhere.
- Continuation lines indent **+2** from the statement they continue.
- **Line length is 180 characters.** Wrap before that, not after — this is wider
  than the old 80/100/120 conventions on purpose (this codebase's multi-argument
  call/declaration layout, see below, already uses vertical space generously; 180
  gives room for a descriptive single-line statement without forcing an
  unnecessary wrap). Configure the IDE's line-length ruler/formatter to 180 to
  match, don't eyeball it.

## Braces — Allman style

The opening brace goes on its **own line**, aligned with the construct it opens. This
applies to classes, interfaces, enums, methods, constructors, static initialisers,
`if`/`else`/`for`/`while`/`try`/`catch`/`finally`, and multi-statement lambdas.

```java
public class DefaultQueryParser<T> implements QueryParser<T>
{
  public T predicate(Node node)
  {
    if (node instanceof Parenthesis)
    {
      return this.predicateFactory.parenthesis(predicate(((Parenthesis)node).getNode()));
    }
    else
    {
      return predicateForNode(node, left(node), right(node));
    }
  }
}
```

Multi-statement lambdas and static blocks follow the same rule:

```java
return t ->
{
  Function<String, Mapper> factory = overrides.get(t);
  if (factory != null) return factory.apply(t);
  return null;
};

static
{
  FIELD_MAPPINGS.put("booleanValue", "boolean_value");
}
```

## Single-statement blocks

Braces may be omitted for a single guarded statement, and the statement may sit on the
**same line** as the condition. This is the preferred form for guard clauses:

```java
if (s == null || s.trim().isEmpty()) return true;
if (node == null) throw exceptionSupplier.get();
if (connection != null && !connection.isClosed()) connection.close();
```

Put the statement on the next line (still no braces) only when it is too long to read
on one line. Never mix: if any branch of an `if`/`else` uses braces, all branches use
braces.

## Statement and member spacing

- One blank line between methods, constructors and fields.
- Use blank lines inside a method to separate logical steps (setup / action / result).
  This is used liberally in the existing code — don't pack a method into one dense
  block.
- No blank line immediately after a class's opening brace in Java source (POM files
  differ — see `../maven/pom-style.md`).

## Multi-argument methods and constructors

When arguments don't comfortably fit on one line, put **each argument on its own
line**, indented +2, with the closing `)` on its own line at the base indent:

```java
public Page(
  @Nonnull
  @JsonProperty("items")
  Collection<T> items,
  @JsonProperty("number")
  int number,
  @JsonProperty("size")
  int size
)
{
  ...
}
```

The same layout is used for call sites and for `enum` constant argument lists:

```java
EQUAL(
  "=",
  ComparisonOperator::matchesEqual,
  Equal::new
),
```

**Applies to record headers too — a record's component list is a constructor
declaration** — and the one-component-per-line trigger is "any component
carries an annotation" (or the line doesn't fit), not "there's more than one
component." A record with a single annotated component still breaks: the
annotation on its own line above the component, the closing `)` on its own
line, and the body's braces on their own Allman line even when the body is
empty:

```java
record GenerateRequest(
  @Schema(description = "The opaque subject id the issued token pair will identify - not resolved, validated, or stored by this service")
  String id
)
{}
```

Not `) {}` on one line — the empty body still gets its own opening/closing
brace line, same as every other Allman-braced construct on this page.

## Fluent / stream chains

Break before each `.` in a chain, indent the continuation +2:

```java
return Stream.of(subject.getDeclaredFields())
  .filter(field -> !ignored.contains(field.getName()) && !field.isSynthetic())
  .map(field -> new Field(field.getName(), field.getType()))
  .map(toMapper(overrides))
  .filter(Objects::nonNull)
  .toList();
```

## `toString()` layout

Value types build the string by concatenation across lines, one field per line:

```java
return "Page{number=" + number +
  ", size=" + size +
  ", totalItems=" + totalItems +
  ", items=" + items +
"}";
```

Node/AST types use a `TEMPLATE_TO_STRING` constant with `String.format` (see
`naming.md`).

## Files

- One top-level type per file. Small nested helper types (a private `record`, a
  functional interface, a test fixture class) are fine when they are only used by the
  enclosing type.
- UTF-8. Non-ASCII characters in string/enum literals are acceptable (`≈`, `∈` appear
  in `tn-query`).
- End every file with a single newline.
