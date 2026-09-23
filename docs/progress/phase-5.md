# Phase 5 — PHP generalization

In progress, 2026-09-23.

## Completed work

- Generated PHP REST and Listen realtime types from the same pinned specs as Swift.
- Added PHP 8.2+ REST auth, prerecorded STT, TTS v1, errors, request IDs and configurable cURL transport.
- Streamed local file uploads without buffering entire audio files.
- Added optional blocking Listen v1/v2 WebSocket support through phrity/websocket 3.8 and a socket test seam.
- Shared the prerecorded response fixture with Swift and exercised actual cURL and WebSocket adapters against local servers.

## Checks run

- `php sdks/php/tests/run.php`: passed.
- `python3 tests/contract/http_upload.py`: passed.
- `python3 tests/contract/ws_php.py`: passed locally with phrity/websocket 3.8.1.
- PHP syntax checks passed for generated and handwritten source.
- PHP 8.2 CI passed REST and WebSocket contracts at commit `a44de7d`.

## Known deficiencies

- Realtime is blocking and best suited to workers/CLI. A fully async PHP runtime would need a different dependency and public API.
- No credential-backed PHP live test has run. The optional live script includes REST and a Flux handshake.
- Speak streaming and Voice Agent are not implemented in PHP.

## Architectural observation

The same spec closure and numeric-string decoding rule carried across languages. Transport lifecycle did not: Swift actors/AsyncSequence and PHP's blocking iterator require different runtime shapes. Keeping generated models separate from runtime code made this manageable.

## Next phase

Use live credentials to validate the handshake before raising parity claims above experimental.
