# tn-notification-service Specification

## Purpose
Dispatches a message to an email address or a phone number, behind one
interface, so consuming services never integrate with an SMS/email provider
directly.

## Requirements

### Requirement: Dispatch a message to an identifier
The system SHALL accept a message and an identifier (email address or phone
number) and SHALL deliver that message through the channel matching the
identifier's type.

#### Scenario: Dispatch to an email address
- **WHEN** a caller submits a message and an email-address identifier
- **THEN** the system delivers the message by email to that address

#### Scenario: Dispatch to a phone number
- **WHEN** a caller submits a message and a phone-number identifier
- **THEN** the system delivers the message by SMS to that number

### Requirement: Channel choice is not the caller's concern
The system SHALL determine the delivery channel (email or SMS) from the
identifier's type; it SHALL NOT require the caller to name a provider or
channel-specific API.

#### Scenario: Caller does not specify a channel
- **WHEN** a caller submits a message and an identifier without naming a delivery
  channel or provider
- **THEN** the system still delivers the message via the channel matching the
  identifier's type

### Requirement: Dispatch failure is reported, not swallowed
The system SHALL report a delivery failure to the caller rather than silently
discarding it.

#### Scenario: Underlying provider is unavailable
- **WHEN** the provider for the identifier's channel is unavailable or returns an
  error
- **THEN** the system reports the failure to the caller instead of indicating
  success

### Requirement: Structured, masked logging — message content never appears
The system SHALL log dispatch attempts as structured (JSON) log entries, per
`tn-claude/standards/logging/README.md`, and SHALL NOT log the message content or
the full identifier value unmasked. This is the highest-value place in the layer to
get masking right: the message content dispatched through this service is routinely
a one-time passcode, and a passcode leaked into a log is a direct account-takeover
path.

#### Scenario: A dispatch is logged without leaking the message
- **WHEN** the system dispatches a message to an identifier
- **THEN** it emits a structured log entry describing the attempt and its outcome,
  and that entry does not contain the message content or the unmasked identifier
  value
