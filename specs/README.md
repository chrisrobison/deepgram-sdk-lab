# Pinned Deepgram specifications

`upstream/openapi.yml` and `upstream/asyncapi.yml` are byte-for-byte copies from the [public Deepgram specification mirror](https://github.com/deepgram/deepgram-api-specs) at the commit in [source.json](source.json). They are included for reproducible generation and offline contract validation. Deepgram's [CC BY 4.0 license](upstream/LICENSE) applies to these upstream files; attribution is given here and in the root documentation. The project's Apache 2.0 license applies to original project code and prose.

Normal builds read the local files only. `./tools/validate-spec` checks hashes, format versions, required paths, and the upstream attribution file.

To update, inspect upstream changes, then run `./tools/update-spec <full-40-character-commit-sha>`. The command fetches exactly that revision, refreshes the hashes and retrieval date, and validates the snapshot. Review the diff, regenerate SDK models when their generators exist, and update [research](../docs/research.md) for changed API behavior. Never point builds or generators at `main`.
