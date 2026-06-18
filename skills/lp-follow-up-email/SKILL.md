---
name: lp-follow-up-email
description: >
  Draft a high-signal LP follow-up email for a specific LP. Pulls Fund II
  top-line (anchor + first close + co-investors), forward Fund II deal
  pipeline, Fund I commercial winners only, platform (Prosemino + British
  Land), and network (Plexus). Strips fund mechanics (NAV/MOIC/IRR),
  distress (Divigas/Ecolectro), and macro caveats. Voice: first-person,
  named third parties unexplained, concrete proof points, no headers in
  the email body. The skill ALWAYS runs a clarification gate first — like
  a junior analyst checking status, background, and intent before drafting.
  Closes on the specific relationship thread from the last meeting (not
  a generic invite).
triggers:
  - "LP follow-up email"
  - "lp follow up"
  - "follow-up email to <LP>"
  - "draft LP follow-up"
  - "brief for <LP name>"
  - "LP update email"
  - "Fund II email to <LP>"
  - "write a note to <LP>"
  - "send an update to <LP>"
  - any task that drafts a Fund II / LP-facing follow-up email
mutating: true
writes_pages: false
writes_to:
  - drafts/lp-follow-up-emails/YYYY-MM-DD-<lp-slug>.md
sources_required:
  brain_pages:
    - companies/lp-<slug>.md  # the target LP page
    - companies/centrica.md  # Fund II anchor
    - deals/fund-ii-lp-pipeline.md
    - deals/fund-ii-lp-pre-marketing-pipeline.md
    - companies/anthro-energy.md
    - companies/green-li-ion.md
    - companies/immaterial.md
    - companies/blixt-tech.md
    - companies/turnoverlabs.md  # Fund II carbon utilisation (in DD)
    - companies/super6.md  # Fund II supercapacitors for data centres
    - companies/methanox.md  # Prosemino — LNG methane slip
    - companies/eutechtics.md  # Prosemino — fine chemical platform
  meetings:
    - granola/* and meetings/* for the target LP, last 90 days
    - inbox/*-<lp-firstname>-* if present (recent meeting notes)
  tasks: []
cost_estimate: ~$0.30-0.80 (Sonnet) or ~$1.20-2.00 (Opus for top-tier LP first-touch)
model_default: sonnet
---

# LP Brief Skill

## Authoritative instruction set

The full prompt for this skill lives at:

```
~/bin/prompts/lp-follow-up-email.md
```

That file IS the skill. This SKILL.md exists so the brain agent can
auto-discover the prompt and route to it. **Always read the prompt file
fresh at task start** — it is edited periodically and this summary may drift.

## When to trigger

- Any explicit ask naming an LP: "brief for Paulius", "LP update for Saphira",
  "write a note to Jean-Damien", "send a Fund II update to Carbon Equity".
- Implicit: post-meeting follow-up to an LP where the user says
  "send him a note" / "send her an update" / "follow up to that one".
- Do NOT fire for: internal portfolio updates, Sunday briefings, DDQ responses,
  formal LP letters (these are different genres — refer them to their own skills).

## Clarification gate — MANDATORY before drafting

The agent runs as a junior analyst. Before any draft is produced, it must
confirm enough context to write the brief responsibly. The gate has three
checks; if any check fails, the agent **stops and asks the user**.

### Check 1 — Target LP identity

- Resolve the LP name to a brain page slug (`companies/lp-<slug>.md` or
  `companies/<slug>.md` if corporate).
- If the LP cannot be resolved (>1 match, no match, ambiguous spelling),
  the agent asks: "Which LP is this — `<candidate 1>` or `<candidate 2>`?"
  with the slugs surfaced so the user can disambiguate.

### Check 2 — Status + recent context

The agent must surface what the brain knows about the LP:

| Field | Where it lives |
|---|---|
| Pipeline stage | `deals/fund-ii-lp-pipeline.md` (Pledged / QO / QL / Discovery / Passed) |
| Ticket size | LP page + pipeline page |
| Manager | LP page + pipeline page |
| Last meeting / call | `granola/`, `meetings/`, `inbox/*-<firstname>-*` (last 90 days) |
| Last email touch | LP page timeline |
| Open action items | LP page + tasks |
| Stated thesis / interests | most recent meeting note |
| Concerns raised | most recent meeting note |

If any of stage / meeting / open-action / intent are missing or ambiguous,
the agent asks the user — phrasing examples:

- "I don't see a meeting note for <LP> in the brain. When did you last
  speak with them, and what was the substance?"
- "<LP> is in the pipeline at <stage> but the last touchpoint is <date>
  (>30 days). Is this a re-engagement nudge, or has there been a recent
  call I should pull notes from?"
- "I see two threads — <thread A> on <topic> and <thread B> on <topic>.
  Which is this brief picking up from?"

### Check 3 — Intent of THIS brief

The agent must know which of the following the brief is for, because each
shapes voice, depth, and the close:

| Intent | Voice tilt | Close |
|---|---|---|
| First introduction (cold→warm) | Confident, name-heavy, broad | "Worth a 30 min call?" |
| Post-meeting follow-up | Picks up specific threads from the meeting | The action agreed in the meeting |
| DD follow-up | Specific answers to their questions | Next DD artefact / reference call |
| Pre-close push | Urgency: dates, allocation, FOMO | "Want to lock in a size?" |
| Pledged → docs handoff | Operational | "Sending docs to your personal email; confirm size + entity" |
| Committed LP update | Reporting feel but still selective | "Catch up at <event>" |
| Cold nudge / dormant LP wake-up | Light, recent-news angle | "Worth reconnecting?" |

If the user has not stated intent, the agent asks:
"What's the purpose of this brief — post-meeting follow-up, DD response,
pre-close push, or general update?"

The agent presents what it found from the brain BEFORE asking gap-fill
questions. Users should never have to type something the brain already knows.

## Drafting rules (full set in the prompt file)

### Mandatory data-pipeline order
1. Fund II top line — anchor (named ONLY as "a FTSE-100 energy company"; never Centrica, see hard rules) + first close date + co-investors
2. Fund II forward pipeline — sector-level deal categories (specific names
   only if portco is already public or LP is past LOI)
3. Fund I winners only — top 4–5 portcos by recent dollar/customer signal
4. Platform — Prosemino capacity + British Land
5. Network — Plexus community
6. LP-specific filter applied to all five sections

### Hard rules
- ⛔ Never disclose the Fund II anchor's name (Centrica), incl. "British Gas" / "British Gas parent", to anyone without Marcus's explicit per-recipient approval. Always write "a FTSE-100 energy company". (Hard rule, 2026-06-18.)
- ❌ Never mention writedowns, distress, NAV flatness, macro headwinds
- ❌ Never use "we're working on" / "exploring" / "in discussions" — replace
  with the most recent concrete event
- ❌ Never list more than 5 portcos in the commercial momentum section
- ❌ Never explain who Sanmina / Vattenfall / UBE / ArcelorMittal / Moelis /
  Ord Minnett / British Land are — assume sophisticated reader
- ❌ Never use MOIC / IRR / DPI / TVPI / NAV in the body
- ❌ Never include "Subject:" or formal email signature unless the user asks
  — return the body block, the user wraps it however they send it
- ✅ Every dollar figure must resolve to a brain source — flag any number
  that doesn't
- ✅ Voice: first-person ("we" / "I"), contractions, named third parties
  unexplained, no jargon
- ✅ The close is **context-driven, not formulaic** — pull from the actual
  meeting thread (action agreed, content promised, intro offered, follow-up
  cadence agreed, question now answerable). Only fall back to a generic
  invite (lab visit, Plexus access) if no real meeting thread exists.

### Self-audit before output
1. Quote-check every dollar figure against the brain; flag stale numbers
2. Confirm no distressed portcos (Divigas, Ecolectro currently) named
3. Confirm Fund II anchor status is current (last update on
   `companies/centrica.md` ≤ 14 days)
4. Confirm the close action references the actual meeting note, not a default
5. Apply known corrections from `~/bin/prompts/lp-follow-up-email-corrections.md`
   (e.g. Blixt = **EIC €6.5M** not EIB €5M; Immaterial Series A2 total =
   **£14.5M / $20M** with UBE new + JERA follow-on + ArcelorMittal from
   earlier tranche; Anthro revenue $15M / $8M product)

## Output

The brief is written to:

```
~/brain/drafts/lp-follow-up-emails/YYYY-MM-DD-<lp-slug>.md
```

with frontmatter:

```yaml
---
type: lp-follow-up-email
lp: <LP slug>
intent: <intent value>
written_by: lp-follow-up-email skill
written: YYYY-MM-DD
status: draft
---
```

The body of the file is the email body, ready to copy-paste into Gmail.
A "working notes" section below shows what the skill pulled, what
corrections it applied, and what it flagged for the user's eye.

## Failure handling

| Scenario | Behaviour |
|---|---|
| LP not in brain | Ask user; do not proceed with a placeholder |
| No meeting note found | Surface the gap; ask user for the meeting context before drafting |
| Conflicting figures (brain vs. corrections file) | Use corrections file; flag the conflict in working notes |
| Intent unstated | Ask before drafting |
| Distressed portco accidentally pulled | Self-audit removes it before output |

## Invocation patterns

**Manual**: `/lp-follow-up-email <LP name>` or "draft an LP follow-up to X" / "write a note to X".
Always interactive — the clarification gate runs every time.

**No cron / no automation** — this skill is human-initiated only.
