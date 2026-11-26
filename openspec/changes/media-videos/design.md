# Design

## Context
tn-media-service keeps items in Postgres (`media_item`: owner, kind `IMAGE`, status, content type, size, profile) and their bytes in an
S3-compatible store under the item id (`S3MediaStore`). `POST /v1/media?profile=&owner=` reads the whole body, `ImageProcessor` checks
and re-encodes it, and the item is `READY` at once. `GET /v1/media/{id}/content` answers the bytes as one `byte[]`. Profiles
(`MediaProperties.Profile`) set `max-bytes`, `max-dimension` and, since post-pictures, their own upload limit and window. The image is
`eclipse-temurin:25-jdk-alpine`. Its one consumer, okayat-bff (and okayat-admin-bff for staff), is the gate; the service has no
authentication of its own.

## Goals / Non-Goals

**Goals:** videos of up to a few hundred MB uploaded through a 100 MB-per-request edge; nothing but picture and sound kept; served so
browsers and phones can stream and seek; no change for pictures or for consumers that only send pictures.

**Non-Goals:** adaptive streaming (HLS/DASH) or several renditions; trimming or editing; a CDN; deleting items no consumer uses
(as for pictures, a separate follow-up); hardware encoding.

## Decisions

### 1. A profile has a kind
`Profile` gains `kind` (`image` by default, so existing configuration means the same), and for `video`: `max-bytes` (the upload),
`max-duration`, `part-size` (default 8 MB), `max-dimension` (the longer side of what is stored, default 1280). The hourly limit and
window work as for pictures, counted when an upload starts. A picture upload to a video profile, or the reverse, is refused (400).

### 2. Uploaded in parts, as an S3 multipart upload
- `POST /v1/media/uploads?profile=&owner=&size=` → 201 `{id, partSize, parts}`: refuses a size over the profile's `max-bytes` (400) and
  an owner over the limit (429); creates the item (`kind VIDEO`, `UPLOADING`) and an S3 multipart upload at `uploads/{id}`, its upload id
  kept in an `upload` row.
- `PUT /v1/media/{id}/parts/{n}` (1-based, body the part, `Content-Length` required) → 204: every part but the last exactly `partSize`,
  the last the remainder, so the parts can only add up to the declared size. The body is streamed to S3 `UploadPart`, never held whole.
  A part sent again replaces itself, so a client retries a failed part without starting over.
- `POST /v1/media/{id}/actions/complete` → 202, the item `PROCESSING`: refuses (409) while a part is missing; completes the multipart
  upload.
- An item still `UPLOADING` a day after it started (`upload-expiry`) is abandoned by a scheduled sweep: the multipart upload aborted,
  the item `FAILED` (`ABANDONED`).
- *Rejected: one streamed request.* The edge refuses bodies over 100 MB, and a dropped connection on a phone loses everything sent.
- *Rejected: pre-signed URLs straight to the store.* The consumer's BFF would stop being the gate on what is sent, the store would need
  a public address, and every consumer would need storage-specific client code.
- *Rejected: tus or another resumable protocol.* Another dependency on both ends for what three endpoints and S3's own multipart do.

### 3. Made ready by a worker with a lease
Items `PROCESSING` are claimed with `SELECT … FOR UPDATE SKIP LOCKED`, setting `lease_until` (now + `transcode-timeout`, default 10 min)
and counting `attempts`. At most `max-concurrent-transcodes` (default 1) run in a replica. A replica that dies leaves the lease to run
out, and another (or itself, restarted) claims the item again. After 3 attempts it is `FAILED` (`UNREADABLE`). This needs no queue: the
table is the queue, and one replica or several behave the same.

For each item the worker downloads `uploads/{id}` to a work directory (`work-dir`, an `emptyDir` in Kubernetes) and:
1. **Probes** it with `ffprobe`: refused as `FAILED` with `NOT_A_VIDEO` without a video stream, `TOO_LONG` over `max-duration`. A
   container ffprobe cannot read is `NOT_A_VIDEO`.
