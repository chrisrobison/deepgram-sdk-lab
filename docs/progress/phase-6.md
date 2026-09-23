# Phase 6 — parity and automation

Completed for the offline 0.1.0 preview, 2026-09-23.

## Completed work

- Machine-readable capability claims generate the README table and are checked in CI.
- Swift and PHP generators regenerate from a pinned spec snapshot; CI fails on drift.
- Shared prerecorded fixture and language-specific HTTP/WebSocket contracts cover the implemented runtime shapes.
- A manual GitHub Actions release workflow validates version metadata, generation, parity, Swift tests, and PHP contracts. Its `publish=false` path cannot create a tag or release. The separate publish job requires the protected `release` environment.
- The language onboarding guide and coordinated version strategy are documented.

## Checks run

- [Release dry run 35930071959](https://github.com/chrisrobison/deepgram-sdk-lab/actions/runs/35930071959) passed platform, Swift, and PHP jobs; publish was skipped.
- `./tools/release-dry-run` and `./tools/parity --check` passed locally.

## Known deficiencies

- No live API key was present, so credential-backed tests have not run. Experimental claims remain below supported.
- Packagist registration and a version tag are intentionally absent. Both require a separate publication decision.
- The spec update command pins a supplied SHA, but upstream change discovery and semantic diff review remain manual.

## Next phase

Perform the staff review, then use credential-backed results and an installed macOS app bundle to validate public behavior before a first release.
