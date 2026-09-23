You are a senior staff-level SDK/platform engineer. Build a production-quality open-source project demonstrating how additional language SDKs could be added to the Deepgram ecosystem in a repeatable, maintainable way.

The project is intended to demonstrate the kind of engineering required to own a multi-language SDK platform: API specification consumption, code generation, language-native runtime layers, WebSocket transports, cross-language feature parity, testing, documentation, CI/CD, versioning, and developer experience.

Do not build a toy wrapper.

The finished project should be credible enough that engineers responsible for Deepgram's official SDKs could review it and take the architecture seriously.

# Primary Goal

Create a repository tentatively named:

`deepgram-sdk-lab`

The first fully functional SDK should be:

**Swift**

The second SDK should be:

**PHP**

Swift is the primary showcase. PHP exists partly to prove that the architecture generalizes across languages rather than being a one-off Swift implementation.

The architecture should make adding a third language relatively straightforward.

# Before Writing Code

First research the current Deepgram ecosystem.

Inspect:

* Deepgram's official API documentation
* Deepgram's public API specification repositories
* Deepgram's AsyncAPI/OpenAPI definitions
* official Deepgram JavaScript SDK
* official Python SDK
* official Go SDK
* official Java SDK
* official .NET SDK
* official Rust SDK
* Deepgram SDK feature matrix
* Deepgram examples repositories
* any documentation describing their generated-code architecture
* their use of Fern, if applicable
* `.fernignore` or equivalent generated/manual-code boundaries in official SDKs
* current Listen v1 APIs
* current Listen v2 / Flux APIs
* Text-to-Speech APIs
* Voice Agent APIs
* prerecorded transcription APIs

Do not assume API shapes from memory.

Use Deepgram's current public specifications and repositories as the source of truth.

Document important architectural observations in:

`docs/research.md`

Include links to the public sources used.

# Architectural Principle

Separate the SDK into two conceptual layers:

1. GENERATED API LAYER
2. HAND-WRITTEN LANGUAGE-NATIVE RUNTIME

Generated code should contain things that can safely be derived from an API specification:

* request types
* response types
* enums
* event/message models
* endpoint definitions
* serialization
* API errors where appropriate

Hand-written code should contain things where language-native design matters:

* authentication
* HTTP transport integration
* WebSocket lifecycle
* reconnect behavior
* streaming
* audio capture helpers
* async iteration
* cancellation
* backpressure
* retry policy
* logging hooks
* convenience APIs
* resource cleanup
* connection state
* developer-friendly abstractions

Generated files must be clearly marked.

Regeneration must never destroy hand-written code.

# Proposed Repository Layout

Use something approximately like:

deepgram-sdk-lab/
README.md
LICENSE
CONTRIBUTING.md
ARCHITECTURE.md

```
specs/
    README.md
    ...

tools/
    generate
    parity
    validate-spec
    ...

generators/
    common/
    swift/
    php/

sdks/
    swift/
        Package.swift
        Sources/
        Tests/
        Examples/

    php/
        composer.json
        src/
        tests/
        examples/

examples/
    swift-voice-playground/
    swift-cli/
    php-transcribe/

parity/
    features.yaml
    README.md

tests/
    contract/
    fixtures/

docs/
    research.md
    adding-a-language.md
    generated-vs-runtime.md
    releasing.md
    design-decisions/

.github/
    workflows/
```

This layout may change if research suggests a better structure. Explain significant deviations.

# Swift SDK

The Swift implementation is the flagship.

It must feel like a Swift SDK rather than a JavaScript API mechanically translated into Swift.

Target modern Swift.

Prefer:

* async/await
* AsyncSequence / AsyncStream
* Codable
* actors where useful
* Sendable correctness
* URLSession
* native WebSocket facilities
* Foundation
* minimal external dependencies

Avoid external packages unless they materially improve the implementation.

The ideal usage should approach:

```swift
let deepgram = Deepgram(apiKey: apiKey)

let stream = try await deepgram.listen.v2.connect(
    model: .fluxGeneralEn
)

try await stream.send(audioData)

for try await event in stream.events {
    switch event {
    case .turnInfo(let turn):
        print(turn.transcript)

    default:
        break
    }
}
```

Design the exact API based on Deepgram's actual current API.

Also explore whether an ergonomic convenience API such as this makes sense:

```swift
try await stream.streamMicrophone()
```

Do not let microphone integration contaminate the core transport layer. It should be an optional convenience component/example.

Implement at minimum:

