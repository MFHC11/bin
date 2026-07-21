---
name: pdf-pipeline-ingest-gap
description: "pdf-to-brain writes sources/*.md to disk but nothing commits them, so gbrain sync never ingests them — 192-page un-ingested backlog found 2026-06-14"
metadata: 
  node_type: memory
  type: project
  originSessionId: 60a3267c-1605-4a77-8cd3-fbe59bc265f6
  modified: 2026-07-20T23:52:05.148Z
---

pdf-to-brain extracts PDFs into `sources/*.md` pages on disk, but those pages stay **untracked in git** until something commits them. `gbrain sync` ingests only the *committed* repo, so un-committed extractions are never ingested and never become searchable.

**Discovered 2026-06-14:** Marcus asked why the brain quoted an outdated Prosemino↔ERV intercompany loan figure (£2.7M from an April *planning* doc, `deals/prosemino-cap-structure-analysis`) instead of the live management accounts (~$3.32m, May 2026). Root cause: the April + May ERV Group management-accounts pages (from Carolyn Kim's PDFs) were extracted to `sources/` but `get_page` returned page_not_found. A single `git add -A` revealed **192 previously-untracked source pages** (the entire pdf-to-brain corpus: decks, CIMs, datarooms, financials). After committing + `gbrain sync` + `gbrain embed --stale`, all became queryable.

**Why it happens:** `brain-daily.sh` contains NO `git add/commit/push` step (verified). The daily does sync/embed/extract/inbox-enrich/pdf-worker; commits happen only via a separate brain-sync flow that wasn't committing these. So pdf-to-brain output piles up untracked forever.

**RESOLVED (verified 2026-07-03):** `brain-daily.sh` step 6 now runs `~/bin/brain-backup --auto` (commit+push+sync) BEFORE the detached pdf drain, so source pages get committed and ingested by the next daily's sync. Verified: `sources/2026-06-29-attachment-approved-board-minutes-30th-march-2026` is in the DB (created 06-30) and `git status sources/` is clean. The ingest gap is closed; do not re-flag it.

**New pdf failure mode found+fixed 2026-07-03:** all `claude --print` vision/synthesis calls from the pdf worker exited 1 with "this workspace has not been trusted" because `projects["/Users/marcusclover"].hasTrustDialogAccepted` was false in ~/.claude.json (worker cwd is the home dir, not ~/brain). Set to true 2026-07-03 (backup at ~/.claude.json.bak-pre-trust-fix-20260703); the Oort registrar-filing PDF that aborted with 14/14 page errors on 07-02 should convert on the next worker pass.

**Recurring vision fail STILL seen post-trust-fix (07-18, 07-20); hardened 2026-07-21.** Every deck's detached-worker vision run first-fails with ALL pages `claude exited 1:` (empty), then a re-run succeeds 0-errors. Ruled OUT by reproduction (Tests 1-4, 2026-07-21): auth works on Max/OAuth; `pdf-to-brain` already pops `ANTHROPIC_API_KEY` (so the key-shadow theory is wrong); `/Users/marcusclover` trust is True; ClawVisor env presence is harmless; 5 concurrent calls all succeed. Could NOT reproduce interactively — it only happens in the true detached ClawVisor cron run. Root cause unconfirmed; the real error was being SWALLOWED because `claude_call` surfaced only stderr (empty), never stdout (where claude writes the actual error). Fixes applied: `pdf-to-brain claude_call` now retries 3x with backoff AND surfaces stdout-or-stderr; `brain-pdf-worker` sources secrets + unsets the key + passes `--concurrency 1` for the unattended path. So transients now self-heal, and the NEXT real failure will finally log the true error. The self-heal was previously only happening via ad-hoc in-session re-runs, not cron.

**MIME allowlist extended 2026-07-21.** `brain-email-collect.py` only downloaded `application/pdf`, so native `.pptx/.docx/.xlsx` decks and raw images (`.png/.jpg`) were silently dropped (never routed anywhere). Now `DOWNLOAD_MIMES` covers pdf+office+image (14 types) and `_convert_to_pdf()` converts non-PDFs to PDF via LibreOffice headless (installed to /Applications 2026-07-21; `-env:UserInstallation` isolates the profile lock) so they land as `*.pdf` in inbox/ and feed the existing vision pipeline. Verified: image→pdf 9s, docx→pdf 5s, function-level both valid. The `%PDF`-only write guard was replaced with pdf-passthrough / office-image-convert / else-skip.

**Retrieval note:** once ingested, financial figures are reliably found via keyword `search` (entity + metric name), but the semantic `query` path returns EMPTY for some dense numeric/table phrasings ("average net burn per month", "tranche schedule") even when the data is present. Durable mitigation: promote headline current figures to compiled-truth prose on entity pages ([[companies/erv]], prosemino). See [[pdf-to-brain]] workflow. Sync emits "Text imported. Run 'gbrain embed --stale'" — embedding is a REQUIRED second step for semantic search.
