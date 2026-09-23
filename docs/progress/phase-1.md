# Phase 1 — repository foundation

Completed 2026-09-23.

## Completed work

- Initialized the repository and documented the project as independent and unofficial.
- Vendored Deepgram's public OpenAPI and AsyncAPI files at commit `6668bc2d5c3dc720697364f8c2ce3c8c0e27fbc5`, with hashes and the upstream CC BY 4.0 license.
- Added an explicit full-commit update command and offline snapshot validation.
- Added machine-readable feature claims, a generated README parity table, and CI checks.
- Documented the generated/manual boundary, language runtime direction, testing intent, and separate SDK versioning.

## Checks run

- `./tools/validate-spec`: both pinned YAML files parsed, paths checked, hashes matched.
- `./tools/parity` and `./tools/parity --check`: README table generated and verified.
- `./tools/update-spec 6668bc2d5c3dc720697364f8c2ce3c8c0e27fbc5`: same-revision update tested; hashes remained stable.

## Known deficiencies and observations

- This phase intentionally claims no supported SDK features. Swift and PHP packages, generators, fixtures and tests begin in later phases.
- Upstream has a newer `/v2/speak` REST and WebSocket surface. Both are recorded as separate parity scope rather than folded into the v1 TTS claim.
- Local Swift is available. PHP is available; Composer is not installed locally yet.
- The local Git repository has no upstream remote, so commits cannot be pushed until a remote is configured.

## Next phase

Implement the Swift package with generated REST wire types, API key authentication, prerecorded transcription and v1 Text-to-Speech REST, plus offline contracts and an opt-in live smoke test. Review spec unions and binary response headers before shaping the Swift public API.
