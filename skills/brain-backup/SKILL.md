---
name: brain-backup
description: Back up the brain end-to-end (commit, push to GitHub, sync Supabase) with built-in verification and self-healing. Use whenever Marcus wants his brain saved/backed up.
---

# brain-backup

One safe, best-practice process to back up Marcus's brain. Marcus must never have to specify git/push/Supabase mechanics, and you must never ask him about them. He says "back up the brain" (or similar) and you run the verified process.

It protects everything needed to rebuild after disk loss: the brain content (GitHub + Supabase), the scripts/skills (`~/bin` repo on GitHub), and the Claude memory store (snapshotted into `~/bin/claude-brain-memory/`, which rides the bin repo, since `gh` is not installed to give it its own repo).

## Triggers

"back up the brain", "ready to back up", "save the brain", "backup brain", "is the brain backed up", "make sure the brain is saved/backed up to GitHub", or any request to persist/secure brain work.

## How to respond (plain language only)

1. Confirm in plain language before writing anything: **"Ready to back up the brain?"** Never say "push", "commit", "sync Supabase", "rebase", etc. to Marcus. If he has clearly already said go ahead ("back it up now", "yes back up"), skip the confirm and run.
2. Run the engine: `~/bin/brain-backup` (authoritative; do NOT hand-run git/gbrain commands yourself).
3. Report the result in plain terms: backed up and verified, or what failed and what you did about it.

To only check status without changing anything (a "is it safe?" question): `~/bin/brain-backup --check`.

## What the engine does (so you can explain it if asked)

`~/bin/brain-backup`:
1. Stages changes; unstages any file over 95MB so it can never block the backup (GitHub's limit is 100MB).
2. Commits (only if there is something new).
3. Pushes to GitHub. If a large file already baked into earlier un-backed-up work blocks it, the engine removes that file from the un-backed-up history and retries automatically (the fix for the 219MB zip that once blocked 50+ saves).
4. Syncs Supabase (`gbrain sync` + `embed --stale`).
5. Verifies and prints PASS/FAIL: nothing left uncommitted, no oversize file in un-backed-up history, GitHub matches local, Supabase matches local.

Exit 0 = verified good. Exit 1 = something failed; read the output, fix the cause, re-run, and only then report success.

## Rules

- Always prefer the engine over ad-hoc commands. If the engine reports a failure, correct the underlying issue and re-run rather than improvising around it.
- If you discover a new failure mode the engine does not yet handle, fix `~/bin/brain-backup`, re-test with `--check` and a real run, and note the lesson in the brain memory (`feedback_brain_backup_process`) so it is not repeated.
- The daily (`~/bin/brain-daily.sh`, step 6) already calls this engine, so routine work is backed up automatically; this skill is for on-demand backups and status checks.
- Authoritative process doc: `concepts/brain-backup-process` (brain) and `~/bin/prompts/brain-backup.md`.
