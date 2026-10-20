# Proposal

## Why
A tn-query filter can name only the top-level fields of the entity it filters. An entity that holds a value in an embedded type -
tn-user-service's `phone`, a country code and a number held together as `Phone` - has fields nobody can filter on: `phone.number = 7911123456`
is rejected as an unknown name, `phone = ...` fails in the database, and `phone ≈ ...` fails because a `Phone` is not a string. Verified
against a real Postgres on 2026-10-20. okayat-platform's admin console wants to find a user by part of a phone number
(`admin-console-foundation`), and any service that embeds a value hits the same wall.

## What Changes
- A filter (and a sort) on the JPA implementation can name a field of an embedded type with a dotted name, such as
  `phone.number ≈ *7911*`, `phone.countryCode = 44`.
- The value in the filter is read as the embedded field's own type (`countryCode` as a number, `number` as text), as a top-level field's is.
- Nothing changes for an entity with no embedded type, nor for a filter that names only top-level fields.
- tn-query-java and tn-query-jdbc are not changed: neither has a notion of an embedded type.

## Capabilities

### New Capabilities
- `tn-query`: what a filter expression can name and how its values are read, starting with embedded fields.

### Modified Capabilities

## Impact
- `tn-query` (value mappers for fields of an embedded type) and `tn-query-jpa` (names and sort for embedded fields): a new minor version of each.
- Consumers pick it up by bumping the version; none has to change code. tn-user-service then lets `?q=phone.number ≈ *...*` work with no
  change of its own beyond the bump (and a test).
- Requested by okayat-platform `admin-console-foundation`; recorded in `catalog.yaml` `requested_changes` on `tn-query`.
