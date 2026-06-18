---
name: check-upstream-first
description: "For bugs in third-party deps installed from npm/github/bun, check upstream CHANGELOG before investigating installed-version source. Many fork-and-fix bugs are upgrade-and-done."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 9bef26f3-091c-484d-917a-ecab3452f214
---

For bugs in third-party dependencies (gbrain, gstack, any github-installed package), check upstream CHANGELOG before going deep into installed-version source archaeology.

**Why:** On 2026-05-28 we spent ~2 hours investigating a "silent-exit + data-loss" bug in gbrain 0.41.2.0. Hypothesized connection-pool race, supervisor interference, pack-gating, etc. Marcus then asked the simple question — "is there a newer gbrain?" — and we found v0.41.13.0 had the silent-exit fix and v0.41.19.0 had the data-loss fix, both shipped 2-3 days before. We almost started a fork/PR.

**How to apply:**
1. Identify install source first: `bun pm ls -g`, `npm view <pkg>`, `cat node_modules/<pkg>/package.json`, brew/cargo equivalents. Note pinned commit/tag/version.
2. Fetch upstream CHANGELOG: `curl -s https://raw.githubusercontent.com/<owner>/<repo>/master/CHANGELOG.md` (or `main`).
3. Grep CHANGELOG between installed version and latest for the bug shape: error message text, component name, symptom keyword.
4. If matched: assess migration risk (schema bumps? breaking?), upgrade, retest. If not matched OR no relevant fix: continue source-level investigation.
5. Trigger this on any bug in `~/.bun/install/`, `node_modules/`, `~/.cargo/`, brew prefix, pip site-packages.

Related: gbrain ships via `github:garrytan/gbrain` so the upstream check is `curl raw.githubusercontent.com/garrytan/gbrain/master/CHANGELOG.md`. bun caches commits aggressively — `bun remove -g <pkg>` + reinstall at explicit commit hash bypasses the dependency-loop error you get from `bun install -g pkg#master --force`.

Links: [[feedback_gbrain_config_planes]]
