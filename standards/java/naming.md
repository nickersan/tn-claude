# Java — naming

## Packages

- All lowercase, no underscores: `com.tn.<area>[.<subarea>...]`.
- `<area>` matches the artifact family (`com.tn.lang`, `com.tn.query`,
  `com.tn.service`, `com.tn.service.data`, `com.tn.client`).
- Sub-packages describe a layer or feature, not a type bucket:
  `com.tn.query.node`, `com.tn.lang.util.function`, `com.tn.lang.util.stream`,
  `com.tn.query.jdbc`, `com.tn.query.jpa`.

## Types

| Kind | Rule | Examples |
|------|------|----------|
| Class / enum / record | `PascalCase` | `DefaultQueryParser`, `ComparisonOperator`, `Page` |
| Interface | `PascalCase`, **no `I` prefix** | `Node`, `QueryParser`, `PredicateFactory`, `Mapper` |
| Abstract class | `Abstract` prefix | `AbstractNode`, `AbstractQueryableRepository` |
| Utility class | **pluralised noun** | `Strings`, `Objects`, `Iterables`, `Collectors`, `ValueMappers`, `Lambdas`, `LocalDateTimes` |
| Test class | SUT name + `Test` | `StringsTest`, `DefaultQueryParserTest` |
| Integration test | SUT/feature + `IntegrationTest` | `JdbcQueryIntegrationTest` |

### Utility classes

- Named as the plural of what they operate on, mirroring the JDK where one exists
  (`Objects`, `Collectors`).
- Contain only `public static` members.
- Give them a `private` no-args constructor (`private Query() {}`,
  `private ValueMappers() {}`). Some older utilities omit it — add one when you touch
  the file.
- Do not make them `final` or `abstract`.

## Constants

- `UPPER_SNAKE_CASE`, `private static final` unless deliberately part of the API
  (`Strings.EMPTY`, `Query.AND` are public).
- Group related constants with a shared prefix that names their role:
  `REGEX_EQUAL`, `INDEX_LEFT` / `INDEX_RIGHT`, `SQL_INSERT` / `SQL_SELECT`,
  `TEMPLATE_TO_STRING`, `EXPECTED_TOKENS`.
- Extract magic strings and numbers into a named constant even when used once if the
  literal isn't self-explanatory (`SPACE = " "`, `EXPECTED_TOKENS = 2`).

## Members, parameters, locals

- `camelCase`, descriptive. No Hungarian notation, no type suffixes.
- Single-letter names only in the smallest scopes: `s` for a lone `String` argument to
  a `Strings`-style helper, `e` for a caught exception, `t`/`u`/`r` for generic values
  in a functional helper.
- Instance fields that are never reassigned are `final` (`Page`'s fields,
  `AbstractNode.left`/`right`). Do **not** put `final` on parameters, locals or
  classes as a matter of course — it is not used that way here.

## Generics

- Single uppercase letters: `T`, `R`, `T1`. Bounded recursive types spell it out:
  `LogicalNode<T extends LogicalNode<T>>`.

## Methods

- `camelCase`, a verb or predicate phrase.
- Boolean-returning methods start with `is` / `isNot` / `has` / `matches`
  (`isNullOrWhitespace`, `isValid`, `matchesGreaterThan`).
- **Provide the negation.** Where a boolean check is commonly negated, add the paired
  method rather than making callers write `!`:
  `isEmpty` / `isNotEmpty`, `isNullOrWhitespace` / `isNotNullOrWhitespace`,
  `isValid` / `isNotValid`.
- Static factory methods read as a phrase: `beforeThen`, `thenAfter`, `forFields`,
  `toBoolean`, `parseNode`.

## Accessors

- **New value / data types omit the `get` prefix**: `items()`, `number()`, `size()`,
  `name()`, `type()`, `entityManager()`. This is the current direction (`Page`,
  `ValueMappers.Field`, `Mapper`).
- The older `Node` interface uses `getLeft()` / `getRight()`. Leave existing `get*`
  APIs alone, but do not add new ones.
- No `set*` mutators on value types — they are immutable (see `idioms.md`). "Modified
  copy" methods are named `withX` (`LogicalNode.withRight`, `And.withRight`).
