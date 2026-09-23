# Phase 3 — Swift realtime

In progress, 2026-09-23.

## Completed work

- Listen v1/v2 WebSocket streams with generated message models, typed event dispatch, unknown/malformed event handling, bounded buffering, send ordering, cancellation checks and explicit close.
- Speak v1 streaming with binary audio, generated metadata/control models, and ordered text/control sends.
- Optional AVFoundation microphone capture in the CLI; core transport has no microphone dependency.
- Initial Voice Agent client with Welcome → Settings → SettingsApplied ordering and a timeout. Agent session replay is deliberately absent.

## Checks run

- Swift packages build locally with Command Line Tools.
- macOS CI passed offline Listen, Speak and REST tests before the latest Agent and reconnect tests were added. A new CI run will check those changes.

## Known deficiencies

- No credential-backed streaming test has run yet.
- Agent provider combinations and function call responses need broader contract coverage. The initial Agent client is not yet a parity claim.
- No SwiftUI showcase; the CLI is the current demo.
- The current reconnect policy retries only before user payload is sent. This prevents unsafe replay but requires callers to start a new session after interruption.

## Next phase

Verify the new Agent/reconnect tests in macOS CI, run protected live protocol tests when a credential is available, and refine the public API from that evidence.
