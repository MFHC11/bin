---
name: brain-ask
description: >
  Robust retrieval discipline for detailed/numeric/factual questions against
  the gbrain brain (financials, portfolio metrics, valuations, dates, exact
  figures). gbrain's `query` (semantic) returns EMPTY or weak results for some
  phrasings because its keyword arm is AND-based (one absent word zeroes the
  match) and number-dense chunks embed weakly. NEVER conclude "the brain
  doesn't know" from a single empty query. Triangulate across query + search +
  recall + reading the page.
triggers:
  - "what is the <metric/figure/number>"
  - "how much / how many / what was the balance / burn / NAV / valuation / revenue"
  - any question expecting an exact figure, date, or financial detail
  - any time a `query` call returns [] for something that plausibly exists
mutating: false
---

# brain-ask: triangulated retrieval for figures and details

## Why this exists
`mcp__..._brain__query` (hybrid/semantic) is the default, but it has two failure
modes on detailed/numeric questions:
1. **AND-keyword brittleness** — its keyword arm uses `websearch_to_tsquery`,
   which ANDs every lexeme. One word not present in the chunk (a unit like
   "dollars", a filler like "per month") makes the whole query return nothing.
2. **Embedding dilution** — a chunk packed with many numbers (a 12-month table)
   has a washed-out vector that ranks below the top-k, so semantic recall misses
   it even though the figure is right there.

A `[]` from `query` almost never means the data is absent. It means you used the
wrong phrasing or channel.

## The discipline (do ALL that apply, then synthesise)
1. **Run `search` (keyword) with 2-3 DISTINCTIVE words**, not a full sentence.
   Use the entity + the metric noun: `search "intercompany loan Prosemino"`,
   `search "net burn"`, `search "Tranche 1"`. Drop stopwords and units
   ("per", "month", "dollars", "current") — they zero out AND-tsquery.
2. **Run `query` (semantic)** for the natural-language phrasing too. If it
   returns `[]`, re-run with fewer / different words. Try the metric's synonyms
   (burn / cash burn / runway; loan / payable / intercompany).
3. **Run `recall(entity=<slug>)`** for the relevant entity (e.g. `erv`,
   `prosemino`). The facts table holds structured, period-aware figures that the
   embedding channels never see (facts are a separate channel; `query` does not
   consult them). `recall` returns private facts to local callers.
4. **Read the actual page.** Entity pages carry a `## Latest financials` prose
   block; pdf-to-brain source pages carry `## Key figures` + the management
   accounts. `get_page("companies/erv")` / the relevant `sources/...` page is
   often the fastest ground truth.
5. **Always cite the source page and the period** (figures change month to
   month; name which management-accounts period you are quoting).

## CLI shortcut
`~/bin/brain-ask "<question>"` fans out `gbrain query` + `gbrain search`, fuses
by normalised score (keyword-weighted, stubs down-ranked), and prints the top
pages. Add `--entity <slug>` to also pull `recall` facts. Use it from a shell;
inside an MCP session, run the channels yourself per the discipline above.

## Known figure homes (ERV)
- `companies/erv` `## Latest financials` — ERV Group NAV, cash, burn, net
  assets, raise tranches, portfolio MOICs (May + April 2026).
- `companies/prosemino` `## Latest financials` — ERV↔Prosemino intercompany loan
  (current $3.317M, supersedes the outdated £2.7M April planning figure),
  Prosemino portfolio NAV/MOIC/burn.
- `sources/2026-06-12-attachment-erv-group-may-26-management-reports` and the
  April equivalent — full management accounts (tables + per-page synthesis).

## Anti-pattern
Do NOT answer a figure question from the first page semantic `query` happens to
return, and do NOT say "the brain doesn't have it" after one empty query. That
is exactly how a stale figure (the £2.7M planning number) gets quoted over the
live one ($3.317M). Triangulate, then cite the period.
