# Concurrency-safe find-or-create (and any other check-then-act operation)

**Every service in this layer runs as multiple instances in any real
environment — in-process synchronization (a `synchronized` block, a local lock)
provides no safety at all across them.** A find-or-create (or any other
check-then-act sequence — "does this exist, if not create it") must be made safe
by the database, not the application process. On PostgreSQL, the idiomatic
one-statement version is an upsert against the unique constraint:

```sql
INSERT INTO identifier (identifier_type, identifier_value, ...)
VALUES (:type, :value, ...)
ON CONFLICT (identifier_type, identifier_value)
DO UPDATE SET identifier_value = EXCLUDED.identifier_value
RETURNING *;
```

The `DO UPDATE SET <col> = EXCLUDED.<col>` (a functional no-op) is the standard
Postgres idiom to make `RETURNING` give you the existing row on conflict, not
just on insert — `DO NOTHING` alone returns no row when the conflict branch
fires. Alternative if a raw upsert doesn't fit cleanly (e.g. behind Spring Data
JPA's repository abstraction): attempt the insert, catch the
`DataIntegrityViolationException` Spring translates a unique-constraint
violation into, and re-`find` on conflict — but be deliberate about the
transaction boundary if you do, since a caught constraint violation still marks
a surrounding `@Transactional` rollback-only in Spring; the insert attempt and
the conflict re-fetch need to be arranged so the retry isn't silently doomed by
the same transaction. The native upsert avoids that wrinkle entirely, which is
why it's the preferred shape.

**Naming the fragment interface: `<Entity>RepositoryExtended`, not
`<Entity>RepositoryCustom`.** When a Spring Data repository needs hand-written
methods alongside its generated ones (a native upsert like the above, a bulk
op, anything `CrudRepository`/`tn-query`'s queryable base can't derive), the
three-piece shape is:

- `<Entity>Repository extends CrudRepository<Entity, Id>, <Entity>RepositoryExtended`
  — the public interface callers inject.
- `<Entity>RepositoryExtended` — a plain interface declaring just the
  hand-written methods.
- `<Entity>RepositoryImpl` — implements `<Entity>RepositoryExtended`; Spring
  Data finds it by the `Impl` suffix convention and composes it into
  `<Entity>Repository`'s proxy automatically.

`Extended` names what the interface *is* (more methods on top of the
generated set) rather than how it got there (`Custom` describes the
mechanism, not the interface's role, and reads the same whether the
extension is one bespoke method or ten). Applies wherever this repository-
fragment pattern is used, not just `tn-user-service`'s `UserRepository`
(the first place it's used in this layer).
