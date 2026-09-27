# Java — error handling

## Exception types

- Domain exceptions are **unchecked**: extend `RuntimeException` directly.
  Examples: `QueryException`, `QueryParseException`, `WrappedException`.
- Give each one two constructors and nothing else:

  ```java
  public class QueryParseException extends RuntimeException
  {
    public QueryParseException(String message)
    {
      super(message);
    }

    public QueryParseException(String message, Throwable cause)
    {
      super(message, cause);
    }
  }
  ```

- One exception type per meaningful failure category, in the same package as the code
  that throws it. A more specific exception may extend a broader one from the same
  area (`QueryParseException` sits alongside `QueryException`).
- Use JDK exceptions for genuine programming errors:
  `IllegalArgumentException` for a bad argument, `IllegalStateException` for an
  impossible state (`"Failed to find: " + CREATE_TABLE_SCRIPT`).
- **The exception's class name carries its meaning.** A caller should be able to tell
  what went wrong from the type alone, without inspecting a status code, a field, or
  the message. Don't throw one generic exception and distinguish cases by a value
  inside it:

  ```java
  // not: DownstreamStatusException carrying a 429 that each caller must check for
  throw new TokenGenerationThrottledException(owner);
  ```

  A generic exception is still right where the case genuinely doesn't matter to any
  caller, e.g. a proxy passing a downstream 4xx through unchanged.

## Declaring what a method throws

**A public method declares, in its `throws` clause, the domain exceptions it
deliberately throws, unchecked ones included.** Private methods may, where it helps
the reader. The signature is the method's contract, where the
compiler, the IDE and a reader all see it. Don't describe them in Javadoc `@throws`
instead:

```java
public UserSession verifyPasscode(Identifier identifier, String passcode) throws UnauthenticatedException
```

- Declare only exceptions the method throws on purpose, as part of its behaviour. Not
  every runtime exception something beneath it might raise.
- Because the exception's name carries its meaning (above), a `throws` clause needs no
  Javadoc to explain it. Add Javadoc only for what neither the signature nor the names
  can say.
- REST endpoints are the exception to the rule: their error contract is the HTTP
  statuses documented with `@ApiResponse` on the `api` interface
  (`../spring-boot/README.md`), not a `throws` clause.

## Messages

Format is `"<human-readable description>: " + <offending value>` — a description, a
colon, a space, then the value that caused it:

```java
throw new QueryParseException("Illegal query part: " + queryPart);
throw new QueryException("Getter missing for: " + left);
throw new QueryException("Type mismatch: " + obj1 + " and " + obj2);
throw new IllegalStateException("Failed to find: " + CREATE_TABLE_SCRIPT);
```

- Sentence-style description, no trailing period.
- Always include the value under discussion; never throw with a bare category string.
- Don't log-and-throw. Throw, and let the boundary handle it.

## Wrapping checked exceptions in lambdas

Checked exceptions in a functional pipeline are handled with the `tn-lang`
`util.function` helpers, not ad-hoc `try/catch` in every lambda:

- `Lambdas.wrapFunction` / `wrapConsumer` / `wrapBiConsumer` / `wrapSupplier` adapt a
  `*WithThrows` variant to the standard functional interface.
- They rethrow `RuntimeException` as-is and wrap anything else in `WrappedException`.
- `Lambdas.unwrapException` unwraps a `WrappedException` back to its cause at the
  boundary where you handle it.

```java
stream.map(Lambdas.wrapFunction(this::parseRow)).toList();
```

Prefer these over introducing new bespoke try/catch-to-runtime plumbing.

## Resources

Use try-with-resources for anything `AutoCloseable` (JDBC `Connection`,
`Statement`, `ResultSet`, `InputStream`). Nest the blocks rather than juggling manual
`close()`:

```java
try (PreparedStatement statement = connection.prepareStatement(sql))
{
  statement.setValues(...);
  try (ResultSet resultSet = statement.executeQuery())
  {
    ...
  }
}
```
