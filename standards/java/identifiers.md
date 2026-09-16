# Java — entity identifiers

Applies wherever a new JPA entity needs a primary key. Existing entities are not
retrofitted as a matter of course — see Scope below.

## The rule

**New entity identifiers are TSIDs, not database sequences.** Use
[`io.hypersistence:hypersistence-tsid`](https://github.com/vladmihalcea/hypersistence-tsid)
(already managed by `tn-parent`) rather than `@GeneratedValue(strategy =
GenerationType.SEQUENCE)`.

TSIDs (Time-Sorted Unique IDentifiers) are 64-bit, roughly time-ordered, generated
without a database round-trip. They keep the simplicity of a `Long`/`BIGINT` primary
key (indexing, joins, JSON serialisation all work exactly as before) while removing
the sequence as a point of coordination and while not leaking a monotonically
increasing row count the way a plain sequence does.

## How

Use the `@Tsid` Hibernate annotation, not manual assignment. It lives in a
*different* artifact from the raw generator — `io.hypersistence:hypersistence-tsid`
(already in `tn-parent`) ships only `io.hypersistence.tsid.TSID`, the bare value
type; the JPA/Hibernate integration is in the separate "Hypersistence Utils"
project, published as one artifact per supported Hibernate line:

```xml
<dependency>
  <groupId>io.hypersistence</groupId>
  <artifactId>hypersistence-utils-hibernate-71</artifactId>
  <version>3.15.5</version>
</dependency>
```

**Use the `-71` artifact.** `tn-parent` (via `spring-boot-dependencies` 4.0.5)
manages Hibernate `7.2.7.Final`, and the hypersistence-utils project's own
compatibility table names `hypersistence-utils-hibernate-71` as the artifact for
**both Hibernate 7.1 and 7.2** — this isn't a same-major guess, it's the documented
pairing. `-72` does not exist as a separate artifact. If `tn-parent` ever moves to
Hibernate 7.3/7.4, switch to `hypersistence-utils-hibernate-73` instead — check the
project's current compatibility table rather than assuming the suffix maps 1:1 to
the Hibernate minor.

```java
import io.hypersistence.utils.hibernate.id.Tsid;

@Entity
@Table(name = "identifier")
public class Identifier
{
  @Id
  @Tsid
  @Column(name = "identifier_id")
  private Long id;

  ...
}
```

`@Tsid` (`@Target({FIELD, METHOD})`) hooks in via Hibernate's own generator SPI
(`@IdGeneratorType(TsidGenerator.class)`) — this is a proper Hibernate identifier
generator, not a lifecycle-callback workaround. Column type is `BIGINT` — identical
to the sequence-based columns it replaces.

## Scope

This is a standard for **new** identifiers, applied as each entity is next touched —
not a retrofit mandate. Migrating an existing sequence-based id to TSID only changes
how *future* rows get their id; existing rows keep their (smaller, sequence-issued)
values unchanged, since both are just `Long`/`BIGINT` — there is no need to rewrite
historical primary keys. Confirm whether a service has real deployed rows before
treating a migration as trivial.
