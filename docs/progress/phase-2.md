# Phase 2 — Swift REST and cross-language proof

In progress, 2026-09-23.

## Completed work

- Added deterministic selected-schema generators for Swift and PHP and generated model directories with source-commit headers.
- Built Swift REST authentication, prerecorded transcription, TTS v1, error context, user agent, retries, and a CLI.
- Built PHP REST authentication, prerecorded transcription, TTS v1, configurable cURL transport, and typed generated models.
- Added a shared prerecorded JSON fixture with both language test suites and opt-in live smoke tests.
- Added a Swift Listen v1/v2 WebSocket runtime and microphone CLI as early Phase 3 work.

## Checks run

- `DEVELOPER_DIR=/Library/Developer/CommandLineTools swift build`: passed, including the CLI.
- `php sdks/php/tests/run.php`: passed.
- `./tools/check-generated`: passed, no generated drift.
- PHP source files pass `php -l`.
- `swift test` is blocked locally because Xcode 27's license has not been accepted; `sudo xcodebuild -license accept` needs an interactive administrator password. The macOS CI test job is configured.

## Known deficiencies

- No live call has been made with a Deepgram credential. No feature is marked supported in parity.
- Swift realtime lifecycle tests are written but have not run locally yet.
- PHP currently buffers local audio files in memory and has no realtime transport.
- Swift TTS streaming, Voice Agent, stronger SwiftUI showcase, and release tooling remain to be built.

## Next phase

Run Swift XCTest, resolve any lifecycle issues, complete TTS streaming and connection behavior, then refine the realtime example and advance feature claims based on evidence.
