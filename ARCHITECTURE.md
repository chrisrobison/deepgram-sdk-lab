# Architecture

## Source and generation lifecycle

The upstream [Deepgram specification mirror](https://github.com/deepgram/deepgram-api-specs) supplies OpenAPI and AsyncAPI. [source.json](specs/source.json) pins one immutable commit and the SHA-256 of each vendored file. Normal builds never fetch upstream. `tools/update-spec` requires a full commit SHA; `tools/validate-spec` checks the local snapshot. Review protocol and API diffs before regenerating.

Deterministic language generators write only to `sdks/<language>/.../Generated` and mark each file with its source commit. Regeneration may replace those directories. It never edits runtime, examples, tests, or user-facing documentation. CI regenerates and rejects drift with `tools/check-generated`.

Each language generator selects the schema nodes needed by implemented capabilities and emits its own wire models. The generators do not mirror the entire Deepgram specification or share a formal intermediate representation. See [ADR 0001](docs/design-decisions/0001-spec-and-generation.md) for the scope and tradeoff.

## Runtime boundary

Generated: schema-derived request/response/event models, enums, coding keys, endpoint metadata, and wire error fields. Handwritten: API key authentication, HTTP requests, WebSocket connection state and cleanup, cancellation, retries, reconnects, streaming, logging hooks, convenience methods, and platform-specific audio capture. Public APIs should present language-native usage and hide generated type sprawl where possible.

Swift uses Foundation, URLSession, Codable, actors, and AsyncSequence. Its microphone helper lives in a separate optional target. PHP targets 8.2+, uses strict types and Composer, and keeps REST independent of a framework. PHP's optional blocking WebSocket adapter uses phrity/websocket; the REST client does not require that dependency at runtime.

## Parity and testing

[features.yaml](parity/features.yaml) records claims independently of generated source. [Parity rules](parity/README.md) define status semantics. Shared wire fixtures exercise both languages for JSON, query parameters, authentication, error parsing, and event decoding. Language-specific tests cover transport and lifecycle. Live tests require `DEEPGRAM_API_KEY` and an explicit opt-in. Pull request CI runs offline.

An offline [benchmark harness](docs/benchmarks.md) records decode and generator baselines. It is informational, not a CI performance gate; workload definitions must be made comparable before drawing cross-language conclusions.

## Releases and another language

For the 0.x lab, the repository uses coordinated SemVer tags because both SwiftPM and Composer consume the root manifests. [ADR 0002](docs/design-decisions/0002-versioning-and-packaging.md) explains the tradeoff and the option to split releases later. The pinned spec commit remains separate generated metadata. `tools/release-dry-run` validates version and manifest consistency without publication. The manual GitHub Actions release workflow runs all checks in dry-run mode; publication is gated by the `release` environment and explicit workflow input. A third language should consume the same snapshot and fixtures, generate its wire types into an isolated directory, then implement its native runtime and parity tests.
