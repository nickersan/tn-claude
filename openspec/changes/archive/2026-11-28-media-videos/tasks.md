One slice: tn-media-service. Done when its unit, integration and contract suites are green, its diff is reviewed, it is released, and
okayat's @smoke (web) is green against it (okayat-kustomize picks up the release; no video profile is set yet, so nothing changes).

## 1. Contracts (from what okayat-bff will call)
- [x] 1.1 Start an upload; send a part; complete; get an item uploading, processing, ready (width, height, durationMs) and failed (failure); content with and without `Range`; poster; refusals: too large, wrong kind, too many, missing parts, unsatisfiable range

## 2. Profiles and items
- [x] 2.1 `Profile.kind` (`image` default), `max-duration`, `part-size`; global `max-concurrent-transcodes`, `transcode-timeout`, `upload-expiry`, `work-dir` ("The wrong kind for the profile")
- [x] 2.2 Migration that only adds: `kind VIDEO`, statuses `UPLOADING`/`FAILED`, `width`, `height`, `duration_ms`, `failure`, `lease_until`, `attempts`; an `upload` table (media id, S3 upload id, parts received)

## 3. Upload in parts
- [x] 3.1 `POST /v1/media/uploads`, `PUT /v1/media/{id}/parts/{n}` streamed to S3 `UploadPart`, `POST /v1/media/{id}/actions/complete` ("Uploading a video in parts", "A failed part sent again", "Too large to start", "Completing with a part missing", "Too many videos in a window")
- [x] 3.2 Sweep of uploads past their expiry ("An upload never completed")

## 4. Making ready
- [x] 4.1 Leased claim with `SKIP LOCKED`, attempts, concurrency limit ("Restarted while processing")
- [x] 4.2 ffprobe checks, ffmpeg re-encode, still frame through `ImageProcessor`, store, delete upload ("Not a video", "Too long", "A video's shape and length", "A sideways phone video")
- [x] 4.3 Metadata test over fixtures with location, creation time, make/model and rotation ("A phone video's location is not kept")
- [x] 4.4 Status checked before storing; delete and remove clear every key ("Removed while processing")

## 5. Serving
- [x] 5.1 Ranged, streamed content for all items; 416; `Accept-Ranges`, `ETag` ("Seeking in a video", "Not ready yet")
- [x] 5.2 `GET /v1/media/{id}/poster` ("A video's still frame")

## 6. Image, build and docs
- [x] 6.1 `apk add ffmpeg` in the Dockerfile; start-up check when a video profile is set
- [x] 6.2 CI installs ffmpeg for the integration tests; README: video profiles, endpoints, ffmpeg locally, the GPL note
- [x] 6.3 catalog.yaml: tn-media-service's api and a requested change from okayat post-videos

## 7. Specs
- [x] 7.1 Archive: `specs/tn-media-service/spec.md`; okayat's post-videos design refers to it rather than restating it