* API key authentication
* prerecorded transcription
* realtime transcription
* Listen v2 / Flux if publicly supported
* Text-to-Speech REST
* streaming Text-to-Speech if publicly supported
* typed WebSocket events
* clean connection lifecycle
* cancellation
* error handling
* automatic cleanup
* configurable reconnect policy
* configurable retry policy
* user agent containing SDK version
* request IDs / relevant Deepgram metadata when exposed
* logging hooks without requiring a logging framework

Voice Agent support should be implemented if its public protocol/specification is sufficiently stable and documented.

Do not fabricate support merely to make the parity table green.

# Swift Example Application

Build one polished example that makes the SDK immediately understandable.

Prefer either:

1. small macOS/iOS SwiftUI voice playground

or, if platform signing/UI complexity would distract too much:

2. excellent command-line realtime voice demo plus a minimal SwiftUI example

The demo should show:

* connection state
* microphone activity
* realtime transcript
* detected turn boundaries if available
* model
* basic latency measurements
* errors/reconnect state

Keep it visually simple and professional.

Do not make the example application's architecture more complicated than the SDK itself.

# PHP SDK

Implement the same conceptual architecture for PHP.

Use modern PHP.

Prefer:

* PHP 8.2+
* strict types
* PSR conventions where useful
* Composer
* minimal dependencies

REST functionality should not require a large framework.

Evaluate existing PSR HTTP abstractions versus a small internal HTTP transport. Choose deliberately and document the decision.

For realtime WebSocket APIs, use an appropriate small dependency only if implementing WebSockets correctly without one would be unreasonable.

The PHP SDK should initially support:

* prerecorded transcription
* Text-to-Speech
* API authentication
* typed request/response models
* common errors
* configurable transport
* realtime APIs where practical

The purpose of PHP is not to achieve artificial 100% parity immediately.

It is to demonstrate that the same specification and architectural pipeline can produce a second idiomatic SDK.

# Code Generation

This is one of the most important parts of the project.

Do not simply copy existing generated code into the repository and call it generation.

Create a reproducible process.

Determine from research whether it makes more sense to:

* consume Deepgram's existing OpenAPI/AsyncAPI definitions directly
* use Fern
* transform Deepgram specs into an intermediate representation
* use language-specific generators
* implement a small custom generation pipeline
* combine these approaches

Favor simplicity and reproducibility.

A developer should eventually be able to run something similar to:

```bash
./tools/generate swift
./tools/generate php
./tools/generate all
```

Generation should be deterministic.

CI should detect generated-code drift.

If generated files have changed because the specification changed, CI should make this obvious.

# API Specification Handling

Do not silently copy Deepgram specifications and allow them to become stale.

Choose an explicit upstream strategy, such as:

* pinned git submodule
* pinned commit fetch
* vendored snapshot with provenance metadata
* upstream URL + checksum + update command

Record:

* source repository
* commit/version
* date retrieved
* checksum if appropriate

Provide a command to update the spec deliberately.

For example:

```bash
./tools/update-spec
```

Never fetch arbitrary "latest" specs during normal builds.

Builds must be reproducible.

# Cross-Language Intermediate Model

Investigate whether a normalized internal representation would materially improve maintainability.

For example:

Deepgram Specs
|
v
Normalized API Model
|
+---- Swift Generator
|
+---- PHP Generator
|
+---- Future Language

Do not create an intermediate representation merely because it sounds architectural.

Use one only if it eliminates meaningful duplication.

Document the decision.

# Feature Parity System

Create:

`parity/features.yaml`

It should define capabilities independently from individual languages.

Example conceptual structure:

```yaml
features:
  prerecorded_transcription:
    swift: supported
    php: supported

  listen_v1:
    swift: supported
    php: experimental

  listen_v2_flux:
    swift: supported
    php: planned

  tts_rest:
    swift: supported
    php: supported

  tts_streaming:
    swift: supported
    php: planned

  voice_agent:
    swift: experimental
    php: planned
```

Use statuses such as:

* supported
* experimental
* partial
* planned
* unsupported

Do not use checkmarks for features that merely compile.

Define exactly what "supported" means.

Generate a human-readable parity table for the README from this machine-readable file.

Ideally validate feature claims against automated tests where practical.

# Contract Tests

Create tests that can validate implementations across languages using shared fixtures.

Examples:

* JSON serialization
* query parameter encoding
* enum handling
* error response parsing
* event decoding
* WebSocket message decoding
* authentication headers
* URL construction

Keep language-specific unit tests as well.

Shared fixtures should prevent Swift and PHP from subtly interpreting the same API differently.

# Integration Tests

Add optional Deepgram integration tests using:

`DEEPGRAM_API_KEY`

These should never run accidentally without credentials.

Separate:

* offline unit tests
* contract tests
* live API integration tests

CI for pull requests should work without exposing credentials.

