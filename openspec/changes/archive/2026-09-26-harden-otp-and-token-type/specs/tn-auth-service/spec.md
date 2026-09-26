## ADDED Requirements

### Requirement: Every token states whether it is an access or a refresh token
The system SHALL include a `token_use` claim in every token it issues, with the
value `access` for an access token and `refresh` for a refresh token, so that a
service verifying a token can reject the wrong kind. The claim is this service's
own; a caller cannot supply or influence it.

#### Scenario: Token pair carries both types
- **WHEN** the system issues a token pair
- **THEN** the access token's `token_use` claim is `access` and the refresh
  token's `token_use` claim is `refresh`

#### Scenario: A refreshed access token is an access token
- **WHEN** the system issues a new access token for a valid refresh token
- **THEN** the new access token's `token_use` claim is `access`

#### Scenario: Refresh rejects a token that is not a refresh token
- **WHEN** a caller presents an access token, or any validly signed token whose
  `token_use` claim is not `refresh`, as a refresh token
- **THEN** the system rejects the request and does not issue a new access token

## MODIFIED Requirements

### Requirement: The system does not accept caller-supplied claims
The system SHALL accept only a subject id from the caller; every other claim
in the issued tokens is this service's own to determine, not the caller's.

#### Scenario: A caller cannot influence any claim beyond the subject
- **WHEN** a caller requests a token pair for a subject id
- **THEN** the issued tokens carry only this service's own claims (issuer,
  issued-at, expiration, a token id, and the token type) alongside that
  subject — nothing the caller supplied beyond the id itself
