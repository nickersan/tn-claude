# Database standard

Status: **placeholder**.

Applies to components that own a relational schema (and conditionally to
`java-spring-service` components that persist data).

To be distilled from the existing data services and the `database/` directory at the
`tn` root. Expected topics:

- Engine: PostgreSQL (the parent manages the `postgresql` driver and
  `flyway-database-postgresql`).
- Migrations: Flyway, versioned scripts, naming, forward-only policy, where scripts
  live.
- Naming: `snake_case` tables and columns (as seen in `tn-query` JDBC tests —
  `boolean_value`, `local_date_time_value`), singular vs plural table names, foreign
  key conventions. Primary keys: see [`../java/identifiers.md`](../java/identifiers.md)
  (TSID via `hypersistence-tsid`, already drafted) — this file should reference that
  rather than duplicate it.
- Schema ownership: one service per schema; no shared write access.
- Test strategy: H2 for fast tests, Testcontainers PostgreSQL for fidelity.
