# Staff review — 0.1.0 preview

Reviewed 2026-09-23 against the pinned Deepgram spec and current offline CI. This is an independent SDK platform experiment, not an official SDK or a production support promise.

## What is maintainable now

| Question | Finding |
| --- | --- |
| Spec change | `specs/source.json` records the exact commit and checksums. `tools/update-spec <sha>` changes the snapshot deliberately; generated drift is checked in CI. A reviewer must still inspect semantic endpoint and protocol differences before changing the pin. |
| Generation ownership | Generated directories carry source markers and are the only paths overwritten by generators. Native transport and lifecycle code is separate. The architecture document was corrected to describe the shipped generators rather than a future design. |
| Third language | The [onboarding guide](adding-a-language.md) gives a concrete sequence. Ruby can use the same pinned JSON/YAML and fixture approach. Kotlin would need JVM transport choices and an explicit mapping for nullability and numeric-string fields. A third generator should reveal whether common normalization is justified. |
| Behavioral parity | Both languages use the same spec revision, generated wire types, shared prerecorded fixture, and parity definitions. Swift's async actor streams and PHP's blocking iterator differ intentionally. PHP lacks Speak streaming and Voice Agent. |
| Future events | Listen and Agent event dispatch preserve unknown event payloads and surface malformed events without forcing a decoder crash. Protocol handshakes still reject an unexpected first event, which is appropriate for an incompatible session. |
| Failure diagnosis | HTTP errors preserve Deepgram request IDs where exposed. Realtime clients surface connection and malformed-event errors. Examples show request IDs and state. No key or audio is logged by SDK hooks. |
| Releases | Root SwiftPM and Composer manifests share coordinated 0.x versions. The manual dry run passed; the publish job is gated. No tag or registry entry exists yet. |

## Release blockers and residual risks

1. **Live protocol verification:** No `DEEPGRAM_API_KEY` was available. Run the opt-in live REST and WebSocket checks, inspect request IDs and server close behavior, and adjust API shapes before promoting any capability to `supported`.
2. **SwiftUI microphone verification:** The example builds, but microphone permission, UI behavior, and shutdown need a manual run in an installed macOS app bundle. Its arrival lag is an estimate, not a measured service latency.
3. **Streaming endurance:** Offline contracts cover representative frames and lifecycle edges. Longer sessions, bursty audio, network interruption, and memory bounds still need instrumented testing. The benchmark covers model decoding and generator runtime, not live WebSocket throughput.
4. **Spec evolution:** The snapshot is pinned but there is no scheduled upstream change detector or machine-readable semantic diff. The maintainer should review upstream periodically, run `tools/update-spec` for an approved SHA, inspect the diff, regenerate, and run contracts. Do not auto-promote new models or parity claims.
5. **Dependency and release review:** PHP's optional `phrity/websocket` dependency is locked for tests. Review its updates and transitive dependencies before release. Packagist registration, tagged SwiftPM installation, and VCS Composer installation have not been tested from a published tag.

## Decisions from this review

- Keep every implemented capability `experimental` until live behavior is verified. A successful compile or offline contract is insufficient for `supported`.
- Keep reconnect limited to pre-payload failures. Replaying audio or TTS text automatically can duplicate billable work and corrupt conversation state.
- Keep the two small language generators. Add a shared intermediate representation only after a third language demonstrates repeated, incompatible schema transformations.
- Treat the preview API as subject to change. Publish a tagged release only after the live and packaging checks above.
