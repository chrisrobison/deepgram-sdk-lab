# Releasing

The project is currently unreleased. Root SwiftPM and Composer manifests allow development use from the Git repository; neither package registry has a published entry.

For a future `vX.Y.Z` release:

1. Review the pinned spec commit, generated drift, parity claims, test results, changelog, and secret scan.
2. Set `version.json`, Swift `Deepgram.version`, and PHP `Client::VERSION` to the same SemVer. Run `./tools/release-dry-run` and both SDK suites.
3. Run opt-in live tests with a protected `DEEPGRAM_API_KEY`. Record the tested region, API responses, and request IDs privately; never put credentials or sensitive audio in the repository.
4. Create an annotated root Git tag `vX.Y.Z` and a GitHub release only after explicit release approval. Verify SwiftPM installation from that tag and Composer installation through a VCS repository declaration.
5. Packagist registration/publishing is a separate external action requiring explicit authorization. Verify package metadata and generated artifacts before it is enabled.

The spec revision is not the SDK version. A spec update may or may not change public SDK behavior. See [ADR 0002](design-decisions/0002-versioning-and-packaging.md) for the coordinated 0.x strategy and conditions for future independent versions.
