# Tasks

Implemented in `tn-query-jpa` (X:\Projects\tn\tn-query-jpa), with `tn-query` (core) touched only if the list of fields needs a helper.

## 1. Names and values for embedded fields

- [ ] 1.1 Write tests that fail first: `NameMappings` lists `phone.countryCode` and `phone.number` for an entity with an `@Embedded Phone`, maps each to the embedded path, leaves out plain `phone`, and leaves an entity with no embedded type as it was; verify they fail before the implementation.
- [ ] 1.2 Implement embedded discovery in `NameMappings` (an `@Embeddable` field replaced by its own fields under dotted names, recursively) and verify the tests pass.
- [ ] 1.3 Build the value mappers from the flattened name-and-type list (`ValueMappers.forFields(Collection<Field>)`) in `AbstractQueryableRepository` and verify with a test that `phone.countryCode = 44` is read as a number and `phone.number` as text.

## 2. Filtering and sorting against a database

- [ ] 2.1 Add Postgres integration tests for each scenario in the spec (equal, like, number, combined with a top-level field, unknown embedded name rejected, top-level-only unchanged) and verify they pass.
- [ ] 2.2 Resolve a dotted sort property through the embedded path in `AbstractQueryableRepository` and verify with an integration test that results sort by `phone.number`.

## 3. Release and use

- [ ] 3.1 Document dotted names in `tn-query-jpa`'s README and verify the example in it runs.
- [ ] 3.2 Publish `tn-query` and `tn-query-jpa`, bump the versions in `tn-user-service`, and verify with a tn-user-service integration test that `phone.number ≈ *7911*` finds a user by part of its number.
- [ ] 3.3 Update `catalog.yaml` (remove the `requested_changes` entry on `tn-query`) and archive the change so `openspec/specs/tn-query/spec.md` carries the requirement.
