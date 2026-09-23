# ADR 0002: Coordinated prerelease versions

Status: accepted for 0.x, 2026-09-23.

The initial foundation proposed independent Swift and PHP versions. That would require separate release repositories or a split workflow: SwiftPM and Packagist consume package manifests and Git tags from repository roots. For the initial public lab, root `Package.swift` and `composer.json` point at their language source trees. Coordinated `v0.x.y` tags make both ecosystems installable from this repository and avoid an untested subtree publication system.

`version.json` is the project version; both SDK user agents carry it. The pinned Deepgram specification commit is separate metadata. `tools/release-dry-run` checks version and manifest consistency without tagging or publishing. Before 1.0, reassess whether the languages need independent release cadence and, if so, automate source splits and document their provenance. Do not claim a released package before a tag and distribution check exist.
