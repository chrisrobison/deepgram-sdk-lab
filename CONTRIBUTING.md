# Contributing

This project is independent of Deepgram. File issues or changes in this repository for its own code; upstream specification corrections belong with Deepgram's public documentation process.

Use focused commits. Before a PR, run `./tools/validate-spec` and `./tools/parity --check` (PyYAML required). Keep handwritten code outside generated directories. For spec changes, pin a full upstream commit with `./tools/update-spec <sha>`, review the diff and update tests and research notes. Do not commit API keys or audio containing private data. Live tests must be opt-in with `DEEPGRAM_API_KEY`.
