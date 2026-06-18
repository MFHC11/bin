---
name: feedback_gbrain_extract_timeline_junk
description: "gbrain extract timeline (fs source) writes ~71% malformed entries from markdown-link dates — don't run it blind"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 25c27808-1617-445e-b4bd-ec532547b9a7
---

`gbrain extract timeline` with the default `fs` source is unsafe to run as-is. On the 2026-06-04 brain (8,747 pages) a `--dry-run` projected 2,721 new timeline entries, of which **1,945 (~71%) were malformed** — the parser treats any `YYYY-MM-DD` it sees, *including dates embedded in markdown link syntax* like `[text](../meetings/2026-04-03-...md)`, as a timeline event and grabs the trailing path/URL fragment as the event text (e.g. `2026-05-07 — mackanic.md)`, `2026-04-26 — LP Pipeline](../deals/fund-ii-lp-pipeline.md)`). Only ~29% were real events. Marcus chose to skip it.

**Why:** the extractor is idempotent, but the *first* run still injects all the junk into the structured timeline, and post-hoc cleanup of ~1,945 entries is painful. Contrast with `gbrain extract links`, which is clean — on the same brain it created 0 (all wikilink/mention edges already materialized by `gbrain sync`), so links is a safe no-op.

**How to apply:** before running any `gbrain extract <links|timeline|all>`, always `--dry-run` first and grep the candidates for markdown-link junk (`grep -cE '\]\(|\.md\)'`). For `timeline` specifically, do not commit unless the junk ratio is low; the fs parser needs a fix (or test `--source db`) before it's trustworthy. See related gbrain gotchas: [[feedback_gbrain_update_procedure]], [[project_gbrain_dream_1570_race]].
