# Logging standard

Applies to `java-spring-service` components (long-running services). Not `java-cli`
(interactive CLIs use plain human-readable output) or `java-library` (a library emits
SLF4J log statements but doesn't own the encoder/appender configuration this standard
governs — that's the application's concern).

## The rule

**Every service logs structured JSON, and never logs a sensitive value unmasked.**
Both halves are mandatory, not aspirational — a service that logs plain text, or that
logs a token/passcode/PII value in the clear, does not meet this standard.

## Why structured

A free-text log line (`log.info("issued token for " + identifier)`) is only
greppable, not queryable, and — critically for the masking rule below — a raw string
concatenated into the message can't be reliably masked by field. A structured field
(`log.info("issued token", kv("identifierType", type))`) can be masked by name
regardless of what value ends up in it. Prefer passing data as structured
arguments/key-value pairs over building the message string yourself:

```java
import static net.logstash.logback.argument.StructuredArguments.kv;

log.info("Issued session", kv("identifierType", identifier.type()), kv("subjectId", subject.id()));
```

not

```java
log.info("Issued session for " + identifier.type() + " " + identifier.value()); // don't — unmaskable, and puts the value in the message
```

## Library choice

- **SLF4J API** (`org.slf4j:slf4j-api`) + **Logback** (`ch.qos.logback:logback-
  classic`) — both already managed by `tn-parent`.
- **`net.logstash.logback:logstash-logback-encoder`** for JSON output and masking —
  **not yet in `tn-parent`**; add it there (dependencyManagement) as part of
  implementing this standard, don't pin it per-service.
- Configure via `logback-spring.xml` (Spring Boot's convention — lets profile-
  specific overrides work) using `LogstashEncoder` (or
  `LoggingEventCompositeJsonEncoder` if you need to compose providers):

  ```xml
  <configuration>
    <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
      <encoder class="net.logstash.logback.encoder.LogstashEncoder">
        <decorator class="net.logstash.logback.mask.MaskingJsonGeneratorDecorator">
          <defaultMask>****</defaultMask>
          <path>token</path>
          <path>code</path>
          <path>refreshToken</path>
          <path>accessToken</path>
          <value>[A-Za-z0-9-_]{20,}\.[A-Za-z0-9-_]{10,}\.[A-Za-z0-9-_]{10,}</value> <!-- JWT shape, belt-and-braces. <value> is
               the simple element (default mask) - <valueMask> is a different, more complex element taking nested
               <value>/<mask> children for custom capture-group masks. Verified against logstash-logback-encoder 9.0's
               actual API, not assumed. -->
        </decorator>
      </encoder>
    </appender>
    <root level="INFO">
      <appender-ref ref="STDOUT"/>
    </root>
  </configuration>
  ```

  `MaskingJsonGeneratorDecorator` supports masking by field **path** (exact field
  name/path, the preferred mechanism — see "prefer structured arguments" above) and
  by **value** (regex over any field's value, a safety net for values that slip
  through in the wrong place). Use both: path-mask every field you know is sensitive
  by name; value-mask shapes that are sensitive wherever they appear (a JWT, a
  6-digit code next to the word "code").

## What must always be masked

Treat this list as a minimum, not exhaustive — when in doubt, mask it:

- One-time passcodes / verification codes (the actual `tn-temporary-token-service`
  token value) — this is the single highest-value thing to get right; a leaked OTP
  in a log is a direct account-takeover path.
- JWT access and refresh token values.
- Full identifier values (email address, phone number) — these are PII. Where the
  identifier itself is useful for debugging, log a stable non-reversible reference
  (e.g. the account's internal id) instead of the raw value; if the raw value must
  appear, mask part of it (e.g. `j***@example.com`, `+44 7*** ***890`).
- Anything else conventionally sensitive if it ever appears in these services:
  passwords (n/a — this layer is passwordless), API keys, signing keys.

## This covers business-event logging, not startup config logging

`tn-service.PropertyLogger` (in `tn-service`, not this repo) is a separate,
existing mechanism: an `ApplicationListener` that logs every resolved Spring
`Environment` property at startup, masking any whose *name* matches a regex
(ships with `REGEX_PASSWORD`/`REGEX_SECRET`). It solves a different layer —
config values at boot, not application events at runtime — and every
`java-spring-service` should register it (`tn-user-service` already does; see
that service's `Application.java`) **in addition to**, not instead of, the
structured/masked business-log setup above. Add both, don't treat one as
covering the other.

## What logging is for here

Log the *event* and enough structured context to debug and audit it — not the
payload. "Issued session for identifierType=EMAIL, subjectId=1234" is useful and
safe. The email address itself adds little debugging value over the subject id and
is exactly what must not leak.

## Status

Drafted (not a placeholder) as of the `tn-auth-service`/`tn-user-service` overhaul
(see `tn-claude/openspec/changes/add-identity-and-notification-capabilities`) — the
first services to implement it. `logback-spring.xml` above is a starting
configuration, not a finished one; each service still needs its own path list for
whatever it logs. Non-JVM equivalents (TypeScript services, if any ever exist in
this layer) are not covered yet.
