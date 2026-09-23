# Phase 2 — Swift REST and cross-language proof

In progress, 2026-09-23.

## Completed work

- Added deterministic selected-schema generators for Swift and PHP and generated model directories with source-commit headers.
- Built Swift REST authentication, prerecorded transcription, TTS v1, error context, user agent, retries, and a CLI.
- Built PHP REST authentication, prerecorded transcription, TTS v1, configurable cURL transport, and typed generated models.
- Added a shared prerecorded JSON fixture with both language test suites and opt-in live smoke tests.
- Changed file transcription to stream from disk in both transports; a local HTTP server contract verifies PHP's cURL POST body and headers.
- Added a Swift Listen v1/v2 and Speak v1 WebSocket runtime and microphone CLI as early Phase 3 work.

## Checks run

- `DEVELOPER_DIR=/Library/Developer/CommandLineTools swift build`: passed, including the CLI.
- `php sdks/php/tests/run.php`: passed.
- `./tools/check-generated`: passed, no generated drift.
- `python3 tests/contract/http_upload.py`: passed against a local server.
- PHP source files pass `php -l`.
- The GitHub macOS CI run passed Swift offline REST and Listen WebSocket tests (6 passed, 1 opt-in live test skipped). Local `swift test` is blocked because Xcode 27's license has not been accepted; `sudo xcodebuild -license accept` needs an interactive administrator password.

## Known deficiencies

- No live call has been made with a Deepgram credential. No feature is marked supported in parity.
- Swift Speak WebSocket tests are awaiting the next CI run.
- PHP has no realtime transport.
- Voice Agent, stronger SwiftUI showcase, and release tooling remain to be built.

## Next phase

Run Swift XCTest, resolve any lifecycle issues, complete TTS streaming and connection behavior, then refine the realtime example and advance feature claims based on evidence.
