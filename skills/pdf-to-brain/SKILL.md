---
name: pdf-to-brain
description: >
  Convert a chart/table-heavy PDF (consulting decks, market reports, dataroom docs)
  into a single rich, brain-ready markdown page in sources/, capturing what charts and
  tables ARGUE via a per-page Claude vision pass — not just transcribing text like
  pdftotext. Produces a Key-insights synthesis + per-page figure-insight blocks +
  reconstructed markdown tables. Idempotent via content_hash; stages for brain-sync.
  Implemented as a deterministic script (~/bin/pdf-to-brain), NOT a prompt-driven session.
triggers:
  - "pdf to brain"
  - "convert this pdf"
  - "ingest this deck"
  - "ingest this report into the brain"
  - "extract insights from this pdf / report"
  - any task converting a *.pdf into a sources/ page
mutating: true
writes_pages: true
writes_to:
  - sources/                                  # the synthesised page
  - sources/pdf/                              # the moved source PDF (gitignored)
  - .tasks/skill-evolution/pdf-to-brain/      # ledger (gitignored, local-only)
cost_estimate: "$0 marginal (Max-plan CLI). Wall-clock ~1 min/vision page; 60–90 min for a ~150pp deck."
model_default: "sonnet (per-page vision) + opus (doc synthesis)"
---

# pdf-to-brain

Turns a PDF into one finished `sources/` page that holds both the literal content
(tables transcribed to markdown, numbers read off charts) and the interpreted meaning
(per-figure **Insight:** lines + a doc-level **Key insights** synthesis). Built for decks
where the point lives in the picture, where plain `pdftotext` produces orphaned fragments.

## How to run

```bash
~/bin/pdf-to-brain "<path/to.pdf>"                 # full deck → sources/<date>-<slug>.md
~/bin/pdf-to-brain "<path>" --dry-run              # route table + split, no model calls
~/bin/pdf-to-brain "<path>" --pages 3,11-16        # subset (writes <slug>.SAMPLE.md)
~/bin/pdf-to-brain "<path>" --sample 8             # first 8 in-scope pages
~/bin/pdf-to-brain "<path>" --sync                 # run brain-sync after staging
~/bin/pdf-to-brain "<path>" --force                # ignore cache + content_hash skip
```
Key flags: `--simple` (force pure-python text extraction, no vision/Claude),
`--force-vision` (force the vision pipeline), `--concurrency N` (default 3),
`--route-threshold N` (prose char floor, default 1400), `--max-pages N` (guard, default 400),
`--out PATH`, `--verbose`. `--dry-run` prints the per-page route table **and** the doc-level
SIMPLE/VISION decision.

## Document triage (deck vs report)

Before any heavy work, the whole PDF is classified. A page is "chart/figure" if it has a
real embedded figure (raster coverage ≥ 0.12), is a sparse slide (< 700 chars), or is a
dense **vector** chart/table with little text (≥ 40 drawings AND < 1500 chars — the clause
that separates a vector table slide from a *designed text report* page, which has many
decorative drawings but high text + no raster). If fewer than **30%** of pages are
chart/figure, the PDF is a **text document** → **SIMPLE mode**: a pure-python `pymupdf4llm`
extraction, **no rasterise, no vision, no Claude** (≈5 s for a 44-page report). Only
chart/table-heavy decks take the per-page vision pipeline. Tuned on real decks (frac ≥ 0.44)
vs reports (≤ 0.24). Override with `--simple` (force text) or `--force-vision`.

## Architecture (vision mode)

Deterministic Python script, stages: **route → rasterize → per-page vision → synthesis →
assemble → stage**.
- **Route** (pymupdf): vision-pass by default; text-only only for genuine wall-of-prose
  pages (`chars ≥ 1400 AND drawings ≤ 4 AND raster_cover < 0.03`). Vision is $0 on Max, so
  bias toward it.