2. **Re-encodes** with ffmpeg:
   `-map 0:v:0 -map 0:a:0? -map_metadata -1 -map_metadata:s -1 -map_chapters -1 -sn -dn`
   `-vf scale=<fit max-dimension, never larger, even sizes> -c:v libx264 -profile:v high -preset veryfast -crf 23 -pix_fmt yuv420p`
   `-c:a aac -b:a 128k -ac 2 -movflags +faststart`. ffmpeg applies a phone's rotation to the pixels, so the stored video is upright and
   carries no rotation tag.
3. **Takes a still frame** at 1 s (or the middle of a shorter video) and stores it through `ImageProcessor`, as a picture is: a JPEG
   with no metadata, at the video's size.
4. Stores the video at `{id}` (`video/mp4`) and the frame at `{id}/poster`, sets `width`, `height`, `duration_ms`, `size_bytes` and
   `READY`, and deletes `uploads/{id}`.
ffmpeg runs as a process with a timeout; its output is logged at debug and its last lines on failure.
- *Rejected: keeping the original.* It holds the metadata this exists to drop.
- *Rejected: a separate transcoder service or a managed one.* One more deployment for a feature of this one; revisit if encoding needs
  its own scaling.

### 4. No metadata, checked by test
Global, stream and chapter metadata are dropped and data and subtitle streams left out, which covers QuickTime's
`com.apple.quicktime.location.ISO6709`, `©xyz` and Android's `location` tags. The integration test probes the stored video for any
tag beyond those ffmpeg writes (`major_brand`, `encoder` and the like are allowed; `location`, `creation_time`, `make`, `model` are not).

### 5. Served in ranges, streamed
`GET /v1/media/{id}/content` honours a single `Range: bytes=a-b` (or `a-`, or `-n`) with 206 and `Content-Range`, and says
`Accept-Ranges: bytes`; without one it answers 200 with the whole item. Either way the body streams from S3's ranged `GetObject`
(`StreamingResponseBody`), so a 150 MB video costs no memory. A range that cannot be satisfied is 416. Pictures get the same, which
changes nothing for callers that send no `Range`. `ETag` is the item id, as it never changes.
`GET /v1/media/{id}/poster` answers the still frame (`image/jpeg`); 404 for a picture or a video not ready.

### 6. The item says more
`MediaItem` gains `width`, `height`, `durationMs` (videos once ready) and `failure` (`NOT_A_VIDEO`, `TOO_LONG`, `UNREADABLE`,
`ABANDONED`); status gains `UPLOADING` and `FAILED`, kind gains `VIDEO`. Consumers that read status as "`READY` or not" are unaffected.

### 7. Deleting and removing
Delete removes the item, any multipart upload, `uploads/{id}`, `{id}` and `{id}/poster`. Staff removal deletes the same bytes and keeps
the record `REMOVED`, as for pictures. A removed or deleted item being processed is not made ready: the worker checks the status before
storing.

### 8. ffmpeg in the image, and in the build
`apk add --no-cache ffmpeg` in the Dockerfile (Alpine's build includes libx264). The service checks for `ffmpeg` and `ffprobe` at
start-up when any video profile is configured, and fails fast without them. Integration tests run ffmpeg for real: CI installs it, and
the README says how locally. Test fixtures are small checked-in clips (a few seconds, under 200 KB) carrying a location, a creation time
and a rotation; one longer clip for `TOO_LONG` is made by the test with ffmpeg's `testsrc`, not checked in.

### 9. Contracts first
The contracts okayat-bff's video slice will call are written before the code: start, part, complete, get (uploading, processing, ready,
failed), content with and without a range, poster, and the refusals (too large, wrong kind, too many, missing parts). Every change is
additive, so the released okayat-bff and okayat-admin-bff keep working against this release.

## Risks / Trade-offs
- [Encoding is CPU-heavy: a minute of 1080p takes about as long again on one core] → one at a time per replica by default; okayat's
  Kustomize gives the service more CPU. The member waits a little longer; nothing else slows.
- [libx264 is GPL, and the image is published] → ffmpeg is a separate program the service runs, not linked into it; the image's
  licences are those of Alpine's packages. Noted in the README.
- [A day of abandoned parts in storage] → bounded by the hourly limit and the profile's size; the sweep deletes them.
- [Range requests multiply calls through the consumer's BFF] → each is small and streamed; the consumer passes `Range` through rather
  than buffering.
