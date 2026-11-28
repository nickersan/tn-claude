# Spec Delta

## Purpose
tn-media-service owns media items for the projects above it: their bytes in an S3-compatible store and what is known about each in
PostgreSQL. An item is owned by a user, accepted under a named profile whose limits apply to it, judged by its contents, kept with
nothing but what it shows, never changed once ready and never reused. Pictures (JPEG, PNG) are uploaded in one request, re-encoded from
their pixels and ready at once. The consuming project's BFF is the gate: the service has no authentication of its own.

## ADDED Requirements

### Requirement: A video is uploaded in parts
The system SHALL accept a video under a profile of kind video as an upload started with its size, sent in numbered parts of the
profile's part size (the last the remainder), and completed. It SHALL refuse a part of the wrong size or number and refuse to complete
while a part is missing, and SHALL let a part be sent again.

#### Scenario: Uploading a video in parts
- **WHEN** a video of 20 MB is started under a video profile with 8 MB parts, its 3 parts are sent and it is completed
- **THEN** its item is processing, owned by the owner given, under that profile

#### Scenario: A failed part sent again
- **WHEN** the second part of an upload is sent twice before it is completed
- **THEN** the upload completes and the video is as uploaded

#### Scenario: Completing with a part missing
- **WHEN** an upload of 3 parts is completed after only 2 were sent
- **THEN** it is refused and the upload can still be finished

### Requirement: A video upload is limited
The system SHALL refuse to start an upload larger than the profile allows, past the owner's limit for that profile in its window, or of
the wrong kind for the profile. An upload not completed within its expiry SHALL be abandoned and its parts deleted.

#### Scenario: Too large to start
- **WHEN** an upload is started with a size over the profile's limit
- **THEN** it is refused and no item is made

#### Scenario: An upload never completed
- **WHEN** an upload is not completed within its expiry
- **THEN** its item is failed as abandoned and its parts are no longer stored

#### Scenario: Too many videos in a window
- **WHEN** an owner has started as many uploads as the profile allows in its window and starts another
- **THEN** it is refused as too many, and their uploads under other profiles are unaffected

#### Scenario: The wrong kind for the profile
- **WHEN** a picture is uploaded in one request under a video profile
- **THEN** it is refused, and so is an upload in parts under a picture profile

### Requirement: A video keeps nothing but picture and sound
The system SHALL store a completed video re-encoded as H.264 and AAC in MP4, upright, at most the profile's size on its longer side,
with its index at the start and none of the original's metadata (location, device, creation time, rotation), and a still frame from it
as a JPEG with no metadata. A ready video SHALL say its width, height and duration. The original upload SHALL then no longer be stored.

#### Scenario: A phone video's location is not kept
- **WHEN** a video recording where and when it was taken, on which phone, is uploaded and made ready
- **THEN** the stored video and its still frame record none of these

#### Scenario: A video's shape and length
- **WHEN** a 5 second video shot at 1920 by 1080 is made ready under a profile of 1280
- **THEN** it is 1280 by 720, says so, and says it lasts 5 seconds

#### Scenario: A sideways phone video
- **WHEN** a video recorded with the phone upright is made ready
- **THEN** the stored video is taller than wide, with no rotation to apply

### Requirement: A video is made ready in the background
The system SHALL make a completed video ready after completing it, refusing one that is not a video or is longer than the profile
allows, and saying why it failed. Processing SHALL survive a restart of the service.

#### Scenario: Not a video
- **WHEN** a file that is not a video is uploaded in parts and completed
- **THEN** its item fails as not a video, and nothing of it is served

#### Scenario: Too long
- **WHEN** a video longer than the profile allows is uploaded and completed
- **THEN** its item fails as too long

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

#### Scenario: A video's still frame
- **WHEN** a ready video's still frame is asked for
- **THEN** a JPEG of the video's size is served

#### Scenario: Not ready yet
- **WHEN** the content of a video still processing is asked for
- **THEN** there is none

### Requirement: A video goes with its item
The system SHALL, on deleting a video item, delete its parts, video and still frame, and on removing one by staff delete the same and
keep the record as removed. A video deleted or removed while being processed SHALL not be made ready.

#### Scenario: Removed while processing
- **WHEN** staff remove a video while it is being made ready
- **THEN** it stays removed and nothing of it is stored
