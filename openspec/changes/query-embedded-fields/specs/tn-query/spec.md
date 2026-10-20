# Spec Delta

## ADDED Requirements

### Requirement: A filter can name a field of an embedded type
The JPA implementation of tn-query SHALL let a filter name a field of an embedded type of the entity by its dotted name, such as
`phone.number`, in any comparison, and a value SHALL be read as the type of the field it is compared with. A name that is not a field
of the entity or of one of its embedded types SHALL still be rejected as unknown.

#### Scenario: Equal to an embedded text field
- **WHEN** a filter says `phone.number = 7911123456` and a user holds that number
- **THEN** that user is found

#### Scenario: Like an embedded text field
- **WHEN** a filter says `phone.number ≈ *7911*`
- **THEN** users whose number contains 7911 are found

#### Scenario: An embedded number is compared as a number
- **WHEN** a filter says `phone.countryCode = 44`
- **THEN** users with country code 44 are found

#### Scenario: Embedded and top-level fields combine
- **WHEN** a filter says `phone.number ≈ *7911* || email ≈ *sam*`
- **THEN** users matching either are found

#### Scenario: An unknown embedded name is rejected
- **WHEN** a filter names `phone.extension`, which the embedded type does not have
- **THEN** the filter is rejected as an unknown name

#### Scenario: An entity with no embedded type is unchanged
- **WHEN** a filter names only top-level fields
- **THEN** it behaves as it did before

#### Scenario: Sorting by an embedded field
- **WHEN** results are sorted by `phone.number`
- **THEN** they are ordered by that field
