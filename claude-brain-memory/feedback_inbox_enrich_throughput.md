---
name: inbox-enrich-throughput-by-model
description: "Opus is slower than Sonnet at clearing the inbox-enrich backlog because it burns the 30-turn ceiling faster — Sonnet ~8-10 files/run, Opus ~4"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d3a51c18-c383-45a2-be1b-e45f099c3328
---

When running `~/bin/prompts/inbox-enrich.md` via `claude --print --model <X>`, model choice changes per-run *throughput*, not just quality:

- **Sonnet 4.6**: ~8-10 files per invocation (matches the prompt's stated cap of 10/run)
- **Opus 4.7**: ~4 files per invocation — Opus uses more reasoning turns per file and hits the prompt's 30-turn ceiling earlier

**Why:** Verified on 2026-05-18 clearing a 74-file backlog. 8 Opus runs (17 min) cleared 33 files; 5 Sonnet runs (27 min) cleared the remaining 41. Per-run throughput, not wall-clock speed, is the binding constraint because each `claude --print` invocation pays a fixed prompt-loading cost.

**Reconfirmed 2026-05-19 in parallel mode**: ran brain-run inbox phase with `MODEL_SONNET=claude-opus-4-7` override, 116-file backlog, 12 parallel batches of 10. Five batches (5, 6, 7, 9, 11) hit max-turns and required split-in-half retry — all halves succeeded second pass. Total: 110 emails fully processed, $34.55, 33 min wall-clock, 22 batches total (12 primary + 10 retry halves). Estimate was Sonnet-baseline ($17.40); Opus actual was 2× that. Sonnet would have completed in ~12 batches with no retries at ~$18.

**How to apply:**
- For pure throughput (large backlogs, daily cron catch-up), use **Sonnet**. The CLAUDE.md tier rules already say inbox processing is Sonnet-tier — this confirms why.
- Use **Opus** only when per-file quality is the bottleneck — typically Tier 1 entity enrichment, compiled-truth synthesis (the dream cycle), or a single high-stakes file where you want maximum reasoning.
- If clearing a backlog, lead with Sonnet sweeps; don't reach for Opus thinking it'll "do more per run."
- See [[inbox-enrich]] daily cron at `~/bin/brain-daily.sh` — it already uses Sonnet for this reason.
