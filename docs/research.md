# Deepgram SDK platform research

Research date: 2026-09-23. This is an independent compatibility project, not a Deepgram SDK. API details below are observations from the linked public sources, not promises of future support.

## Source inventory

| Source | Observation |
| --- | --- |
| [API reference](https://developers.deepgram.com/reference) | The product reference is the behavioral authority when the machine-readable files are ambiguous. |
| [Public specification mirror](https://github.com/deepgram/deepgram-api-specs) | Mirrors the docs' OpenAPI and AsyncAPI files hourly. The mirror says external PRs are not accepted. Its specifications are licensed [CC BY 4.0](https://github.com/deepgram/deepgram-api-specs/blob/main/LICENSE). |
| [OpenAPI](https://github.com/deepgram/deepgram-api-specs/blob/main/openapi.yml) | OpenAPI 3.1.0; contains `POST /v1/listen`, `POST /v1/speak`, and `POST /v2/speak`. The latter is a newer Flux TTS batch surface. |
| [AsyncAPI](https://github.com/deepgram/deepgram-api-specs/blob/main/asyncapi.yml) | AsyncAPI 2.6.0; contains `/v1/listen`, `/v2/listen`, `/v1/speak`, `/v2/speak`, and `/v1/agent/converse`. The files' `info.version` is `1.0.0`; it is not a reliable immutable spec revision. |
| [SDK feature matrix](https://developers.deepgram.com/sdks/sdk-features) | Lists official SDK availability and API status. It does not list Swift or PHP as supported SDKs. The feature matrix is a reference for scope, not evidence that this project's features work. |
| [Official examples](https://github.com/deepgram/examples) and [recipes](https://github.com/deepgram/recipes) | Show runnable usage patterns and how Deepgram tests examples; some live examples require credentials. |

The pinned candidate spec revision is [`6668bc2d5c3dc720697364f8c2ce3c8c0e27fbc5`](https://github.com/deepgram/deepgram-api-specs/tree/6668bc2d5c3dc720697364f8c2ce3c8c0e27fbc5), committed 2026-09-18. Local downloads of that revision have SHA-256 `0d65cf6415837a479f05dcd328f7c167dcc4a3ff22b6be6402207a8c34da98b9` for OpenAPI and `496fbcd1cd98e278613cda21bc397f344a46254a5113f4a37bfc85fca3eab174` for AsyncAPI. Phase 1 will vendor the exact bytes with provenance and attribution so normal builds never fetch a moving branch.

## Official SDK architecture

| SDK | Relevant observation |
| --- | --- |
| [JavaScript](https://github.com/deepgram/deepgram-js-sdk) | Current README describes Fern-generated REST methods plus streaming clients. Its [`.fernignore`](https://github.com/deepgram/deepgram-js-sdk/blob/main/.fernignore) protects a custom client, transport, examples, and unit tests. |
| [Python](https://github.com/deepgram/deepgram-python-sdk) | [`.fernignore`](https://github.com/deepgram/deepgram-python-sdk/blob/main/.fernignore) explicitly protects custom auth, secure logging, transport implementations, and WebSocket clients for Listen and Speak versions. This is strong evidence that lifecycle logic needs handwritten ownership. |
| [Go](https://github.com/deepgram/deepgram-go-sdk) | Go module has its own package layout and streaming API. No `.fernignore` was present at the repository root when inspected; do not infer that all official SDKs use Fern. |
| [Java](https://github.com/deepgram/deepgram-java-sdk) | [`.fernignore`](https://github.com/deepgram/deepgram-java-sdk/blob/main/.fernignore) protects custom clients, transport hooks, reconnect logic, and selected protocol types. |
| [.NET](https://github.com/deepgram/deepgram-dotnet-sdk) | Separate SDK with streaming support; no root `.fernignore` observed. |
| [Rust](https://github.com/deepgram/deepgram-rust-sdk) | Repository README calls it community owned and moving toward stable 1.0; no root `.fernignore` observed. Its status differs from the official language entries in the feature matrix. |

There was no public `deepgram/deepgram-swift-sdk` or `deepgram/deepgram-php-sdk` repository at the inspected URLs on this date. Search snippets that mention a Swift SDK should not be treated as repository evidence.

## API and protocol inventory

| Surface | Public source | Implications for this project |
| --- | --- | --- |
| Prerecorded STT | [`POST /v1/listen`](https://developers.deepgram.com/reference/speech-to-text/listen-pre-recorded), [quickstart](https://developers.deepgram.com/docs/pre-recorded-audio) | Supports URL JSON and uploaded media bytes. The synchronous response and callback acknowledgement have different shapes; model both deliberately. |
| Listen v1 realtime | [`wss://api.deepgram.com/v1/listen`](https://developers.deepgram.com/reference/speech-to-text/listen-streaming) | Binary audio plus JSON control messages (`Finalize`, `CloseStream`, `KeepAlive`); results and metadata events. |
| Listen v2 / Flux | [`wss://api.deepgram.com/v2/listen`](https://developers.deepgram.com/reference/speech-to-text/listen-flux), [quickstart](https://developers.deepgram.com/docs/flux/quickstart) | Requires a Flux model. Raw audio needs encoding and sample rate. `TurnInfo` carries transcript, turn signal, words, sequence and request IDs; `Connected`, configure acknowledgements and fatal errors are distinct. Approximately 80 ms audio chunks are recommended. |
| TTS REST | [`POST /v1/speak`](https://developers.deepgram.com/reference/text-to-speech/speak) and [OpenAPI](https://github.com/deepgram/deepgram-api-specs/blob/main/openapi.yml) | Audio is a binary response; content type and metadata headers need preservation. The spec also includes `/v2/speak`, so endpoint versions must stay explicit. |
| TTS streaming | [SDK matrix](https://developers.deepgram.com/sdks/sdk-features), [AsyncAPI](https://github.com/deepgram/deepgram-api-specs/blob/main/asyncapi.yml), [Flux TTS guide](https://developers.deepgram.com/docs/flux-tts/quickstart) | `/v1/speak` and `/v2/speak` are separate WebSocket protocols. Flux TTS v2 adds turn based events and stricter query parameters; do not reuse v1 state handling blindly. |
| Voice Agent | [`/v1/agent/converse`](https://developers.deepgram.com/reference/voice-agent/voice-agent), [message flow](https://developers.deepgram.com/docs/voice-agent-message-flow) | Publicly documented and GA in the matrix. Requires ordered welcome/settings exchange, binary audio and typed control events. Scope after the core Listen and Speak lifecycle is proven. |

Authentication uses `Authorization: Token <API_KEY>` for keys or `Bearer` for temporary tokens in the streaming reference. The initial SDK API should focus on API keys. Browser style WebSocket subprotocol authentication is documented but should not be assumed available through every native transport.

## Phase 0 architecture proposal

1. Pin the public mirror's OpenAPI and AsyncAPI files by commit and checksum. Keep their attribution beside the snapshot. A deliberate update command changes the pin, then validation and generation run locally.
2. Generate only schema-derived request, response, and event types and endpoint metadata. Place them under each language's `Generated/` tree and mark them. Handwrite transport, auth, lifecycle, retry, logging, and ergonomic entry points in separate directories. A generator may replace its entire output directory without touching runtime files.
3. Start with a small shared *selection manifest* mapping spec operations and messages to product capabilities. Avoid a full intermediate representation until the Swift and PHP generators show concrete duplication. The specs themselves remain the common source.
4. Build shared JSON and wire fixtures early. A capability is `supported` only after the corresponding offline contracts, lifecycle cases where applicable, and an opt-in live test exist. The parity table must reflect delivered behavior, not intended scope.
5. Use URLSession and Foundation for Swift REST/WebSocket. Evaluate send/receive and close semantics with a fake socket seam. PHP REST should use a small configurable transport with no framework; pick a maintained WebSocket library after protocol tests define the actual need.

The working architecture is: pinned specs → selected schema generator → generated wire types in Swift/PHP → handwritten native runtimes → shared contract fixtures and parity validation. The selection manifest is narrower than a normalized API model and keeps spec drift visible.

## Risks and unknowns

- AsyncAPI describes message shapes but cannot prove reconnect safety. Reconnecting after sent audio may duplicate or lose a turn. The SDK must expose interruption clearly and make automatic reconnect policy explicit, with tests for replay behavior.
- Live endpoints evolve faster than the mirror's generic `info.version`. Hash and commit changes, then review semantic diffs before regeneration.
- Binary REST responses and union responses need special generation treatment. A generic all-endpoints generator could produce awkward public APIs; keep the generated layer private to the runtime where possible.
- Flux TTS v2 appeared in the current specs and docs. It is additional scope beyond the prompt's core TTS requirement; it must not be marked supported until implemented and exercised.
- Voice Agent is publicly documented, but its ordered control flow and provider-specific settings make it a separate runtime effort. Do not treat generated message types as support.
- There is no authenticated live request in Phase 0; response headers, close codes, and retryable failure behavior still need integration verification.
