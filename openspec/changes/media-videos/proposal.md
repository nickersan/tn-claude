# Proposal

## Why
okayat's `post-videos` (okayat-platform `openspec/changes/post-videos`, agreed 2026-11-26) lets a post carry a video. tn-media-service
holds every picture okayat shows and is the only place its bytes are judged, cleaned and served, so video belongs here too. Its item
status was left with room for it (`PROCESSING`).

Three things the service does today assume a picture:
- **An upload is one request held in memory.** A minute of phone video is 50 to 350 MB, and the edge okayat chose (`edge-caller-address`,
  a Cloudflare Tunnel) refuses a body over 100 MB.
- **Cleaning is decoding pixels.** A video's location, device and time sit in its container and stream metadata; only a re-encode
  removes them all, and that takes seconds to a minute, not milliseconds.
- **Serving is the whole item at once.** Players need byte ranges to start, seek and stream; iOS Safari will not play without them.

## What Changes
- **A profile can be a video profile** (`kind: video`), with a byte limit, a longest duration, a part size and its own hourly limit.
- **A video is uploaded in parts:** start an upload with its size, put its parts (each at most the part size), then complete it. The
  parts go straight to object storage as a multipart upload; no part is held whole in memory, and a part that fails is sent again.
  An upload not completed within a day is abandoned and its parts deleted.
- **A completed upload is made ready in the background:** it is probed (a video, no longer than the profile allows), re-encoded to
  H.264/AAC MP4 at most 1280 pixels on its longer side with **no metadata**, its index moved to the front so playback can start early,
  and a still frame taken from it as a JPEG. The item goes `UPLOADING` → `PROCESSING` → `READY`, or `FAILED` with a reason. The upload
  itself is then deleted.
- **A video item says its shape and length:** width, height and duration, once ready.
- **Content is served in byte ranges** (`Range` → 206), streamed from storage, for videos and pictures alike; a video's still frame is
  served at `/v1/media/{id}/poster`.
- **Deleting or removing a video** deletes its parts, video and still frame.
- **The image carries ffmpeg.**
- Pictures are untouched: the single-request upload, its limits and its responses stay as they are, so a consumer that sends pictures
  sees no change.

## Capabilities
### New Capabilities
- `tn-media-service`: written now for the video it adds, as the config asks (backfill when changed). Pictures' existing behaviour is
  summarised in its purpose, not respecified.

### Modified Capabilities
None.

## Impact
- **tn-media-service**: profile kind and limits; the upload, parts and complete endpoints; a transcode worker with a lease on each item
  so a restart or a second replica neither loses nor repeats one; ranged, streamed content; the poster endpoint; migrations that only
  add (`kind`, `width`, `height`, `duration_ms`, `failure`, lease columns, an uploads table); ffmpeg in the Dockerfile; contracts for
  okayat-bff's calls. A minor release (0.x+1), backward compatible.
- **Build and CI**: integration tests need `ffmpeg` and `ffprobe` on the path (installed in CI; on Windows from a package manager).
- **catalog.yaml**: a requested change on tn-media-service from okayat post-videos.
- **Consumers**: okayat (okayat-bff, okayat-admin-bff through okayat-kustomize's profile) in its own changes. Nothing else uses the
  service.
