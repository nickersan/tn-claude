## Context
See proposal.md - Why. Today `tn-query-jpa`'s `NameMappings.forFields(root)` maps the entity's declared field names to `root.get(name)`,
and `tn-query`'s `ValueMappers.forFields(Class)` builds a value mapper per declared field of a supported type, so a field of type `Phone`
has a name but no value mapper and no usable expression. `ValueMappers.forFields(Collection<Field>)` already builds mappers for a list of
name-and-type pairs, so the core library needs no new notion of an embedded type.

## Decisions

### 1. Embedded means JPA-embedded, and lives in tn-query-jpa
A field is embedded if its type is annotated `@Embeddable`. That is JPA's concept, so the discovery of embedded fields belongs in
tn-query-jpa; tn-query (core) gains nothing JPA-specific. tn-query-jpa lists the entity's fields, replaces each embedded one by its own
fields under a dotted name (`phone` becomes `phone.countryCode` and `phone.number`), and hands that list to
`ValueMappers.forFields(Collection<Field>)` for the value types. Names map to `root.get("phone").get("number")`. The plain `phone` name
is left out: it can be neither compared nor liked, which is the error today.

Rejected: a dotted-name feature in tn-query core (it has no embedded concept; the parser already accepts a dotted name, as the error "Unknown name:
phone.number" shows); asking each service to override name mappings (every service would repeat it).

### 2. One level, and top-level names keep working
An embedded type inside an embedded type is flattened the same way, with a longer dotted name; there is no limit beyond the entity's
structure. Existing filters name top-level fields and are unaffected. A top-level field that happens to contain a dot cannot exist in Java,
so a dotted name is never ambiguous.

### 3. Sorting follows
`AbstractQueryableRepository` sorts with `root.get(property)`, which a dotted property breaks. It resolves a dotted property through the
same path, so sorting and filtering name fields the same way.

### 4. Java and JDBC are left alone
tn-query-java reads fields by reflection and tn-query-jdbc maps names to columns; neither has an embedded type to flatten. If a use arises
there, it is its own change.

## Risks / Trade-offs
- A dotted name is new surface in a shared library → covered by the scenarios, including the unknown-name rejection, and a test per
  implementation boundary (core unchanged, JPA changed).
- Entities that already declare a column with the flattened name → impossible, since a Java field name cannot hold a dot.
