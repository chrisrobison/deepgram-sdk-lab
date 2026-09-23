# ADR 0004: Small PHP REST transport

Status: accepted for the PHP preview, 2026-09-23.

PHP uses ext-curl and a small configurable `Transport` interface. A PSR HTTP abstraction would still require a concrete implementation and add dependency/setup friction for the first call. The interface permits an application's existing transport without forcing a framework. `FileBody` streams large prerecorded audio through cURL.

For blocking realtime usage, the optional adapter uses [phrity/websocket 3.8](https://github.com/sirn-se/websocket-php), a maintained client that handles handshake, masking, fragmentation and close frames. It is suggested rather than required so REST installs stay small. The adapter is a development dependency for CI. An independent local RFC 6455 server contract verifies auth headers, binary audio frames, typed receive and close. There is no automatic replay after audio is sent.
