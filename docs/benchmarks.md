# Offline performance baseline

Measured 2026-09-23 on the local Apple Silicon development machine with Swift 6.3.3 Command Line Tools and PHP 8.5.10. Run `DEVELOPER_DIR=/Library/Developer/CommandLineTools ./tools/benchmark 10000` to repeat locally. The benchmark uses [one shared prerecorded response fixture](../tests/fixtures/prerecorded-response.json) and no Deepgram API calls.

| Operation | Baseline | Notes |
| --- | ---: | --- |
| Swift `JSONDecoder` to generated `ListenV1Response` | 54,334 decodes/s | 10,000 decodes in 0.1840 s in a release executable; first wall run spent ~21 s building. |
| PHP `fromArray` on already parsed JSON | 359,285 conversions/s | 10,000 conversions in 0.0278 s; peak PHP allocation was 2 MiB. JSON parsing is excluded from this number. |
| Full Swift+PHP generation | 0.44 s wall | Includes Python startup and writing output; no network. |

These are developer baselines, not a cross-language speed ranking: Swift measures JSON parsing plus model decoding, while PHP measures model conversion after parsing. A comparable end-to-end decode benchmark and longer WebSocket memory/processing measurements should be added before optimization. The fixture is small and does not model long transcripts or many channels.
