---
name: skill-evolve
description: >
  Continuous skill optimization via MCE (Meta Context Engineering).
  Bi-level loop: log execution outcomes, analyse failure patterns via
  agentic crossover over version history, propose targeted revisions,
  validate against pressure scenarios, promote the winner.
  Use when a skill underperforms, after a postmortem, when asked to
  "evolve", "optimise", or "improve" a skill, or on a periodic review
  cadence. Also use after any skill execution to log the outcome.
triggers:
  - "evolve skill"
  - "optimise skill"
  - "optimize skill"
  - "improve skill"
  - "skill not working"
  - "review skill performance"
  - "skill evolution"
  - "log skill outcome"
  - "MCE"
  - "skill postmortem"
  - any postmortem or failure analysis of a skill execution
mutating: true
writes_to:
  - ~/bin/skills/*/
  - ~/.claude/skills/*/
  - ~/brain/.tasks/skill-evolution/
---

# Skill Evolution — MCE Applied

Operationalises the MCE paper (Ye et al., Peking University, arXiv 2601.21557)
for Marcus's skill system. Skills are treated as learnable objects that improve
through a (1+1)-Evolution Strategy: propose one revision, validate it, keep
whichever version scores higher.

## Two Modes

### Mode 1: Log (after any skill execution)

Append one entry to the skill's evolution ledger. This is the data that
makes future evolution possible — without logs, crossover has nothing
to reason over.

### Mode 2: Evolve (on demand or periodic review)

Full MCE cycle: analyse history → crossover → revise → validate → promote.

---

## Mode 1: Log Execution Outcome

Run this at the end of every skill execution. One JSONL line, append-only.

### Ledger location

```
~/brain/.tasks/skill-evolution/<skill-name>/ledger.jsonl
```

### Entry format

```json
{
  "ts": "2026-05-26T14:00:00Z",
  "version": 1,
  "outcome": "success|partial|fail",
  "turns": 28,
  "cost_usd": 0.42,
  "notes": "what worked, what failed, specific failure mode if any",
  "files_touched": 7,
  "trigger": "process inbox"
}
```

### Required fields

| Field | Source |
|---|---|
| `ts` | ISO-8601 now |
| `version` | Current version number from `versions/current` |
| `outcome` | `success` (all goals met), `partial` (some goals met), `fail` (wrong output or aborted) |
| `notes` | One sentence minimum. For `partial`/`fail`: what specifically went wrong. For `success`: what went well that should be preserved. |

Other fields are optional but valuable for trend analysis.

### Procedure

1. Create `~/brain/.tasks/skill-evolution/<skill-name>/` if it doesn't exist.
2. If no `versions/` directory exists, snapshot the current SKILL.md as `versions/v1.md` and write `1` to `versions/current`.
3. Append the JSONL entry to `ledger.jsonl`.
4. If a postmortem exists (e.g. `~/brain/.tasks/briefing-*-postmortem.md`), reference its path in `notes`.

---

## Mode 2: Full Evolution Cycle

The MCE algorithm adapted for our system. Five phases, strictly ordered.

### Phase 1 — Harvest

Read the full history for the target skill:

1. `ledger.jsonl` — all execution entries
2. `versions/` — all prior SKILL.md snapshots
3. Any referenced postmortems or failure analyses
4. The current live SKILL.md

Compute summary statistics:
- Success rate (last 10 runs, last 30 runs, all-time)
- Most common failure modes (group by `notes` themes)
- Cost trend (is it getting more expensive?)
- Turn trend (is it getting slower?)

**Output**: Write `~/brain/.tasks/skill-evolution/<skill-name>/analysis-YYYY-MM-DD.md`

### Phase 2 — Agentic Crossover

This is the core MCE mechanism. The meta-agent reasons over the full
history to synthesise an improved skill. Not mechanical recombination —
deliberative reasoning about what works and what doesn't.

**Crossover prompt structure:**

```
You are evolving a skill that has been executed N times.

CURRENT SKILL (version K):
<full SKILL.md>

EXECUTION HISTORY (most recent 20 entries):
<ledger entries>

FAILURE PATTERNS:
<grouped failure modes from Phase 1>

SUCCESSFUL PATTERNS:
<what consistently works>

PRIOR VERSIONS THAT SCORED HIGHER:
<any version with better success rate than current>

YOUR TASK:
1. Identify which parts of the current skill cause failures
2. Identify which elements from successful runs to preserve
3. Propose SPECIFIC changes — not vague improvements
4. Each change must cite the ledger entry or failure pattern it addresses
5. Do not change things that are working
```

**Rules for the crossover agent:**
- Every proposed change must cite evidence from the ledger
- "Seems like it could be better" is not evidence — show the failure entry
- Preserve elements that correlate with successful runs
- If a prior version had higher success rate, explain what it had that was lost

**Output**: Write crossover reasoning to `~/brain/.tasks/skill-evolution/<skill-name>/crossover-YYYY-MM-DD.md`

