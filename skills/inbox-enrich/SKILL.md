---
name: inbox-enrich
description: >
  Process new captures in ~/brain/inbox/ — route meeting recaps to meetings/,
  extract entities, stub missing people + company pages (capped), append
  compiled-truth bullets under Open Threads / Recent Activity, add Timeline
  entries with citations, and rewrite plain-text mentions into wikilinks.
  Triggered by any task involving inbox/ files, email filing, meeting note
  processing, or the daily 9 AM ingestion cron. NEVER substitute a gbrain
  default ingestion skill (data-research, ingest, meeting-ingestion) for
  this workflow — they have different filing rules and citation patterns.
triggers:
  - "process inbox"
  - "enrich inbox"
  - "file inbox"
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
  - inbox/ (wikilink rewrites only — never delete)
---

# Inbox Enrich Skill

## Authoritative instruction set

The full, line-by-line instructions for this skill live at:

```
~/bin/prompts/inbox-enrich.md
```

That file IS the skill. This SKILL.md exists so the brain agent can
auto-discover the prompt and route to it. **Always read the prompt file
fresh at task start** — it's edited periodically and this summary may drift.

## When to trigger

- Any explicit user ask: "process inbox", "enrich inbox", "file inbox",
  "run inbox enrich", "do today's inbox", "process today's emails".
- Implicit triggers: a task that involves files inside `~/brain/inbox/`
  (filing emails, processing meeting notes that landed there, cleaning
  up after a Gmail collector run).
- The daily 9 AM cron's enrichment phase (`~/bin/brain-daily-9am.sh`).

## When NOT to trigger

- "Aggressive compiled-truth rewrites" — this skill APPENDS only.
  Full rewrites are a separate manual workflow run with explicit
  human approval (we ran one on 2026-05-13 across 21 top entities).
- Granola transcript imports — those land directly in
  `meetings/granola/` and don't go through `inbox/`.
- Calendar daily files — those live under `daily/calendar/` and
  have their own structure.

## Rules summary (canonical version is in the prompt file)

| Rule | Detail |
|---|---|
| **Process cap** | Up to 10 inbox files per run, oldest first. |
| **Routing** | Meeting recaps (real recap, no email metadata, no `email-` in filename) → `meetings/`. Emails + docs stay in `inbox/` for the wikilink rewrite pass. |
| **Entity extraction** | People + organisations from `### Contacts` / `### Mentioned organisations` sections; fall back to inferred prose mentions. |
| **Stub creation** | Use `mcp__gbrain__search` to find existing pages first; only stub when no match. Cap: ≤50 people, ≤25 companies per run. |
| **Skip filters** | Role addresses (`marketing@`, `info@`, etc.), common-provider domains (`gmail.com`, `outlook.com`, etc.), ERV internal (`@erv.io`). |
| **Compiled-truth** | **APPEND ONLY** to `## Open Threads` / `## Recent Activity` sections. NEVER replace existing content. Every appended line ends with `[Source: [[inbox/<filename-no-ext>]]]`. |
| **Timeline** | One line per inbox file per relevant target: `- YYYY-MM-DD: <event> [Source: [[inbox/<filename-no-ext>]]]`. Skip stubs. |
| **Wikilinks** | Rewrite plain-text mentions in the inbox file → `[[Display Name]]`. First occurrence only. Skip code blocks, frontmatter, existing `[[…]]` / `[Source: …]`. |
| **Hard rules** | Never delete inbox files (only `mv` meetings out). Never replace content (append only). Never invent facts. 30-turn ceiling — write what you have and print the partial summary. Do not commit (wrapper handles git). |

## Conflict resolution with gbrain default skills

The gbrain repo ships `skills/data-research/SKILL.md`, `skills/ingest/SKILL.md`,
`skills/meeting-ingestion/SKILL.md`, etc. Those have **different** filing rules,
citation formats, and entity-creation thresholds. Per `~/.claude/CLAUDE.md`,
`inbox-enrich` wins for anything touching `~/brain/inbox/` — do not chain into
or substitute the gbrain defaults.

## Invocation patterns

**Manual (interactive Claude Code session):**
> "Process today's inbox" — agent reads `~/bin/prompts/inbox-enrich.md` and
> executes against current inbox state.

**Cron (9 AM daily):**
```bash
# ~/bin/brain-daily-9am.sh submits this to the gbrain supervisor's shell handler
claude --print --model sonnet < ~/bin/prompts/inbox-enrich.md
```

The cron path uses Sonnet 4.6 for cost containment (~$0.10–0.50/day).
Manual passes can use Opus per the tiered model rule in `CLAUDE.md`.
