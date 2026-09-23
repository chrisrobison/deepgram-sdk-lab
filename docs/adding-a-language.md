# Adding another language

This guide assumes the repository's pinned spec and shared fixtures remain the source of truth. Ruby, Kotlin, or Dart should follow the same sequence.

1. Read [research](research.md), [architecture](../ARCHITECTURE.md), and [ownership rules](generated-vs-runtime.md). Check the current [spec pin](../specs/source.json) and inspect the relevant Deepgram reference pages. Record any spec/doc mismatch.
2. Add `generators/<language>/generate.*` and a `tools/generate <language>` route. Read only local `specs/upstream` files. Select implemented schemas and operations deliberately. Write output only under `sdks/<language>/.../Generated/`. Stamp the spec commit, use stable sorting, and fail on unsupported schema constructs. Run generation twice and confirm no diff.
3. Build a minimal native runtime around the generated wire types: API key auth, a configurable REST transport, request ID preservation, errors, user agent/version, and resource cleanup. Keep simple calls short. Make retries explicit for billable POST requests.
4. Decode [shared fixtures](../tests/fixtures/) and cover URL/query encoding, auth headers, error parsing and binary responses. Add language-specific tests for transport behavior. For WebSockets, test unknown/malformed events, close, send-after-close, cancellation, buffer overflow and interruption. Never silently replay audio after a reconnect.
5. Add a runnable environment-key example and an opt-in credential-backed smoke test. Live tests must require `DEEPGRAM_API_KEY` plus an explicit flag; pull request CI stays offline.
6. Add capability statuses to [parity/features.yaml](../parity/features.yaml). Start at `planned`, then update only when the [status definition](../parity/README.md) is met. Run `./tools/parity` to update the README.
7. Add a CI job for generation drift, build/lint, offline contracts, and package validation. Document installation from the repository and dry-run release steps. Revisit the [coordinated versioning decision](design-decisions/0002-versioning-and-packaging.md) if the new language cannot use a root manifest.

The third generator is a useful test of whether the current direct-spec approach has become repetitive. If two language generators repeat the same schema normalization logic, introduce a small normalized model with fixture tests. Keep transport and lifecycle code native even if a fuller generator is later adopted.
