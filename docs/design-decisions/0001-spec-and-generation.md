# ADR 0001: Pin specs and separate generated wire code

Status: accepted for the foundation, 2026-09-23.

Deepgram publishes an hourly synced OpenAPI/AsyncAPI mirror. Pin one commit and checksums in the repository so builds and regeneration are repeatable. Copy the upstream CC BY 4.0 license with the files. Require deliberate updates, review, and drift checks.

Generate schema-derived wire code into isolated language directories; handwrite native transports and lifecycle. Official JS, Python and Java SDK `.fernignore` files support this separation. Use small local generators initially because the needed surface is selective and a full Fern-generated client would overlap handwritten runtime ownership. Reconsider a shared intermediate model after Swift and PHP expose concrete duplicated transforms.
