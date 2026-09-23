# Phase 0 — research

Completed 2026-09-23.

## Completed work

- Inspected the public specification mirror, its license, API reference, feature matrix, six SDK repositories, and example repositories.
- Inventoried the REST and WebSocket surfaces and recorded a candidate pinned revision and hashes in [research](../research.md).
- Proposed a generated wire layer, language-native runtimes, and shared contracts. A full normalized IR is deferred pending evidence from two generators.

## Checks run

- Retrieved both specifications at the stated commit and computed SHA-256 hashes.
- Parsed both YAML files; verified OpenAPI 3.1.0 and AsyncAPI 2.6.0 and the listed product paths.
- Checked local Swift 6.3.2 and PHP 8.5.10 availability. Composer was not found.

## Known deficiencies and risks

- No live Deepgram call or credential-backed protocol observation yet.
- No package implementation yet; feature support claims must remain `planned` until behavior is tested.
- The local directory began without a Git repository or upstream remote, so publication needs a remote configured.

## Next phase

Establish the repository, vendor the pinned specification with attribution, add explicit spec update/validation commands, and define the initial parity data and CI gates.
