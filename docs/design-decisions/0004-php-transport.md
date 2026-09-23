# ADR 0004: Small PHP REST transport

Status: accepted for the PHP preview, 2026-09-23.

PHP uses ext-curl and a small configurable `Transport` interface. A PSR HTTP abstraction would still require a concrete implementation and add dependency/setup friction for the first call. The interface permits an application's existing transport without forcing a framework. `FileBody` streams large prerecorded audio through cURL.

The current PHP package does not claim realtime support. A maintained WebSocket dependency should be selected only after a protocol test matrix defines handshake headers, binary frames, cancellation, timeouts and close behavior. A handwritten socket implementation is not justified by dependency minimization alone.
