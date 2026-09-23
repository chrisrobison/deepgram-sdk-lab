# Architecture

## Source and generation lifecycle

The upstream [Deepgram specification mirror](https://github.com/deepgram/deepgram-api-specs) supplies OpenAPI and AsyncAPI. [source.json](specs/source.json) pins one immutable commit and the SHA-256 of each vendored file. Normal builds never fetch upstream. `tools/update-spec` requires a full commit SHA; `tools/validate-spec` checks the local snapshot. Review protocol and API diffs before regenerating.

Phase 2 will introduce deterministic language generators. Their output will live only in `sdks/<language>/.../Generated` and will carry a generated marker and source commit. Regeneration may replace that directory. It must never edit runtime, examples, tests, or user-facing documentation. CI will regenerate and reject drift once the generators exist.

The generator will select schema and operation nodes needed by implemented capabilities. A full intermediate representation is deferred; its complexity is justified only if Swift and PHP generators otherwise duplicate meaningful normalization work. A small selection manifest can map capabilities to spec nodes without inventing an alternate API specification.

## Runtime boundary

Generated: schema-derived request/response/event models, enums, coding keys, endpoint metadata, and wire error fields. Handwritten: API key authentication, HTTP requests, WebSocket connection state and cleanup, cancellation, retries, reconnects, streaming, logging hooks, convenience methods, and platform-specific audio capture. Public APIs should present language-native usage and hide generated type sprawl where possible.

Swift will use Foundation, URLSession, Codable, actors and AsyncSequence as appropriate. Swift's microphone helper will be a separate optional example/component. PHP will target 8.2+, use strict types and Composer, and keep REST independent of a framework. PHP's realtime dependency will be selected after protocol requirements are tested.

## Parity and testing

[features.yaml](parity/features.yaml) records claims independently of generated source. [Parity rules](parity/README.md) define status semantics. Shared wire fixtures will exercise both languages for JSON, query parameters, authentication, error parsing and event decoding. Language-specific tests will cover transport and lifecycle. Live tests will require `DEEPGRAM_API_KEY` and an explicit opt-in. Pull request CI will run offline.

## Releases and another language

For the 0.x lab, the repository uses coordinated SemVer tags because both SwiftPM and Composer consume the root manifests. [ADR 0002](docs/design-decisions/0002-versioning-and-packaging.md) explains the tradeoff and the option to split releases later. The pinned spec commit remains separate generated metadata. `tools/release-dry-run` validates version and manifest consistency without publication. A third language should consume the same snapshot and fixtures, generate its wire types into an isolated directory, then implement its native runtime and parity tests.
