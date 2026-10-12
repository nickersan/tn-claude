# tn-user-service Specification

## Purpose
Holds a user's profile and the identifiers (email, phone) linked to it — this
service is the identity anchor: its own id is the stable id used everywhere
once a user is authenticated, including as the subject `tn-auth-service` mints
a session for (see that capability's Purpose — `tn-auth-service` itself has no
concept of an identifier or an account; resolving one to a stable id is
entirely this service's job). Deliberately does not issue or verify tokens —
that separation is intentional and retained by `tn-auth-service`.

## Requirements

### Requirement: A user has at most one identifier of each type
The system SHALL store at most one email address and at most one phone number
per user, each individually unique across every user — no two users may share
the same email, and no two users may share the same phone number.

#### Scenario: A user is created with one identifier
- **WHEN** a caller creates a user with an email address
- **THEN** the system stores that email address against the new user, and no
  other user may be created or updated with the same email address

#### Scenario: A second identifier of a different type coexists
- **WHEN** a user that already has an email address linked has a phone number
  linked to it
- **THEN** the system stores both, and either can subsequently be used to find
  that same user

### Requirement: A phone number is a country code and a national number
The system SHALL hold a phone number as its country calling code and its
national significant number — the number without the trunk prefix used when
dialling within the country (the UK's leading 0), but keeping a leading 0 that
is part of the number (Italy's). Both parts SHALL be set or neither. The pair
SHALL be unique across users. The system SHALL validate the pair against the
country's numbering plan and reject a number not already in national
significant form, so every caller stores one form of a number; callers
normalise first.

#### Scenario: A valid number is stored as given
- **WHEN** a caller creates a user with country code 44 and number 7911123456
- **THEN** the system stores and returns that country code and number

#### Scenario: An Italian number keeps its leading zero
- **WHEN** a caller creates a user with country code 39 and number 0612345678
- **THEN** the system stores the number with its leading 0

#### Scenario: A trunk prefix is rejected
- **WHEN** a caller creates a user with country code 44 and number 07911123456
- **THEN** the system rejects the request

#### Scenario: A number too short for its country is rejected
- **WHEN** a caller supplies a number too short to be valid for its country code
- **THEN** the system rejects the request

#### Scenario: Only one part is rejected
- **WHEN** a caller supplies a country code without a number, or a number
  without a country code
- **THEN** the system rejects the request

### Requirement: Profile details are optional beyond an identifier
The system SHALL allow a profile to exist with only one identifier set; name
fields and the other identifier type are optional and may be supplied later.

#### Scenario: Profile created with a single identifier only
- **WHEN** a caller creates a profile supplying only an email address
- **THEN** the system creates the profile without requiring a name or a phone
  number

### Requirement: Find-or-create by identifier is a single safe operation
The system SHALL provide a find-or-create operation that, given either an
email address or a phone number, returns the existing user for it or creates
one if none exists, and SHALL guarantee at most one user is ever created for a
given identifier value even when the operation is called concurrently for the same
new value (the system runs as multiple instances in any real environment, so
this guarantee SHALL hold across instances, not just within one process).

#### Scenario: Creates when absent
- **WHEN** a caller invokes find-or-create for an identifier value with no
  existing user
- **THEN** the system creates a user with that identifier and returns it

#### Scenario: Returns the existing user when present
- **WHEN** a caller invokes find-or-create for an identifier value that
  already belongs to a user
- **THEN** the system returns the existing user without creating another one

#### Scenario: The same phone number finds the same user
- **WHEN** a caller invokes find-or-create twice for the same country code and
  number
- **THEN** both calls return the same user

#### Scenario: Neither or both identifiers is rejected
- **WHEN** a caller invokes find-or-create with both an email address and a
  phone number, or with neither
- **THEN** the system rejects the request

#### Scenario: Concurrent calls for the same new identifier value create exactly one user
- **WHEN** two or more calls invoke find-or-create for the same identifier
  value at the same time, and no user exists for it beforehand
- **THEN** exactly one user is created, and every caller receives that same
  user

### Requirement: A user is created or updated by supplying its full representation
The system SHALL accept the same shape — email, phone, and name fields,
without an id — for both creating a new user and replacing an existing one's
profile. Updating a user's profile SHALL be permitted to change its email
and/or phone, including adding a second identifier alongside an existing one;
the system does not treat an identifier as immutable once set. The system
does not itself verify that a supplied identifier belongs to the caller — the
caller is trusted to have already verified it (e.g. via
`tn-temporary-token-service`'s OTP flow) before requesting the create or
update.

#### Scenario: Adding a second identifier via update
- **WHEN** a caller updates an existing user, supplying both the identifier it
  already has and a second identifier of the other type
- **THEN** the system stores both, and either can subsequently be used to find
  that same user

#### Scenario: Changing an existing identifier via update
- **WHEN** a caller updates an existing user, supplying a different value for
  an identifier type it already has
- **THEN** the system replaces the existing value with the supplied one

#### Scenario: A value already belonging to a different user is rejected
- **WHEN** a caller creates or updates a user supplying an email address or
  phone number that already belongs to a different user
- **THEN** the system rejects the request and does not change either user's
  stored identifiers

### Requirement: A user must have at least one identifier
The system SHALL reject creating or updating a user such that it would have
neither an email address nor a phone number.

#### Scenario: Creating a user without any identifier
- **WHEN** a caller creates a user supplying neither an email address nor a
  phone number
- **THEN** the system rejects the request

#### Scenario: Updating a user to remove its only identifier
- **WHEN** a caller updates a user, supplying neither an email address nor a
  phone number where the user previously had at least one
- **THEN** the system rejects the request and leaves the user's stored
  identifiers unchanged

### Requirement: This service does not issue or verify tokens
The system SHALL NOT issue, refresh, or verify a session token — that is
`tn-auth-service`'s responsibility, not this service's.

#### Scenario: Profile operations never return a token
- **WHEN** a caller creates, reads, or updates a user
- **THEN** the response contains profile data only, never a token

### Requirement: User records use TSID primary keys
The system SHALL assign each user record's primary key as a TSID, not a
database-sequence value, per `tn-claude/standards/java/identifiers.md`. This id
is the stable id used everywhere once a user is authenticated, including the
subject id passed to `tn-auth-service.generate()`.

#### Scenario: New user gets a TSID
- **WHEN** the system creates a user
- **THEN** the record's primary key is a TSID value, not a sequence-issued one

### Requirement: Structured, masked logging
The system SHALL log profile creation, lookup, and update events as
structured (JSON) log entries, per `tn-claude/standards/logging/README.md`,
and SHALL NOT log an email address or phone number value unmasked.

#### Scenario: Profile events are logged without leaking an identifier value
- **WHEN** the system creates, finds, or updates a user
- **THEN** it emits a structured log entry describing the event, and that
  entry does not contain the unmasked email address or phone number value

### Requirement: A user can have an avatar, kept apart from the user
The system SHALL let a user have one avatar picture, set, read and removed through
`PUT`, `GET` and `DELETE /v1/users/{id}/avatar`. The picture SHALL be held in a table
of its own, so that reading users never reads a picture. The user representation SHALL
carry `avatarVersion` only: a number that changes with each new picture and is absent
when the user has none. The version SHALL count per user and never be reused for that
user, including after the avatar is removed and another set. Updating a user SHALL keep
their avatar, and deleting a user SHALL delete it. The avatar a user has is replaced or
deleted in place: no earlier picture is kept.

#### Scenario: Setting an avatar
- **WHEN** a caller sets an avatar for a user who has none
- **THEN** the system returns the user with `avatarVersion` 1, and serves the picture

#### Scenario: Replacing an avatar changes its version
- **WHEN** a caller sets an avatar for a user who has one
- **THEN** the system serves only the new picture, and `avatarVersion` has increased

#### Scenario: A removed avatar's version is not reused
- **WHEN** a caller removes a user's avatar and then sets another
- **THEN** the new `avatarVersion` is higher than any the user has had

#### Scenario: Versions count per user
- **WHEN** two users each have their first avatar set
- **THEN** both have `avatarVersion` 1

#### Scenario: Reading users does not read pictures
- **WHEN** a caller gets, lists, updates or finds-or-creates a user who has an avatar
- **THEN** the system does not load the picture

#### Scenario: Updating a user keeps their avatar
- **WHEN** a caller updates a user who has an avatar
- **THEN** the user's `avatarVersion` and picture are unchanged

#### Scenario: Deleting a user deletes their avatar
- **WHEN** a caller deletes a user who has an avatar
- **THEN** the system holds no picture for that user

#### Scenario: An unknown user has no avatar
- **WHEN** a caller sets, reads or removes the avatar of a user that does not exist
- **THEN** the system responds not found

### Requirement: An avatar is a small JPEG or PNG, stored without its metadata
The system SHALL accept as an avatar only a JPEG or PNG of at most 100 KB, as sent and
as stored, and at most 2048 pixels on a side. It SHALL judge a file by its contents,
not by the content type it is sent with. It SHALL read a picture's size from its header
and refuse one that is too large before decoding it, decode with the picture's embedded
metadata left unread, and decode at most a configured number of pictures at once. It
SHALL store a picture written afresh from its pixels alone, so that none of the photo's
embedded metadata (location, camera details, time taken, colour profile) is kept. It
SHALL stop reading an upload once it exceeds 100 KB.

#### Scenario: A picture within the limits is accepted
- **WHEN** a caller sets a JPEG or PNG of at most 100 KB and 2048 pixels on a side
- **THEN** the system accepts it

#### Scenario: A picture over 100 KB is refused
- **WHEN** a caller sets a picture over 100 KB
- **THEN** the system responds bad request and the user's avatar is unchanged

#### Scenario: An oversized body is not read in full
- **WHEN** a caller sends an upload of tens of megabytes
- **THEN** the system refuses it having read little more than 100 KB

#### Scenario: A file that is not a JPEG or PNG is refused
- **WHEN** a caller sets a text file sent as `image/jpeg`, or a GIF
- **THEN** the system responds bad request and the user's avatar is unchanged

#### Scenario: A picture claiming enormous dimensions is refused undecoded
- **WHEN** a caller sets a small file whose header gives 20000 by 20000 pixels
- **THEN** the system responds bad request without decoding it

#### Scenario: Location is removed
- **WHEN** a caller sets a JPEG whose EXIF data includes GPS coordinates
- **THEN** the picture the system serves has no EXIF data and the same dimensions

#### Scenario: A picture that is too large once re-encoded is refused
- **WHEN** a caller sets a PNG under 100 KB that is over 100 KB once written afresh
- **THEN** the system responds bad request and the user's avatar is unchanged

#### Scenario: A malformed colour profile does not stop a picture being accepted
- **WHEN** a caller sets a JPEG with a colour profile that is not valid
- **THEN** the system accepts the picture, stored without the profile

### Requirement: Avatar uploads are limited
The system SHALL limit how many avatar uploads a user may start in a period, across
every instance, counting uploads that are then refused, and SHALL respond too many
requests to the excess. It SHALL respond too many requests, too, when it is already
decoding as many pictures as it is configured to.

#### Scenario: Uploading too often is refused
- **WHEN** a user starts more uploads in the period than the limit allows
- **THEN** the system responds too many requests and the user's avatar is unchanged

#### Scenario: Refused uploads count
- **WHEN** a user's uploads are refused as not pictures until the limit is reached
- **THEN** their next upload is refused as too many requests

#### Scenario: The limit is per user
- **WHEN** one user has reached the limit
- **THEN** another user can still upload

### Requirement: An avatar is served as the image it is, and kept private
The system SHALL serve an avatar with the content type of the image it stored
(`image/jpeg` or `image/png`), never the type the upload gave, with
`X-Content-Type-Options: nosniff` and `Cache-Control` marking it private. It SHALL NOT
write a picture's contents to a log.

#### Scenario: Served with the stored type
- **WHEN** a caller reads the avatar of a user who set a PNG sent as `image/jpeg`
- **THEN** the response is `image/png`, with `nosniff` and a private `Cache-Control`

#### Scenario: Pictures are not logged
- **WHEN** a caller sets and reads an avatar
- **THEN** no log entry contains the picture's bytes
