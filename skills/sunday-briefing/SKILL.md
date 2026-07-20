---
name: sunday-briefing
description: >
  Generate Marcus's Sunday afternoon briefing for the week ahead. Synthesises
  HoldCo subscription status, Fund II LP active threads, NAV loan / financing
  state, calendar, inbox debt, meeting prep, watch list, patterns, and
  do-not-do list. Money-flow pages are read BEFORE calendar to prevent the
  calendar-bias failure mode documented in the 2026-05-17 postmortem. Output
  enforces commercial > strategic > operational priority hierarchy.
triggers:
  - "Sunday briefing"
  - "sunday briefing"
  - "weekly briefing"
  - "week ahead briefing"
  - "brief me for the week"
  - "chief of staff briefing"
  - "what's on this week"
  - "generate the briefing"
  - any task asking for a synthesis of last 7 days + next 7 days for ERV
mutating: true
writes_pages: true   # maintains concepts/erv-priority-ledger (the strategic layer)
writes_to:
  - .tasks/briefing-YYYY-MM-DD.md
  - .tasks/briefing-YYYY-MM-DD.html (when an HTML/readable version is requested)
  - concepts/erv-priority-ledger.md (reconciled + updated each run)
sources_required:
  priority_ledger:
    - concepts/erv-priority-ledger.md (READ FIRST, reconcile as Section 0, UPDATE after the brief)
  brain_pages:
    - companies/invicta-wealth-solutions.md
    - companies/lp-energy-revolution-ventures-limited.md
    - deals/fund-ii-lp-pipeline.md
    - deals/fund-ii-lp-pre-marketing-pipeline.md
  tasks:
    - tasks/active.md (Tier 1 Money in Motion section first)
  inbox:
    - last 7 days of inbox/*.md
    - prioritise files with HoldCo / KYC / DDQ / subscription / NAV / LP in filename or summary
  calendar:
    - marcus@erv.io, next 7 days (via mcp__claude_ai_Google_Calendar__list_events)
  daily_notes:
    - daily/calendar/YYYY/YYYY-MM-*.md (last 7 days, context only)
cost_estimate: ~$0.30-1.20 (Sonnet) or ~$1.20-2.00 (Opus)
model_default: sonnet (Opus for first-of-month or after a documented failure)
---

# Sunday Briefing Skill

## Authoritative instruction set

The full, line-by-line prompt for this skill lives at:

```
~/bin/prompts/sunday-briefing.md
```

That file IS the skill. This SKILL.md exists so the brain agent can
auto-discover the prompt and route to it. **Always read the prompt file
fresh at task start** — it's edited periodically and this summary may drift.

## When to trigger

- Any explicit user ask: "Sunday briefing", "weekly briefing", "brief me for the week", "chief of staff briefing", "what's on this week".
- Implicit: end-of-weekend prep, Sunday afternoon/evening session, or any request for a synthesis combining last week's events with the week ahead.

## When NOT to trigger

- **Mid-week status check** — use a lighter ad-hoc query, not the full briefing.
- **Single-LP deep dive** — use brain query / get_page for that one LP.
- **Portfolio company update** — use a portfolio-specific synthesis, not the briefing format.
- **Granola transcript review** — has its own workflow.

## Two-layer model (added 2026-06-14)

The briefing runs two layers: a **strategic layer** (the Priority Ledger, `concepts/erv-priority-ledger`, the ~8-10 ERV "rocks", maintained by the CoS agent) and an **operational/EA layer** (`tasks/active.md`, inbox, calendar). Lead with the ledger, retain the full EA picture. **Freshness rule:** a fresh high-stakes item outranks a well-documented routine one; the brief reflects Marcus's priority stack, not brain-coverage density. Be proactive: surface risks/deadlines Marcus has not flagged, and ask employee-grade follow-up questions when he names a new priority.

## Mandatory data-pipeline order (do NOT shortcut)

The default calendar-first pipeline produces process bias and inverts Marcus's priority hierarchy. **Run in this exact sequence:**

-1. **Gap detection** (2026-07-19): if the last `.tasks/briefing-*.md` is older than 9 days, widen all lookbacks to the full gap and retitle the lookback section "Since the Last Brief (N days)".
0. **Priority Ledger first** (`concepts/erv-priority-ledger`): reconcile every rock (moved? STALE? deadline within 14 days?). Report in Section 0; write updates back after the brief.
1. **Money-flow pages first** (read in full, do not search/skim):
   - `companies/invicta-wealth-solutions.md` — every open HoldCo subscription
   - `companies/lp-energy-revolution-ventures-limited.md` — HoldCo round status
   - `deals/fund-ii-lp-pipeline.md`
   - `deals/fund-ii-lp-pre-marketing-pipeline.md`
2. **Silence-age check** — for every Pledged / Qualified Opportunity LP, when was the last inbound and has it been answered? Anything 3+ days unanswered → Inbox Debt priority.
3. **`tasks/active.md`** — Tier 1 Money in Motion section first.
4. **Inbox scan (last 7 days)** — read all files with LP / HoldCo / KYC / DDQ / subscription / NAV / anchor in filename or summary, regardless of recency rank.
5. **Calendar (next 7 days)** — LAST, after the commercial picture is built.
6. **Daily notes (last 7 days)** — context only.
7. **Cross-reference** attendees and senders against `people/` and `companies/` pages.

## Priority hierarchy (enforce in Top 5 ranking)

| Tier | Definition |
|---|---|
| **Tier 1** | Commercial actions affecting cash or fund close THIS WEEK — HoldCo subscriptions in flight, NAV loan / financing in execution, Fund II LP DDQs or term sheets with deadlines, LP meetings where dataroom or subscription is the next gate |
| **Tier 2** | Top 3 strategic LP conversations with specific imminent moves |
| **Tier 3** | Strategic relationships (Centrica, Caterpillar, anchor LPs) — important but not money this week |
| **Tier 4** | Operational / process (IQ-EQ, fund admin, governance) — only surface if blocking Tier 1 |

**Hard rule:** Process items NEVER rank above commercial items unless they unblock cash.

## Output format spec

Write to `~/brain/.tasks/briefing-YYYY-MM-DD.md` AND display inline. Sections in this exact order:

1. `# Sunday Briefing — [Date]`
1.5. `## Section 0 — Strategic Priority Ledger` — one line per rock (status, what moved / STALE / deadline), then "This week's strategic focus" (1-3 rocks). Comes BEFORE Money in Motion. Update the ledger page after the brief.
2. `## Money in Motion This Week` — three subsections: HoldCo Subscriptions Live, Fund II LP Active Threads, Financing / NAV Loan
3. `## Last Week — The Three Things That Mattered` — exactly 3 bullets, 1-2 sentences each
4. `## This Week — Top 5 Priorities` — ranked Tier 1 > 2 > 3 > 4
5. `## Owed Responses (Inbox Debt)` — LP/commercial first by silence age, max 10
6. `## Meeting Prep (Next 7 Days)` — Tier 1 meetings first regardless of calendar order, each entry under 60 words
7. `## Watch List` — max 5 items, one line each
8. `## Patterns the Brain Spotted` — 1-3 patterns; AT LEAST ONE must be a money-flow pattern
9. `## What I Should NOT Do This Week` — 1-3 items

**Style:** Under 800 words. No em dashes. No filler. Direct assertion. ERV thesis vocabulary (force / light / heat / compute / matter) where relevant.

## Pre-finalisation checklist (mandatory)

- [ ] Priority Ledger read FIRST and reconciled; Section 0 present before Money in Motion
- [ ] Every Top Priority traces to a ledger rock (or is added as a new rock)
- [ ] Freshness rule applied; at least one proactive risk/deadline Marcus did not flag surfaced
- [ ] Ledger page updated after the brief (status, last-moved, change log)
- [ ] Money-flow pages read BEFORE calendar
- [ ] Every QO/Pledged LP checked for silence age
- [ ] `## Money in Motion` is Section 1
- [ ] HoldCo subscriptions visible (or explicitly stated as none-live)
- [ ] Top 5 follows Tier 1 > 2 > 3 > 4
- [ ] Patterns section includes a money-flow pattern
- [ ] **Forcing question:** "If Marcus acts on the top 5 in order, will it move money into ERV faster?" If no, restructure.

## Failure modes (from 2026-05-17 postmortem)

| Failure mode | Symptom | Prevention |
|---|---|---|
| **Calendar bias** | Process meetings (IQ-EQ) rank above commercial threads | Money-flow pages read FIRST, calendar LAST |
| **Inbox-recency framing** | "Owed responses" scans last 7 days of files instead of LP pipeline × silence age | Step 2 silence-age check is mandatory |
| **Priority rubric content-agnostic** | Calendar urgency beats commercial weight | Tier 1-4 hierarchy enforced in Top 5 |
| **No traversal from money-flow pages** | HoldCo subscriptions invisible | Step 1 mandatory full-read of 4 money-flow pages |
| **Visual weight inverted** | Meeting prep section longer than Money in Motion | Money in Motion is Section 1; meeting prep entries capped 60 words |
| **30-turn ceiling hit** | Briefing incomplete | Write partial briefing with explicit "incomplete — covered through Step N" header rather than nothing |

## Model routing (governor architecture, 2026-07-19)

Cost gates are void on Max plan. The governor routes: frontier session model (Opus 4.8 / Fable 5) when run in-session (the brief is compiled judgment); Sonnet acceptable for a future cron run. 2026-07-19 additions: close-critical-path test in Tier 1, portfolio distress radar (step 4.5), capital-channel sweep (step 4.6), Delegable line in Top 5, Compounding section (max 2 lines), mandatory CEO-readable PDF render sent as attachment.

## Conflict resolution with gbrain default skills

The gbrain repo ships `data-research`, `ingest`, and `meeting-ingestion` skills. Those have different filing rules and synthesis patterns. **`sunday-briefing` wins for any task asking for a weekly synthesis briefing** — do not chain into or substitute the gbrain defaults. The Sunday briefing writes to `.tasks/` plus one brain page: `concepts/erv-priority-ledger` (reconciled each run).

## Invocation patterns

**Manual (interactive Claude Code session):**
> "Generate my Sunday briefing" — agent reads `~/bin/prompts/sunday-briefing.md` and executes against current state.

**Future cron (not yet wired):**
```bash
# ~/bin/brain-sunday-1700.sh (proposed)
claude --print --model sonnet < ~/bin/prompts/sunday-briefing.md
```

## Postmortem reference

Full diagnostic of the failure modes encoded above:
`~/brain/.tasks/briefing-2026-05-17-postmortem.md`
