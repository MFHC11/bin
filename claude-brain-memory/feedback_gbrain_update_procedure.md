---
name: feedback_gbrain_update_procedure
description: "How to update/upgrade the gbrain CLI safely (private github source, npm impostor trap, bun quirk, blocked migration postinstall)"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b5395f9c-baf8-436e-b698-a2b89b437f7f
---

"update gbrain" means upgrade the gbrain CLI to the latest commit of its **private** repo, installed via bun global from `github:garrytan/gbrain` (currently pinned by commit, e.g. `#eefe8b5`). It is "Postgres-native personal knowledge brain with hybrid RAG search".

**Why this matters:** the public npm package named `gbrain` is a totally unrelated "GPU Javascript Library for Machine Learning" (by `stormcolor`). Running `bun install -g gbrain@latest` would wipe Marcus's second-brain CLI and replace it with the wrong package. NEVER update from the public registry.

**How to apply:**
1. Check upstream first: `git ls-remote https://github.com/garrytan/gbrain HEAD`, then `curl` the raw `package.json` at that sha for the version, and the GitHub compare API (`/repos/garrytan/gbrain/compare/<old>...<new>`) for the changelog.
2. Re-pinning to a new commit triggers bun's `DependencyLoop` error. Fix: `bun remove -g gbrain` then `bun install -g "github:garrytan/gbrain#<sha>"`.
3. bun **blocks** the postinstall (`gbrain apply-migrations`). After install, run `gbrain apply-migrations --yes` manually (idempotent; routes DDL through the session pooler because `GBRAIN_DISABLE_DIRECT_POOL=1` is in ~/.zshrc — see [[feedback_gbrain_ipv6_ddl]]).
4. Verify with `gbrain --version` and `gbrain doctor`.

On 2026-06-01: updated 0.41.26.1 → 0.42.1.0. Doctor flagged a pre-existing, NOT-update-caused destructive item: `facts.embedding` is `halfvec(1536)` but gateway is `1280d` (zeroentropy) — new fact inserts will fail; fix needs a maintenance-window ALTER + index rebuild. Left unrun pending Marcus's approval.
