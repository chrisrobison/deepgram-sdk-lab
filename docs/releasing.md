# Releasing

The project is currently unreleased. Root SwiftPM and Composer manifests allow development use from the Git repository; neither package registry has a published entry.

For a future `vX.Y.Z` release:

1. Review the pinned spec commit, generated drift, parity claims, test results, changelog, and secret scan.
2. Set `version.json`, Swift `Deepgram.version`, and PHP `Client::VERSION` to the same SemVer. Run `./tools/release-dry-run` and both SDK suites.
3. Run opt-in live tests with a protected `DEEPGRAM_API_KEY`. Record the tested region, API responses, and request IDs privately; never put credentials or sensitive audio in the repository.
4. Trigger the manual `Release dry run or publish` workflow with `publish=false` to exercise all release checks. For actual publication, `publish=true` requires the protected `release` environment; it creates a root `vX.Y.Z` tag and GitHub release after approval. Verify SwiftPM installation from that tag and Composer installation through a VCS repository declaration.
5. Packagist registration/publishing is a separate external action requiring explicit authorization. Verify package metadata and generated artifacts before it is enabled. The current workflow publishes only a GitHub tag/release; no Packagist package exists yet.

The spec revision is not the SDK version. A spec update may or may not change public SDK behavior. See [ADR 0002](design-decisions/0002-versioning-and-packaging.md) for the coordinated 0.x strategy and conditions for future independent versions.