- **Rasterize** (pymupdf + Pillow): 144 DPI, long edge clamped to 1568px, JPEG q80.
- **Per-page vision** (`claude --print --model sonnet --permission-mode bypassPermissions
  --allowedTools Read`, image via temp file, page text as grounding) → structured JSON
  `{title, tables_markdown, data_points, body_markdown, insight}`.
- **Synthesis** (`claude --print --model opus`) over per-page titles+insights+data →
  `{title, exec_summary, key_insights, companies, people}`.
- **Stage** to `sources/<slug>.md`; move source PDF to `sources/pdf/`; append ledger.

## Backend

Max-plan Claude CLI (`claude --print`), **no ANTHROPIC_API_KEY** — `claude_call()` pops the
key from a copied env and uses Max OAuth, matching `inbox-enrich`. No metered cost. If Max
rate-limits mid-run, the per-page cache + journal resume cleanly on re-run.

## Output contract

`sources/<YYYY-MM-DD>-<kebab-title>.md`, `type: note`, `doc_type: pdf-source`,
`ingested_via: pdf-to-brain@1`, `content_hash: sha256:<pdf bytes>`, `companies:`/`people:`
populated from synthesis. Body: title → callout → `## Key insights` → `## Per-page
synthesis` (`### Page N` with reconstructed tables + `**Insight:** … (pN)`) → `## See also`.

## Idempotency & resumability

`content_hash` (sha256 of PDF bytes) in frontmatter. Re-running the same PDF is a **no-op
unless `--force`**; a changed PDF preserves `created`, bumps `updated`. Per-page cache keyed
by `sha256(model|prompt_version|page_no|image|text)` under `~/.gbrain/pdf-vision/<hash>/`.

## Prompt tuning

The per-page and synthesis prompts live as the constants `PER_PAGE_PROMPT` and
`SYNTH_PROMPT` in `~/bin/pdf-to-brain`; the authoritative human copy is
`~/bin/prompts/pdf-to-brain.md` (read fresh to iterate). Bump `PROMPT_VERSION` in the script
to invalidate the per-page cache after a prompt change.

## Daily auto-ingest

`brain-daily.sh` step 6 drains `inbox/*.pdf` automatically: it launches
`~/bin/brain-pdf-worker` **detached** (so big decks don't block the cron), which runs
`pdf-to-brain` on each inbox PDF sequentially (no `--sync`). The resulting `sources/` pages
are ingested by the **next** daily's `gbrain sync` (≈24h later). The worker is **idempotent**
(content_hash skip) and **self-healing** (a PDF stays in `inbox/` until it converts, so a
killed detached run is re-drained next daily). Caveat: detached survival assumes the daily
runs under cron; under launchd a separate agent for the worker would be more robust. Run the
backlog manually anytime: `~/bin/brain-pdf-worker`.

## Conflict resolution

For `*.pdf` → `sources/`, **pdf-to-brain wins** over the gbrain default `ingest` skill and is
NOT the email `inbox-enrich` flow. Finished pages land in `sources/` and are never
re-processed by the inbox enrichment cron.

## Safety

- Output slug is `[a-z0-9-]` only — no path traversal; writes confined to `sources/`.
- Refuses to move the source PDF into `sources/pdf/` unless that path is in `~/brain/.gitignore`
  (prevents committing large binaries). Fail-loud.
- Trusted-input assumption: the deck's text layer is fed to the vision model as grounding;
  do not run on untrusted PDFs that may contain prompt-injection text.

## Failure handling

A page that errors after one reprompt is journaled `error` (not dropped); the run continues
and exits non-zero so a re-run retries only the failures. Synthesis failure still writes the
page (without Key insights).

## Ledger

Append one JSONL line per run to `~/brain/.tasks/skill-evolution/pdf-to-brain/ledger.jsonl`
(`ts, version, outcome, cost_usd, notes, source, content_hash, pages, slug`). Gitignored.
