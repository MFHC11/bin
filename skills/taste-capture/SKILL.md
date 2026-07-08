---
name: taste-capture
description: >
  Use when Marcus signals that something crossed his taste bar and should shape
  future work: triggers "+taste", "save as taste", "this is taste" (a thing he
  likes), or "+anti" / "anti-pattern" (a thing to avoid). Captures the JUDGMENT
  (not just the artifact) into the Taste Index, routed to the right bucket.
  Gated: nothing is stored without one of these explicit signals.
triggers:
  - "+taste" / "save as taste" / "this is taste"
  - "+anti" / "save as anti-pattern"
mutating: true
model_default: frontier (compiling durable judgment routes frontier per governor)
---

# Taste Capture

Self-contained. Read fresh each run. No em dashes in anything written (Marcus rule).
Hub: `concepts/taste-index`. This skill feeds it.

## The gate (hard)

No signal, no storage. Only capture on an explicit `+taste` / `+anti` / "save as taste"
signal. Never auto-file a link or an idea because it looked useful. Useful once is not
durable. The selectivity is the point, so when in doubt, capture less.

## Steps

1. Identify the object of the judgment (the thing liked or rejected) and gather the
   reference: link, file path, draft, or the specific message being reacted to.
2. Draft the capture in the shape below. For `+anti`, lead with "What to avoid".
   ```
   What I liked:
   Why it matters:
   Anti-pattern (what to avoid / not copy blindly):
   How to apply:
   Domain / Tags:
   Reference:
   (bets only) Confidence + Revisit-by:
   ```
   Do not leave "Why it matters" or "How to apply" blank. If you cannot state them
   from context, ask Marcus one question rather than guessing. The judgment is the
   point; a bookmark already stores the link.
3. Route to the right bucket:
   - **Always-on rule** (cross-domain, must be in context every session, e.g. a hard
     writing or confidentiality rule): write a memory feedback file in
     `~/.claude/projects/-Users-marcusclover-brain/memory/` and add a one-line pointer
     to `MEMORY.md`, following the memory conventions (frontmatter, Why, How to apply).
   - **Domain taste** (aesthetic or judgment for a domain of work): append the capture
     to `~/brain/concepts/taste-<domain>.md` (writing, deals, lp-comms, product,
     design). Create the domain page from the same template if it does not exist, and
     add it to the register in `~/brain/concepts/taste-index.md`.
   - **Calibratable call** (a prediction that will resolve, e.g. an LP or market call):
     record it as a gbrain take with `kind=bet`, a confidence, and a resolve-by date
     (via the brain MCP `submit_job`/takes path, or note it on `concepts/taste-index`
     for the next dream cycle to log). These are scored later by the calibration
     scorecard.
4. Add or update a one-line pointer in `~/brain/concepts/taste-index.md` so the capture
   is discoverable from the hub register.
5. Confirm to Marcus in one line: what was captured, which bucket, and where it lives.

## Which domain?

writing, deals (investment judgment), lp-comms, product (demos / tooling / UX), design.
If none fit, propose a new domain slug and confirm with Marcus before creating the page.

## Notes

- The point is the judgment, not the artifact.
- taste-writing captures are read by the article-persona skill before every draft.
  Deals and lp-comms captures should likewise be read by their skills once those
  domains fill in.
- The dream cycle and daily may AUDIT the taste index (flag missing fields, unlinked
  pages, stale bets) but must never AUTHOR taste. Capture is human-initiated only.
- Ledger: append one JSONL line to
  `~/brain/.tasks/skill-evolution/taste-capture/ledger.jsonl` (create if missing) per
  the skill-evolution convention.
