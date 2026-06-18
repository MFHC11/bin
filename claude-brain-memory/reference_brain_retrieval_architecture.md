---
name: brain-retrieval-architecture
description: How gbrain retrieval actually works (why query returns empty on figures) + the brain-ask wrapper/skill built 2026-06-14 to fix it
metadata: 
  node_type: memory
  type: reference
  originSessionId: 60a3267c-1605-4a77-8cd3-fbe59bc265f6
---

Mapped gbrain 0.42's retrieval internals (`~/.bun/.../node_modules/gbrain/src`) on 2026-06-14 while making financials queryable. Key facts:

**Three separate channels, NOT fused for you:**
- `query`/`ask` (hybrid: vector + AND-keyword + RRF) and `search` (keyword only) run over `content_chunks` (embedded page bodies). RRF has NO score threshold that suppresses keyword hits (verified in hybrid.ts rrfFusionWeighted).
- `recall` runs over the separate `facts` table. **The main query/ask path NEVER consults facts.** You must call recall explicitly.

**Why `query` returns `[]` on numeric questions (the real root cause):**
1. AND-keyword brittleness: the keyword arm uses `websearch_to_tsquery` which ANDs every lexeme. One word absent from the chunk (a unit "dollars", filler "per month") zeroes the whole match. Dropping the stray word fixes it.
2. Embedding dilution: a chunk packed with many numbers (12-month table) has a washed-out vector that ranks below top-k. Smaller, single-metric chunks embed far better (proven: MOIC bullet list was retrievable, the multi-month burn table was not).
An empty `query` almost never means the data is absent. See [[pdf-pipeline-ingest-gap]].

**The Facts fence gotcha:** a page's `## Facts` fence (gbrain:facts:begin/end) only reaches the `facts` table via the DREAM CYCLE (`gbrain dream`, core/cycle.ts runExtractFacts) — there is no standalone reconcile CLI. AND `stripFactsFence({keepVisibility:['world']})` strips every `private` fact row from the embedded compiled_truth, so private facts are NOT searchable via query/search at all; they live only in the facts table, reachable only via `recall` (private rows return to local callers). => To make a figure query/search-findable, put it in the page BODY as prose, not (only) in the fence.

**What was built (durable, no gbrain core edits — Marcus chose wrapper+skill over a node_modules patch that `gbrain upgrade` would clobber):**
- `~/bin/brain-ask` — fans out gbrain query+search(+recall with --entity), fuses by normalised score (keyword weighted 1.0, query 0.7), down-ranks stub pages. Good for clean phrasings; a doubly-brittle phrasing where BOTH arms miss still struggles (that needs an OR-keyword core patch, deferred).
- `~/bin/skills/brain-ask/SKILL.md` + a CLAUDE.md Brain-First addendum — the retrieval DISCIPLINE for the MCP path: triangulate query+search(distinctive entity+metric words, drop units)+recall+read the page; cite the period.
- `companies/erv` and `companies/prosemino` now carry `## Latest financials` BODY prose (query-findable) + private Facts-fence rows (recall after next dream).
- pdf-to-brain PROMPT_VERSION v2: synthesis now emits a self-contained `## Key figures` block for future financial PDFs.

**Still open:** the financial Facts-fence rows on erv/prosemino reach `recall` only after the next `gbrain dream` (approval-gated). The brain-ask wrapper's ranking is imperfect for pathological phrasings.