### Phase 3 — Revise

Write the new SKILL.md version based on Phase 2's crossover analysis.

1. Read the crossover analysis
2. Apply each change, preserving everything else
3. Snapshot to `versions/v{K+1}.md`
4. Update `versions/current` to `K+1`
5. **DO NOT overwrite the live SKILL.md yet** — that happens in Phase 5

### Phase 4 — Validate

Run pressure scenarios comparing old vs new version. Adapts the
writing-skills TDD approach.

**For discipline/process skills (inbox-enrich, sunday-briefing):**
- Replay the 3 most recent failure scenarios from the ledger
- Run 2 edge cases that the crossover specifically addressed
- Score: does the new version's instructions prevent the documented failures?

**For output skills (lp-follow-up-email, briefings):**
- Generate output under both versions for the same input
- Compare against the known-good criteria (corrections files, postmortems)
- Score: does the new version produce better output on historical failures?

**Scoring**: Simple pass/fail per scenario, then:
```
val_score = scenarios_passed / total_scenarios
```

**Decision rule ((1+1)-ES):**
```
if new_val_score > old_val_score:
    promote new version
elif new_val_score == old_val_score AND new addresses a real failure:
    promote new version (tiebreak: prefer the one that fixes a known bug)
else:
    keep old version, log the failed evolution attempt
```

### Phase 5 — Promote or Reject

**If promoting:**
1. Copy `versions/v{K+1}.md` over the live SKILL.md
2. Append to ledger: `{"ts": "...", "event": "evolution", "from": K, "to": K+1, "val_score": 0.8, "changes": "summary"}`
3. If the skill has an authoritative prompt file (e.g. `~/bin/prompts/inbox-enrich.md`), update that too — the SKILL.md is the contract, the prompt file is the implementation

**If rejecting:**
1. Keep live SKILL.md unchanged
2. Append to ledger: `{"ts": "...", "event": "evolution_rejected", "candidate": K+1, "val_score": 0.4, "reason": "..."}`
3. The failed version stays in `versions/` for future crossover reference — failures are data too

---

## Directory Structure

```
~/brain/.tasks/skill-evolution/
  inbox-enrich/
    ledger.jsonl              # Append-only execution log
    versions/
      current                 # Plain text: "3"
      v1.md                   # Original SKILL.md snapshot
      v2.md                   # First evolution
      v3.md                   # Current
    analysis-2026-05-26.md    # Phase 1 output
    crossover-2026-05-26.md   # Phase 2 output
  sunday-briefing/
    ledger.jsonl
    versions/
      ...
  lp-follow-up-email/
    ledger.jsonl
    versions/
      ...
```

---

## When to Evolve

| Trigger | Action |
|---|---|
| After every skill execution | Mode 1: Log outcome |
| Postmortem written | Mode 2: Full cycle targeting that skill |
| 5+ partial/fail entries since last evolution | Mode 2: Full cycle |
| Monthly review | Mode 2: Full cycle on all skills with >5 runs |
| User says "evolve/optimise/improve skill X" | Mode 2: Full cycle |

---

## Evolution Principles (from MCE)

1. **Skills are learnable objects** — not sacred documents. Every version is a hypothesis to be tested.
2. **No revision without evidence** — the ledger is the source of truth. Gut feelings about "what might be better" are not crossover.
3. **(1+1)-ES** — one candidate at a time, keep the winner. Simple beats clever.
4. **History is the search space** — prior versions that scored higher are valid crossover parents. Don't throw away what worked.
5. **Failures are data** — rejected evolutions stay in `versions/` because future crossover may recombine their good elements with other improvements.
6. **Context function, not template** — skills produce context as flexible files and instructions, not rigid schemas. The MCE paper showed unconstrained context representations outperform structured ones by 5.6-53.8%.

---

## Bootstrap: First Run on an Existing Skill

For skills that predate this system:

1. Create `~/brain/.tasks/skill-evolution/<skill-name>/versions/`
2. Copy current SKILL.md to `versions/v1.md`
3. Write `1` to `versions/current`
4. Backfill ledger from existing run logs:
   - `~/brain/.tasks/inbox-run-*.md` → inbox-enrich entries
   - `~/brain/.tasks/briefing-*.md` → sunday-briefing entries
   - Postmortems count as `fail` or `partial` with detailed notes
5. Run Mode 2 Phase 1 (Harvest) to establish the baseline

---

## Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| Evolving without logging first | Crossover with no history = guessing, not engineering |
| Changing things that work | MCE principle: preserve successful patterns. Only change what the ledger says is broken |
| Skipping validation | An untested revision is just an opinion. The (1+1)-ES gate exists for a reason |
| Evolving after every single failure | Noise. Wait for patterns (5+ entries). One failure could be bad input, not bad skill |
| Rewriting from scratch | Evolution, not revolution. Crossover recombines; it doesn't start over |
| Ignoring rejected versions | Failed candidates contain partial insights. Future crossover should see them |
