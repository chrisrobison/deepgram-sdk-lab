# Swift package

The Swift package targets macOS 13+/iOS 16+ and uses Foundation and URLSession. No third-party package is required. It is an independent, early-stage implementation.

Run `swift build` and `swift test` from this directory. Live XCTest is skipped unless `DEEPGRAM_LIVE_TESTS=1` and `DEEPGRAM_API_KEY` are set. The CLI can transcribe a local WAV file or stream microphone audio to Flux:

```sh
DEEPGRAM_API_KEY=... swift run deepgram-cli transcribe ./audio.wav
DEEPGRAM_API_KEY=... swift run deepgram-cli flux
```

To use this repository as a local SwiftPM package, add `sdks/swift` as a package dependency and import `DeepgramSDKLab`. Published tags and registry distribution are not available yet.

`Deepgram.listen.transcribe(url:)`, `transcribe(audio:contentType:)`, and `transcribe(file:contentType:)` return generated `ListenV1Response` models. `Deepgram.speak.generate(text:)` returns bytes plus content type, request ID, and model metadata. For realtime, use `deepgram.listen.v1.connect(...)` or `deepgram.listen.v2.connect(model: .fluxGeneralEn, encoding: "linear16", sampleRate: 16000)` and iterate `stream.events`.

Automatic reconnect is limited to connections that have sent no audio. Audio replay after an interruption can duplicate or omit speech; in-flight streams report an interruption error so callers can begin a new session deliberately. Events use a bounded 128-element buffer and fail on overflow. Unknown JSON events are forwarded as `.unknown`; malformed JSON appears as `.malformed`.
