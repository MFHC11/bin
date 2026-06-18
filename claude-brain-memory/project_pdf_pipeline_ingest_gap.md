---
name: pdf-pipeline-ingest-gap
description: "pdf-to-brain writes sources/*.md to disk but nothing commits them, so gbrain sync never ingests them — 192-page un-ingested backlog found 2026-06-14"
metadata: 
  node_type: memory
  type: project
  originSessionId: 60a3267c-1605-4a77-8cd3-fbe59bc265f6
---

pdf-to-brain extracts PDFs into `sources/*.md` pages on disk, but those pages stay **untracked in git** until something commits them. `gbrain sync` ingests only the *committed* repo, so un-committed extractions are never ingested and never become searchable.

**Discovered 2026-06-14:** Marcus asked why the brain quoted an outdated Prosemino↔ERV intercompany loan figure (£2.7M from an April *planning* doc, `deals/prosemino-cap-structure-analysis`) instead of the live management accounts (~$3.32m, May 2026). Root cause: the April + May ERV Group management-accounts pages (from Carolyn Kim's PDFs) were extracted to `sources/` but `get_page` returned page_not_found. A single `git add -A` revealed **192 previously-untracked source pages** (the entire pdf-to-brain corpus: decks, CIMs, datarooms, financials). After committing + `gbrain sync` + `gbrain embed --stale`, all became queryable.

**Why it happens:** `brain-daily.sh` contains NO `git add/commit/push` step (verified). The daily does sync/embed/extract/inbox-enrich/pdf-worker; commits happen only via a separate brain-sync flow that wasn't committing these. So pdf-to-brain output piles up untracked forever.

**Fix (proposed, not yet applied):** add `git add -A && git commit` to `brain-daily.sh` (or have brain-pdf-worker commit its own output) so extractions get committed → ingested automatically. Until then, after any pdf-to-brain run: `cd ~/brain && git add -A && git commit && gbrain sync --repo ~/brain && gbrain embed --stale`.

**Retrieval note:** once ingested, financial figures are reliably found via keyword `search` (entity + metric name), but the semantic `query` path returns EMPTY for some dense numeric/table phrasings ("average net burn per month", "tranche schedule") even when the data is present. Durable mitigation: promote headline current figures to compiled-truth prose on entity pages ([[companies/erv]], prosemino). See [[pdf-to-brain]] workflow. Sync emits "Text imported. Run 'gbrain embed --stale'" — embedding is a REQUIRED second step for semantic search.
