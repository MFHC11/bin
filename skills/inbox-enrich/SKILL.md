---
name: inbox-enrich
description: >
  Auto-scaling inbox processor — single-pass for 1-10 unprocessed files,
  parallel subagent dispatch for 11-100, cost-guarded confirm for 100+.
  Routes meeting recaps to meetings/, extracts entities, stubs missing
  people + company pages (capped), appends compiled-truth bullets, adds
  Timeline entries with citations, and rewrites plain-text mentions into
  wikilinks. The brain-run Phase 4 wrapper implements enumeration,
  routing, and subagent dispatch; this SKILL.md is the contract.
triggers:
  - "process inbox"
  - "drain inbox"
  - "enrich inbox"
  - "file inbox"
  - "clear inbox backlog"
  - "inbox processing"
  - "daily inbox"
  - "9 AM enrichment"
  - "email filing"
  - "meeting note processing"
  - any task touching ~/brain/inbox/*.md
mutating: true
writes_pages: true
writes_to:
  - meetings/
  - people/
  - companies/
  - deals/
  - inbox/ (wikilink rewrites + enriched: watermark — never delete)
  - .tasks/ (run summary)
---

# Inbox Enrich Skill (auto-scaling)

## What this skill does

The skill processes inbox/ captures into structured second-brain content:
file moves, entity stubs, compiled-truth appends, timeline entries, and
two-way backlinks. The behaviour **scales automatically with backlog size** —
the orchestrator dispatches parallel subagents when the queue is deep.

## Authoritative instruction set

Per-file enrichment rules live at `~/bin/prompts/inbox-enrich.md` — that
file is what each subagent (or the single-pass agent) reads. Auto-scaling
orchestration is implemented in `~/bin/brain-run` Phase 4. The tests in
`~/bin/lib/brain-run-tests-phase4.zsh` define the contract.

**Always read the prompt file fresh** at task start.

## Auto-scaling routing

The wrapper enumerates unprocessed files first, then routes by count:

| Count | Mode | Behaviour |
|---|---|---|
| 0 | exit | Log "inbox empty"; end_phase succeeded. No claude invocations. |
| 1-10 | single-pass | One `claude --print` invocation processes all of them inline. (Original behaviour.) |
| 11-100 | parallel | Split into batches of 10 (oldest first); spawn up to 10 concurrent subagents; queue excess. |
| 101+ | cost-guard | Estimate `count × $0.15`. Require explicit confirmation or `--force-large`. Refuse if estimate >$30 without `--force-large`. |

### "Unprocessed" definition

A file in `~/brain/inbox/*.md` is unprocessed iff ALL hold:

- Filename is not `README.md`
- Frontmatter has no `enriched: YYYY-MM-DD` line
- Frontmatter has no `skip-enrich` tag

### Cost guards

- **Estimate**: `count × $0.15 average` (Sonnet baseline). Logged before the run.
- **Estimate >$10**: Show the estimate; require explicit confirm (interactive)
  or `--force-inbox` flag (cron / non-interactive).
- **Estimate >$30**: Refuse to run unless `--force-large` flag passed.
  `--force-large` implies `--force-inbox`.
- **Actual cost**: Each subagent's `total_cost_usd` from its JSON output is
  recorded; rolled up into the run summary.

## Parallel mode behaviour

When count > 10:

1. Enumerate; sort by filename ascending (oldest first).
2. Split into batches of 10. Final batch may be shorter.
3. Spawn up to **10 concurrent** `claude --print` subagents.
   - Each subagent receives the standard prompt PLUS a `SUBAGENT_FILES:`
     directive listing exactly its batch.
   - Flags: `--max-turns 30 --model claude-sonnet-4-6 --permission-mode bypassPermissions --output-format json`.
   - Output JSON to `phase-4.batch-<N>.output.json`.
4. **Mid-run gate**: when `n_batches > 3`, the first wave is capped at 3
   batches (canary). After they complete, inspect their exit codes.
   If ANY failed (and not just max-turns), abort the run — queue the
   failed batches for split-in-half retry, but do not launch the
   remaining `n_batches - 3` batches.
5. **Failed batch retry**: a failed batch is retried ONCE with
   **split-in-half** (5 + 5 files). If either half fails again, those
   files are listed in the summary's failed-files section.
6. After all batches complete, the wrapper commits each successful batch
   (commit is handled by the brain-run wrapper, not by the agent).

## Per-file enrichment rules (unchanged)

See `~/bin/prompts/inbox-enrich.md` Steps 1-9. Invariants:

| Rule | Detail |
|---|---|
| Per-subagent cap | ≤ 10 files. |
| Routing | Meeting recaps (strict 3-test) → `meetings/`. Emails + docs stay in `inbox/`. |
| Stub creation | `mcp__gbrain__search` first; cap 50 people / 25 companies per subagent. |
| Compiled-truth | Append-only with `[Source: [[inbox/...]]]` citations. |
| Timeline | One line per file per target with citation. |
| Wikilinks | First-occurrence-only; skip code blocks and frontmatter. |
| Watermark | `enriched: YYYY-MM-DD` in frontmatter on every processed file. |

## Output

After the run, the wrapper writes:

```
~/brain/.tasks/inbox-run-YYYY-MM-DD-HHMM.md
```

Contents:
- Files unprocessed at start
- Mode chosen (single-pass / parallel)
- Batches executed
- Total cost (sum of per-batch `total_cost_usd`)
- Status (OK / PARTIAL)
- Per-batch rc + cost lines

A console summary is also printed (the same final block from the
original Step 9 of the prompt).

## Failure handling

| Scenario | Behaviour |
|---|---|
| 0 unprocessed | Exit clean; log "inbox empty". |
| Subagent max-turns | Treated as partial success; only files with watermark count as done. |
| Subagent rc != 0 (non max-turns) | Log batch; retry once with split-in-half. |
| ≥1 failure in first-3 canary | Abort run; remaining batches NOT launched. |
| Estimate >$10, no `--force-inbox` (non-interactive) | Refuse. |
| Estimate >$30, no `--force-large` | Refuse. |

## Invocation patterns

**Manual**: "process inbox", "drain inbox", "clear inbox backlog" → runs
`brain-run --weekly --no-mail --no-granola` (or equivalent inbox-only
mode). Auto-scaling applies.

**Daily 9 AM cron**: `~/bin/brain-daily-9am.sh` continues to call
`claude --print < ~/bin/prompts/inbox-enrich.md` directly. Single-pass
(≤10 files) — the cron is a daily drip, not a backlog clearer.

**Full sweep**: `brain-run --weekly --force-large` — bypasses both cost
guards (force-large implies force-inbox).

## Conflict resolution

The gbrain repo ships default skills (data-research, ingest,
meeting-ingestion). Per `~/.claude/CLAUDE.md`, **inbox-enrich wins** for
anything in `~/brain/inbox/`. Do not chain into or substitute the defaults.
