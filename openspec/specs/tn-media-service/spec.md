# tn-media-service Specification

## Purpose
tn-media-service owns media items for the projects above it: their bytes in an S3-compatible store and what is known about each in
PostgreSQL. An item is owned by a user, accepted under a named profile whose limits apply to it, judged by its contents, kept with
nothing but what it shows, never changed once ready and never reused. Pictures (JPEG, PNG) are uploaded in one request, re-encoded from
their pixels and ready at once. The consuming project's BFF is the gate: the service has no authentication of its own.

Videos (since 0.7.0, requested by okayat post-videos) come under a profile of kind video and differ from pictures in three ways, each for
a reason:
- **Uploaded in parts.** An edge in front of a consumer refuses bodies over about 100 MB, and a phone that drops its connection would
  lose a whole upload. Pre-signed URLs straight to the store were rejected because the BFF would stop being the gate and the store would
  need a public address; tus and the like because S3's own multipart upload does the same with no new dependency on either end.
- **Re-encoded, never kept as sent.** A phone's video records where, when and on which device it was taken; the original is the thing
  that holds this, so it is deleted once a clean copy is stored. The copy is one H.264/AAC MP4 rendition with its index first, which
  every browser and phone can stream and seek. Adaptive streaming, several renditions, trimming and hardware encoding are out of scope.
- **Made ready in the background.** Encoding takes about as long as the video on one core, so a request cannot wait for it. The items
  table is the queue: a replica leases an item, one that dies leaves the lease to run out for another, and a video removed or deleted
  meanwhile is not made ready. ffmpeg is run as a separate program, not linked in, which keeps the service's own licence apart from
  libx264's GPL.

Byte ranges are served for every item, so a video can be streamed and seeked through the consumer's BFF without either side holding it
whole; callers that send no range see no change.

## Requirements

### Requirement: A video is uploaded in parts
The system SHALL accept a video under a profile of kind video as an upload started with its size, sent in numbered parts of the
profile's part size (the last the remainder), and completed. It SHALL refuse a part of the wrong size or number and refuse to complete
while a part is missing, and SHALL let a part be sent again.

#### Scenario: A failed part sent again
- **WHEN** the second part of an upload is sent twice before it is completed
- **THEN** the upload completes and the video is as uploaded

### Requirement: A video upload is limited
The system SHALL refuse to start an upload larger than the profile allows, past the owner's limit for that profile in its window, or of
the wrong kind for the profile. An upload not completed within its expiry SHALL be abandoned and its parts deleted.

#### Scenario: Too many videos in a window
- **WHEN** an owner has started as many uploads as the profile allows in its window and starts another
- **THEN** it is refused as too many, and their uploads under other profiles are unaffected

### Requirement: A video keeps nothing but picture and sound
The system SHALL store a completed video re-encoded as H.264 and AAC in MP4, upright, at most the profile's size on its longer side,
with its index at the start and none of the original's metadata (location, device, creation time, rotation), and a still frame from it
as a JPEG with no metadata. A ready video SHALL say its width, height and duration. The original upload SHALL then no longer be stored.

#### Scenario: A phone video's location is not kept
- **WHEN** a video recording where and when it was taken, on which phone, is uploaded and made ready
- **THEN** the stored video and its still frame record none of these

#### Scenario: A sideways phone video
- **WHEN** a video recorded with the phone upright is made ready
- **THEN** the stored video is taller than wide, with no rotation to apply

### Requirement: A video is made ready in the background
The system SHALL make a completed video ready after completing it, refusing one that is not a video or is longer than the profile
allows, and saying why it failed. Processing SHALL survive a restart of the service.

#### Scenario: Restarted while processing
- **WHEN** the service stops while making a video ready and starts again
- **THEN** the video is made ready once

### Requirement: Media is served in ranges
The system SHALL serve an item's content whole, or the single byte range asked for with its place in the whole, streamed from storage,
and refuse a range that cannot be satisfied. It SHALL serve a ready video's still frame. It SHALL serve nothing of an item that is not
ready, removed or deleted.

#### Scenario: Seeking in a video
- **WHEN** the bytes from the middle to the end of a ready video are asked for
- **THEN** just those bytes are served, saying where they sit in the whole

### Requirement: A video goes with its item
The system SHALL, on deleting a video item, delete its parts, video and still frame, and on removing one by staff delete the same and
keep the record as removed. A video deleted or removed while being processed SHALL not be made ready.

#### Scenario: Removed while processing
- **WHEN** staff remove a video while it is being made ready
- **THEN** it stays removed and nothing of it is stored
