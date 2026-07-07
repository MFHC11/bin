---
name: project_gbrain_link_graph_bugs
description: "gbrain silently drops link edges (batch array-encoding bug + DIR_PATTERN whitelist gap); ~/bin/brain-link-backfill repairs, wired into brain-daily.sh"
metadata: 
  node_type: memory
  type: project
  originSessionId: cfbd9c84-836f-483e-b1ea-5eff34dd7d1b
---

Found 2026-07-07 during the brain audit (gbrain 0.42.1.0). Three upstream bugs corrupt or understate the link graph:

1. **addLinksBatch loses whole batches**: `_addLinksBatchOnce` (core/postgres-engine.ts) passes link contexts as a client-side `text[]`; contexts containing embedded quotes (common in calendar day pages full of `[[...|...]]` pipes) produce `malformed array literal` and the WHOLE 100-row batch is lost. Console-only error, exit code stays 0: `gbrain extract` reports "done" while dropping ~23 batches (~2,300 edges) per run. This is why the 2026-07-03 calendar wikilink retrofit (13,792 links) never landed in the graph.

2. **DIR_PATTERN whitelist gap**: the link extractor (core/link-extraction.ts:46) only recognises wikilink targets under `people|companies|meetings|concepts|deal|civic|project(s)|source|media|yc|tech|finance|personal|openclaw|entities`. Links to `daily/`, `inbox/`, `sources/`, `signals/`, `drafts/`, `wiki/`, `deals/` (note: `deal` singular is whitelisted, `deals` is not) are NEVER extracted. This defeated the calendar master->year->month->day de-orphaning chain by design, not by failure.

3. **Health metrics ignore deleted_at**: `getHealth` SQL counts soft-deleted pages in page_count, orphan_pages, and coverage denominators, so the brain score is structurally understated after bulk soft-deletes (the 1,457 retired calendar pages).

**Why:** all three fail silently; "extract done" and a stable brain score look healthy while the graph rots.

**How to apply:** `~/bin/brain-link-backfill` (server-side INSERT..SELECT over path-form wikilinks in compiled_truth+timeline, idempotent, no client array marshalling) repairs 1+2 at the data level; it runs in brain-daily.sh right after the extract step. First run inserted 2,752 edges and de-orphaned ~1,536 daily pages. Remove the script only when upstream fixes land (check CHANGELOG per [[feedback_check_upstream_first]]). Also fixed the same day: calendar year-index files (daily/calendar/index/2021..2026.md) needed explicit quoted string titles in frontmatter; numeric filename stems were coerced to numbers and `gbrain sync` crashed on `opts.title.toLowerCase`, skipping the files every run since 2026-07-03 AND freezing sources.last_sync_at (the sync checkpoint only advances on a clean run, which made `gbrain doctor` report sync staleness despite daily syncs). Draft upstream report: ~/brain/.tasks/gbrain-link-graph-bugs-upstream-report.md. Related: [[project_gbrain_dream_1570_race]], [[feedback_gbrain_extract_timeline_junk]], [[feedback_brain_sync_zero_pages_indexed]].
