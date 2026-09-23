# Generated and handwritten ownership

The authoritative input is the pinned [OpenAPI/AsyncAPI snapshot](../specs/README.md). `./tools/generate all` selects the schemas currently used by the public SDKs. The Swift generator emits REST and realtime models under `sdks/swift/Sources/Deepgram/Generated/`; the PHP generator emits REST and Listen realtime models under `sdks/php/src/Generated/`. These files carry a generated marker and the source commit. CI runs `./tools/check-generated` and fails if regeneration changes them.

Generated files may be deleted and rebuilt. Do not edit them manually. Extend a generator or update the pinned source, regenerate, then review the output. The generator currently selects a narrow schema closure; it does not claim all Deepgram API operations.

`sdks/swift/Sources/Deepgram/` outside `Generated/` owns URLSession integration, auth, REST retries, WebSocket state, typed event dispatch, buffering, cancellation, and public convenience entry points. `sdks/php/src/` outside `Generated/` owns authentication, cURL transport, errors, REST methods, and the test seam. The Swift microphone layer lives in `Examples/CLI`, so capture APIs do not become a core dependency.

Two deliberate wire adaptations exist. Some upstream fields are typed as strings with a `float` title while examples send JSON numbers; Swift `WireNumber` and PHP `Wire::number` accept both. Empty schema objects retain unknown content as JSON maps. Unknown WebSocket event types are surfaced rather than treated as decoding failures.

The important generated/manual invariant is file ownership, enforced by separate directories and drift CI. `tools/generate` never writes runtime source. Generated model drift is a signal to review upstream behavior, not an automatic approval to release.