Where appropriate, protected CI may execute real integration tests.

# WebSocket Testing

Realtime SDK quality depends heavily on WebSocket behavior.

Do not limit tests to the happy path.

Test:

* normal connection
* server close
* client close
* malformed events
* unknown future event types
* reconnect behavior
* cancellation
* network interruption simulation where practical
* partial audio chunks
* rapid shutdown
* send after close
* connection timeout

Unknown server events should not unnecessarily crash clients.

Favor forward compatibility.

# Error Model

Design a coherent error hierarchy.

Distinguish where reasonable:

* authentication failure
* HTTP API failure
* malformed response
* connection failure
* WebSocket protocol issue
* timeout
* cancelled operation
* invalid local configuration
* unsupported feature

Preserve Deepgram request IDs and useful response metadata where available.

Error messages must help developers debug problems.

# Versioning

Use semantic versioning.

There should be:

* one project version strategy
* SDK package version strategy
* generated API/spec version metadata

Think carefully about whether all languages should always share a version number.

Document the choice rather than blindly using a monorepo version.

# CI

GitHub Actions should test:

Swift:

* format/lint if chosen
* build
* unit tests
* contract tests

PHP:

* Composer validation
* static analysis if useful and lightweight
* unit tests
* contract tests

Repository:

* generator determinism
* generated-code drift
* parity file validation
* documentation links where practical

Support macOS runners only where Swift genuinely requires them.

Avoid gratuitously expensive CI.

# Release Automation

Design, and preferably implement, a release workflow capable of eventually publishing:

Swift:

* Git tags / Swift Package Manager compatible releases

PHP:

* Packagist-compatible Composer package

Do not actually publish packages without explicit authorization.

Release tooling should be testable in dry-run mode.

# Documentation

Documentation quality matters as much as implementation quality.

The root README should answer within the first screen:

1. What is this?
2. Why does it exist?
3. What currently works?
4. How do I try it?
5. How does the architecture work?

Include:

* minimal Swift example
* minimal PHP example
* architecture diagram
* generated parity matrix
* links to examples
* project status
* disclaimer that this is an independent/unofficial project unless Deepgram explicitly adopts it

Create:

`ARCHITECTURE.md`

covering:

* specification source
* generation lifecycle
* generated/manual code boundary
* transport architecture
* parity architecture
* testing architecture
* releases
* adding another language

Create:

`docs/adding-a-language.md`

The goal is that someone could reasonably add Ruby, Kotlin, Dart, or another language by following it.

# Architectural Decision Records

For important choices, create short ADRs under:

`docs/design-decisions/`

Examples:

* why Swift first
* generated vs handwritten boundary
* specification pinning strategy
* WebSocket architecture
* intermediate representation or lack thereof
* dependency policy
* versioning strategy

Keep ADRs concise.

# Developer Experience

Treat SDK ergonomics as a primary feature.

A developer's first successful transcription should require very little code.

Avoid:

* giant configuration objects
* unnecessary builders
* exposing generated internals
* leaky transport abstractions
* excessive dependency injection
* architecture astronauts
* dozens of tiny protocols/interfaces without purpose

Prefer boring, predictable APIs.

Advanced behavior should be configurable without making simple behavior complicated.

# Performance

Measure important things instead of guessing.

Create a lightweight benchmark harness for:

* object/event decode throughput
* WebSocket event processing overhead
* memory behavior during longer streaming sessions where practical
* generator performance if meaningful

Do not optimize prematurely.

Record baseline results.

# Security

Never commit an API key.

Support environment configuration in examples.

Avoid logging:

* API keys
* raw authorization headers
* sensitive audio

Review dependencies for obvious risks.

# Dependency Policy

Keep dependencies minimal.

Every dependency must solve a real problem.

Document significant dependencies and why they exist.

Do not introduce:

* a web framework
* a DI framework
* a giant build system
* unnecessary code-generation platforms

unless the benefit is compelling.

# Intellectual Property / Project Positioning

This is an independent compatibility project.

Do not imply that it is an official Deepgram project.

Use publicly documented APIs/specifications appropriately.

Do not copy large sections of Deepgram source code.

Study official SDK architecture and patterns, but implement the project independently.

Preserve licenses and attribution where required.

# Git Discipline

Make logical commits.

Good examples:

* `docs: document Deepgram SDK architecture research`
* `build: add pinned Deepgram API specification`
* `gen: add normalized API model`
* `swift: add generated REST models`
* `swift: implement realtime websocket transport`
* `swift: add Flux streaming example`
* `php: add REST transport`
* `ci: verify generated code is current`

Do not make one giant "initial implementation" commit.

