# Java standard

Applies to every JVM component (`java-library`, `java-spring-service`, `java-cli`, and
the JVM parts of any other type).

These rules are distilled from `tn-lang`, `tn-query` and `tn-parent`. They describe how
this code is written today. Where the existing code is inconsistent, the file says so
and names the intended direction.

## Files

| File | Covers |
|------|--------|
| [`formatting.md`](formatting.md) | Braces, indentation, whitespace, statement and call layout, files |
| [`imports.md`](imports.md) | Import grouping and ordering |
| [`naming.md`](naming.md) | Packages, classes, utility classes, interfaces, constants, members, accessors |
| [`idioms.md`](idioms.md) | Guard clauses, `this.`, immutability, records, streams, `var`, `instanceof`, null, functional style |
| [`error-handling.md`](error-handling.md) | Exception types, messages, wrapping checked exceptions |
| [`testing.md`](testing.md) | JUnit 5 + Mockito, test naming, the unit / integration / contract split |
| [`identifiers.md`](identifiers.md) | TSID entity identifiers instead of database sequences |

## Non-negotiables (the short list)

1. Two-space indent, no tabs. Allman braces (opening brace on its own line).
2. Import groups in the fixed order in `imports.md`, separated by blank lines. No
   wildcard imports.
3. Utility classes are pluralised nouns with only `static` members.
4. Interfaces have no `I` prefix; abstract classes have an `Abstract` prefix.
5. Custom exceptions extend `RuntimeException`; messages are `"Description: " + value`.
6. Tests are package-private, named `should<Behaviour>()`, and live in the right source
   root for their level (`src/test`, `src/it`, `src/ct`).
7. The Java language level is set **only** by `tn-parent`. Never set
   `maven.compiler.*` in a component POM.
8. New entity identifiers are TSIDs (`io.hypersistence:hypersistence-tsid`), not
   `GenerationType.SEQUENCE`. See `identifiers.md`.
9. `java-spring-service` components log structured JSON and mask sensitive fields.
   See `../logging/README.md`.
10. Code is clear and minimal; comment only what the code itself can't make clear.
    See `../conventions/README.md#comments`.
