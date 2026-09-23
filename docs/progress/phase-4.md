# Phase 4 — Swift showcase

In progress, 2026-09-23.

## Completed work

- Added a macOS SwiftUI voice playground with connection state, microphone level, transcript, turn event, request ID, errors, and an approximate arrival lag.
- Moved microphone capture into a separate optional SwiftPM target shared by the CLI and playground. The core SDK still has no AVFoundation dependency.
- Kept the example small: one observable session object and one view.

## Checks run

- Root SwiftPM package builds with Command Line Tools on macOS, including both example executables.

## Known deficiencies

- The playground has not been tested against the live API because no `DEEPGRAM_API_KEY` is available locally.
- The lag indicator is a rough arrival estimate, not instrumented end-to-end latency.
- Microphone permission and the visual app have not yet been manually exercised in a signed Xcode bundle.

## Developer experience review

The example uses `Deepgram(apiKey:)`, `listen.v2.connect`, `send`, and `events` directly. Capture is a separate opt-in module, so applications can supply their own audio source. A future release should verify microphone permissions and stop behavior in a real app bundle before advertising the showcase as production-ready.
