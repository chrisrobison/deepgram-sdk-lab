# Feature claims

`features.yaml` is the single source for the README table. Run `./tools/parity` to update it; CI runs `./tools/parity --check`.

Statuses:

- `supported`: public API implemented, offline contract and lifecycle tests pass, and an opt-in credential-backed integration test exists and has passed for the current behavior.
- `experimental`: implemented and tested, but public API or server behavior is still being validated; document the risk.
- `partial`: a meaningful documented subset works; name missing pieces in the SDK documentation.
- `planned`: no support claim.
- `unsupported`: intentionally outside scope or technically unavailable; document why.

Changing YAML alone does not demonstrate support. A review must link the implementing code and tests. The table is a claim, not a test oracle.
