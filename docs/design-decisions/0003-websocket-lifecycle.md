# ADR 0003: Native WebSocket lifecycle and safe reconnect

Status: accepted for the Swift preview, 2026-09-23.

Swift uses URLSessionWebSocketTask behind one small transport seam. Listen and Speak actors own state, send ordering, bounded event streams, protocol controls and cancellation. Generated models decode message payloads; runtime code dispatches by event type and surfaces unknown/malformed events. Audio capture remains in the CLI example.

URLSession delegate callbacks confirm the open handshake with a timeout. Sends are chained because actors are reentrant while awaiting network I/O. Receive buffering is bounded; overflow terminates with an error instead of silently losing events.

Automatic reconnect is allowed only before application audio/text has been sent. Replaying audio or text after a network break could duplicate billable work or corrupt turn boundaries. After payload submission, an interruption is surfaced to the caller. Future resumable protocols could justify a different policy, but no replay guarantee is documented today.
