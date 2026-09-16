# Database standard

Applies to components that own a relational schema (and conditionally to
`java-spring-service` components that persist data).

The engine and testing sections below are drafted for real — the first services to
apply them are `tn-auth-service`, `tn-user-service`, and `tn-temporary-token-service`,
replacing the H2 they use today. Naming/migrations/ownership are still placeholder.

## Engine — PostgreSQL everywhere, no H2

**PostgreSQL is the only database this layer uses — in every environment,
including local, and in every test that touches a real database.** `tn-parent`
already manages the driver (`org.postgresql:postgresql`) and Flyway's Postgres
module (`flyway-database-postgresql`).

H2 is not a lighter-weight substitute for Postgres here, even locally — it doesn't
share the same SQL dialect or the same behaviour, so an H2-backed test proves less
than it looks like it proves, and a service that runs on H2 locally but Postgres in
every real environment is running on something it was never actually tested
against. `tn-parent` still manages `com.h2database:h2` (test-scope) for other,
not-yet-touched components — don't remove it from `tn-parent`, just stop depending
on it in any component you touch.

This changes deployment as well as testing: `tn-auth-service`,
`tn-user-service`, and `tn-temporary-token-service` currently run against a
file-backed H2 database in the `local` Kustomize overlay purely to avoid running a
database pod locally — replaced by a real (containerised) Postgres in that overlay
instead, so local matches AWS RDS in every other environment. See
`../kubernetes/README.md`.

## Testing — Testcontainers, not H2, not mocks-only

**Integration tests (`src/it`) that need a real database run against PostgreSQL
via Testcontainers.** Unit tests (`src/test`) don't touch a database at all
(mock the repository, as the existing tests already do) — Testcontainers is for
the tier that specifically wants real persistence behaviour, not a blanket
replacement for mocking.

New managed dependencies needed in `tn-parent` (not yet present — `org.testcontainers:
postgresql` already is):

```xml
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-testcontainers</artifactId>
  <version>${spring-boot.version}</version>
  <scope>test</scope>
</dependency>

<dependency>
  <groupId>org.testcontainers</groupId>
  <artifactId>junit-jupiter</artifactId>
  <version>1.21.4</version>
  <scope>test</scope>
</dependency>
```

Shape, using `@ServiceConnection` (Spring Boot auto-configures the datasource from
the running container — no manual `@DynamicPropertySource`):

```java
@DataJpaTest
@Testcontainers
class EmailRepositoryTest
{
  @Container
  @ServiceConnection
  static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:17");

  ...
}
```

**Known gotcha on Spring Boot 4** (`tn-parent` is on 4.0.5): a bare
`@ServiceConnection` on a `PostgreSQLContainer` field has been reported to fail
connection-details resolution
([spring-projects/spring-boot#48234](https://github.com/spring-projects/spring-boot/issues/48234),
closed as user-config, not a framework bug). If auto-detection fails, give it an
explicit name: `@ServiceConnection("postgresql")`. Confirmed needed —
`tn-auth-service` got "Failed to determine a suitable driver class" with the bare
annotation, fixed by naming it.

**Two more dependencies needed alongside the ones above, confirmed while
implementing this against `tn-auth-service`** (neither is optional, both already
managed by `tn-parent`, just need declaring in the component):
- `org.postgresql:postgresql` — the actual JDBC driver. `org.testcontainers:
  postgresql` only manages the container; without the driver too, startup fails
  with `ClassNotFoundException: org.postgresql.Driver`.
- `org.flywaydb:flyway-database-postgresql` — Flyway's core module doesn't know
  the Postgres dialect on its own; without this, Flyway fails with
  `FlywayException: Unsupported Database: PostgreSQL <version>` even with the
  driver present and a real Postgres container running.

**Every full `@SpringBootTest` context needs a real datasource, not just tests
that use `@DataJpaTest`** — Hibernate/Flyway auto-configure a `DataSource` at
context startup regardless of whether a given test actually exercises
persistence (e.g. a controller test that mocks the service layer entirely still
needs one, now that H2 no longer transparently provides it). Share one
abstract base class declaring the container across such tests rather than
repeating the container field in each one — but see the singleton-container
gotcha immediately below before reaching for `@Testcontainers`/`@Container` to
do it.

**Gotcha confirmed the hard way: don't use `@Testcontainers`/`@Container` on a
container field declared in a shared abstract base class.** Those annotations
stop the container after the *first* test class that used it finishes — every
other class extending the same base then fails with `Connection refused`,
because Maven Surefire reuses one JVM across test classes by default, so the
static field (and the now-stopped container it points to) is shared, not
reset per class. `tn-user-service`'s find-or-create concurrency test (§4.7)
hit this directly. Fix: Testcontainers' own documented "singleton container"
pattern — start the container manually in a static initializer, no
`@Testcontainers`/`@Container` annotations, and never call `.stop()` (Ryuk
reaps it when the JVM exits):

```java
public abstract class AbstractPostgresIntegrationTest
{
  @ServiceConnection("postgresql")
  static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:17");

  static
  {
    postgres.start();
  }
}
```

A container declared directly inside one `@DataJpaTest` class (not via a
shared base) doesn't have this problem — each class's own static field is
independent, so the normal `@Testcontainers`/`@Container` form is fine there.

## Still placeholder

- Migrations: Flyway, versioned scripts, naming, forward-only policy, where
  scripts live.
- Naming: `snake_case` tables and columns (as seen in `tn-query` JDBC tests —
  `boolean_value`, `local_date_time_value`), singular vs plural table names,
  foreign key conventions. Primary keys: see
  [`../java/identifiers.md`](../java/identifiers.md) (TSID via
  `hypersistence-tsid`, already drafted) — this file should reference that rather
  than duplicate it.
- Schema ownership: one service per schema; no shared write access.
