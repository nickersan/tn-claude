# Java — imports

Imports are grouped, and the groups appear in a fixed order separated by a single blank
line. Within a group, imports are sorted alphabetically.

## Order

1. **Static — JDK.** `import static java.*` / `import static javax.*`
   (e.g. `java.lang.String.format`, `java.util.Collections.emptyList`,
   `java.util.stream.Collectors.toMap`).
2. **Static — third party.** e.g. `org.junit.jupiter.api.Assertions.assertEquals`,
   `org.mockito.Mockito.when`.
3. **Static — first party.** `import static com.tn.*`
   (e.g. `com.tn.lang.Strings.EMPTY`).
4. *(blank line)*
5. **JDK.** `import java.*` / `import javax.*`
6. *(blank line)*
7. **Jakarta.** `import jakarta.*` (e.g. `jakarta.annotation.Nonnull`,
   `jakarta.persistence.*`).
8. *(blank line)*
9. **Third party.** e.g. `com.fasterxml.jackson.*`, `com.google.common.*`,
   `org.springframework.*`, `org.junit.jupiter.api.Test`.
10. *(blank line)*
11. **First party.** `import com.tn.*`

Omit a group (and its trailing blank line) when it is empty. Not every file has all
groups.

## Example

```java
package com.tn.query;

import static java.util.Collections.emptyList;
import static java.util.stream.Collectors.toMap;

import java.util.Collection;
import java.util.Map;
import java.util.function.Function;

import jakarta.annotation.Nonnull;

import com.fasterxml.jackson.annotation.JsonProperty;

import com.tn.query.node.And;
import com.tn.query.node.Node;
```

## Rules

- **No wildcard imports** — not for packages, not for static members. Static test
  assertions are imported one symbol at a time
  (`import static org.junit.jupiter.api.Assertions.assertEquals;`), not `.*`.
- Prefer a static import over a qualified call for things used repeatedly in a file
  (`format(...)`, `emptyList()`, assertion methods). Don't static-import something used
  once where the qualified name reads better.
- Keep `jakarta.*` in its own group; do not fold it into "third party".
