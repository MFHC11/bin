---
name: feedback_brain_backup_process
description: "Backing up the brain = run ~/bin/brain-backup (one engine); never make Marcus specify git/push/supabase; ask \"ready to back up?\" in plain language"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 7b821414-cf93-4b6d-81e0-5276e3a84f0f
---

Backing up the brain is ONE command, `~/bin/brain-backup`. It protects all three things needed to rebuild after disk loss: (1) brain content → GitHub + Supabase, (2) scripts/skills → the `~/bin` GitHub repo, (3) the Claude memory store → a snapshot inside `~/bin/claude-brain-memory/` (with RESTORE.md) that rides the bin repo (no `gh` installed, so no separate repo). It stages (guarding out >95MB files), commits, pushes, syncs Supabase (`gbrain sync` + `embed --stale`), and verifies (trees clean, no oversize blob in un-backed-up history, both repos HEAD == origin/main, gbrain checkpoint == HEAD, memory snapshot matches live). `~/bin/brain-backup --check` is the verify-only self-test. The daily (`~/bin/brain-daily.sh` step 6) calls it automatically.

**Why:** Marcus explicitly does not want to specify mechanics (commit/push/sync) and worries he'll ask for something he doesn't understand. He wants the correct best-practice process done automatically, asked about in plain language, with tests that catch and self-heal errors. A 219MB `inbox/Prosemino chat.zip` once silently blocked the push for 50+ commits — exactly the kind of failure the engine now prevents and remediates.

**How to apply:**
- On "back up the brain" / "ready to back up" / "save the brain", invoke the [[brain-backup]] skill; run `~/bin/brain-backup`, do NOT hand-run git/gbrain.
- Confirm in plain language first: "Ready to back up the brain?" Never say push/commit/rebase/sync to Marcus.
- Known self-healed failures: unstages >95MB files; if a large blob is already in un-backed-up history it purges it via `git filter-branch` over `origin/main..HEAD` and retries the push once; after a history rewrite `gbrain sync` does a full re-sync (checkpoint SHA gone) — expected.
- If a NEW failure appears: fix `~/bin/brain-backup`, re-test (`--check` + a real run), update `concepts/brain-backup-process` and this note. Don't repeat a known mistake.

Related: [[feedback_brain_sync_doctor_exit]] (brain-sync exit-1 at health check is benign), [[project_pdf_pipeline_ingest_gap]] (the no-commit gap this closes), [[feedback_macos_cron_keychain]] (cron needs ~/.gbrain/secrets.env; SSH key must be reachable for the cron push).
