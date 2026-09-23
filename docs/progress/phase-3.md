# Phase 3 — Swift realtime

In progress, 2026-09-23.

## Completed work

- Listen v1/v2 WebSocket streams with generated message models, typed event dispatch, unknown/malformed event handling, bounded buffering, send ordering, cancellation checks and explicit close.
- Speak v1 streaming with binary audio, generated metadata/control models, and ordered text/control sends.
- Optional AVFoundation microphone capture in the CLI; core transport has no microphone dependency.
- Initial Voice Agent client with Welcome → Settings → SettingsApplied ordering and a timeout. Agent session replay is deliberately absent.

## Checks run

- Swift packages build locally with Command Line Tools.
- macOS CI passed offline Listen, Speak, Agent handshake, reconnect and REST tests at commit `a44de7d`.

## Known deficiencies

- No credential-backed streaming test has run yet.
- Agent provider combinations and function call responses need broader contract coverage. The initial Agent client is experimental.
- No SwiftUI showcase; the CLI is the current demo.
- The current reconnect policy retries only before user payload is sent. This prevents unsafe replay but requires callers to start a new session after interruption.

## Next phase

Run protected live protocol tests when a credential is available, and refine the public API from that evidence.
