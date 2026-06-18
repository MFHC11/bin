---
name: queryable-financials-buildout
description: Ongoing buildout making brain figures queryable (Key figures prose + Facts fences). ERV/Prosemino + 16 portcos done 2026-06-14/15; emails + more to come
metadata: 
  node_type: memory
  originSessionId: 60a3267c-1605-4a77-8cd3-fbe59bc265f6
---

Goal (Marcus, 2026-06-14/15): make key information from financials, emails, and portfolio-company updates QUERYABLE. Details and numbers matter. Build out gradually.

**The pattern that works** (validated): for each entity, write TWO things to its canonical page:
1. A `## Key figures` BODY prose block: self-contained `- <Metric> (<entity>, <period>): <value>. [Source: <source-slug>]` lines. This is what makes figures query/search-findable (body prose embeds; the Facts fence does NOT, see [[brain-retrieval-architecture]]).
2. A `## Facts` fence (gbrain:facts:begin/end, columns: # | claim | kind | confidence | visibility | notability | valid_from | valid_until | source | context). Structured, period-aware; reconciled into the `facts` table by the DREAM cycle's extract_facts phase; reachable via LOCAL `gbrain recall <full-slug>` (and ~/bin/brain-ask --entity). Private rows are stripped from embeddings, so they need both the prose AND the fence.

**Done so far:**
- ERV Group + Prosemino financials (May/Apr 2026 mgmt accounts): companies/erv, companies/prosemino.
- 15 portfolio companies tracked (2026-06-15, Opus fleet, canary + 3 waves of 5): quino-energy, methanox, green-li-ion, redoxion, oort-energy, sention, super6, ecolectro, anthro-energy, immaterial-ltd, element30, blixt-tech, eutechtics, divigas, turnover-labs. (The 14 holdings carried in the ERV Group accounts + Turnover Labs, which is in live DD with a Jan-2026 LOI.) Sources mined: ERV mgmt accounts, Fund I annual statements + Q1 LP update, board minutes, shareholder updates, pitch decks. Append-only, fully cited, corrections file applied (Blixt EIC €6.5M, Immaterial £14.5M/$20M). Turnover Labs recorded as pre-investment (no fabricated ERV position). Commit 448040f.
- DROPPED from the portfolio list (2026-06-15, Marcus): **RFC Power** — unlikely ERV will invest. The companies/rfc-power.md Key figures + Facts (deck-sourced, valid brain content) were left in place but it is no longer tracked as a portco. Strip the page on request.

**Reconcile mechanics:** after writing fences, run `cd ~/brain && git add -A && git commit && gbrain sync && gbrain embed --stale` (prose becomes query-findable immediately) THEN a `gbrain-agentic dream` to reconcile the new fences into the facts table (recall). NOTE: the dream sync+synthesize phases fail on the #1570 pooler race ([[project_gbrain_dream_1570_race]]), but extract_facts (the phase we need) runs fine and reconciled 1600 facts on the 2026-06-14 run. The portfolio fences added after that dream still need a fresh dream to become recall-able.

**Next (gradual buildout):** portfolio-company EMAILS (round closes, board updates, KPI emails) via an inbox-enrich facts pass; then LPs, deals, and the rest. Same Key-figures-prose + Facts-fence pattern. See [[brain-retrieval-architecture]] and the pdf-to-brain v2 `## Key figures` synthesis output (future PDFs auto-emit it).
