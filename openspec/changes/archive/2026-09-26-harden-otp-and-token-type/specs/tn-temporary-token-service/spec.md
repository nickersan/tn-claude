## ADDED Requirements

### Requirement: Token generation is limited per owner
The system SHALL limit how many tokens may be generated for one owner within a
configured time window, across every instance of the service. A generate request
over the limit SHALL be rejected without generating a token and without changing
or removing the owner's existing token.

#### Scenario: Generation within the limit
- **WHEN** a caller generates tokens for an owner no more often than the limit
  allows within the window
- **THEN** each request returns a new token, as before

#### Scenario: Generation over the limit is rejected
- **WHEN** a caller generates more tokens for an owner than the limit allows within
  the window
- **THEN** the system rejects the additional request with a "too many requests"
  response, generates no token, and the owner's most recent token remains
  verifiable

#### Scenario: The limit applies per owner
- **WHEN** one owner has reached the limit and a caller generates a token for a
  different owner
- **THEN** the system generates the token for the other owner

#### Scenario: Generation is allowed again once the window has passed
- **WHEN** an owner reached the limit and the window has since elapsed for their
  earlier requests
- **THEN** the system generates a new token for that owner

#### Scenario: Concurrent requests do not exceed the limit
- **WHEN** more generate requests for the same owner than the limit allows arrive
  at the same time, at any instances of the service
- **THEN** the system generates at most as many tokens as the limit allows and
  rejects the rest

### Requirement: Failed verification attempts are limited per token
The system SHALL count failed verification attempts against an owner's most
recently generated token, and once the count reaches a configured limit SHALL
invalidate that token, so that no value — including the correct one — verifies
until a new token is generated. Failed attempts SHALL NOT be reported differently
from any other invalid verification.

#### Scenario: A correct value within the limit verifies
- **WHEN** a caller submits fewer incorrect values than the limit and then the
  correct value, before the token expires
- **THEN** the system reports the correct value as valid

#### Scenario: Reaching the limit invalidates the token
- **WHEN** a caller submits as many incorrect values for an owner's token as the
  limit allows, then submits the correct value
- **THEN** the system reports the correct value as invalid

#### Scenario: A new token starts a fresh count
- **WHEN** an owner's token was invalidated by reaching the limit and a new token is
  then generated for that owner
- **THEN** the new token's correct value verifies as valid

#### Scenario: Concurrent failed attempts are all counted
- **WHEN** several incorrect values for the same owner's token are submitted at the
  same time, at any instances of the service
- **THEN** every one of them counts towards the limit