# Implementation Phases

Work incrementally.

## Phase 0 — Research

Deliver:

* `docs/research.md`
* initial architecture proposal
* API/spec inventory
* feature inventory
* risks and unknowns

Do not implement major code before this is complete.

## Phase 1 — Repository Foundation

Deliver:

* repository structure
* spec pinning/update mechanism
* build scripts
* initial parity schema
* architecture documentation
* basic CI

## Phase 2 — Swift REST

Deliver:

* Swift package
* generated types
* authentication
* REST transport
* prerecorded transcription
* TTS REST
* tests
* examples

At the end of Phase 2, a developer should be able to install the package and transcribe an audio file.

## Phase 3 — Swift Realtime

Deliver:

* WebSocket runtime
* Listen realtime support
* Listen v2 / Flux support where applicable
* typed events
* cancellation
* lifecycle management
* reconnect behavior
* realtime CLI example
* robust tests

## Phase 4 — Swift Showcase

Deliver:

* polished voice playground example
* latency instrumentation
* README demo assets/instructions
* refined public API

Do a developer-experience review before moving on.

## Phase 5 — PHP

Reuse the architecture.

Deliver:

* Composer package
* generated types
* REST transport
* prerecorded transcription
* TTS
* contract tests shared conceptually with Swift
* appropriate realtime support
* examples

Record anything that was unexpectedly difficult to generalize.

Those pain points are important architectural findings.

## Phase 6 — Parity + Automation

Deliver:

* generated feature matrix
* generator-drift CI
* cross-language contract tests
* release dry-run workflow
* adding-a-language documentation

## Phase 7 — Staff-Level Review

Before calling the project complete, review it as though you are the engineer who would inherit it for the next five years.

Ask:

* What will break when Deepgram changes the spec?
* How do we discover spec changes?
* What must be regenerated?
* What cannot safely be generated?
* How difficult is Ruby SDK support now?
* How difficult is Kotlin SDK support now?
* Are Swift and PHP truly sharing architecture, or merely living in the same repository?
* Are API differences between languages intentional?
* Are public APIs stable enough for users to depend on?
* Can releases be reproduced?
* Can failures be diagnosed?
* Will unknown future server events break clients?
* Is CI testing actual behavior or merely compilation?
* Is generated-code ownership obvious?
* Could another engineer understand this project quickly?

Write the findings to:

`docs/staff-review.md`

Fix significant issues discovered during this review.

# Definition of Done

Do not consider the project finished merely because examples work.

The project is done when:

* Swift installation is straightforward
* PHP installation is straightforward
* generation is reproducible
* specifications are pinned
* generated/manual boundaries are clear
* Swift realtime transcription works
* Swift API feels idiomatic
* PHP proves the architecture generalizes
* contract tests exist
* live integration tests exist
* WebSocket lifecycle is tested
* parity is machine-readable
* README parity is generated
* CI detects drift
* releases can be dry-run
* documentation explains how to add another language
* no secrets are present
* public APIs are documented
* examples are runnable
* another experienced engineer could maintain it

# Important Working Rules

Do not fake functionality.

Do not mark TODO implementations as supported.

Do not swallow errors to make demos appear successful.

Do not overengineer.

Do not create abstractions before there are at least two concrete consumers unless there is a compelling reason.

Do not blindly reproduce Deepgram's existing SDK APIs if a language has a clearly more idiomatic approach.

Do maintain conceptual consistency across languages.

Do inspect the existing official SDKs when answering questions about expected behavior.

Do explain significant architectural decisions in repository documentation rather than long code comments.

Do keep generated code boring.

Spend engineering creativity on:

* developer experience
* lifecycle correctness
* tooling
* testing
* architecture
* observability
* maintainability

# How To Work

At the beginning of each phase:

1. inspect the existing repository
2. inspect relevant upstream Deepgram sources
3. state the specific phase objectives
4. identify risks
5. implement
6. run tests
7. review the diff
8. update documentation
9. commit logical units

Do not attempt the entire project in one context window.

At the end of each phase, create:

`docs/progress/phase-N.md`

containing:

* completed work
* tests run
* known deficiencies
* architectural observations
* next phase
* anything discovered about Deepgram's APIs that affects later work

Always leave the repository in a working state at phase boundaries.

# Final Objective

The repository should communicate a clear engineering thesis:

**A multi-language SDK organization should not maintain N unrelated SDKs. It should maintain a specification-driven SDK platform with shared behavioral contracts, generated API surfaces, language-native runtime layers, measurable feature parity, and automated releases.**

The Swift SDK is the demonstration.

The PHP SDK is proof that the architecture generalizes.

The real product is the SDK engineering system.
