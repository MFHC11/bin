# brain-backup — authoritative process (read fresh each run)

Goal: back up Marcus's brain correctly and verifiably, without ever asking him about technical mechanics, and self-heal known failure modes.

## Engine

The whole process is `~/bin/brain-backup`. Do not reimplement it inline. Modes:

- `~/bin/brain-backup` — full backup + verify (stage→commit→push→sync→verify).
- `~/bin/brain-backup --check` — verification tests only, no writes (the self-test).
- `~/bin/brain-backup --reason "<msg>"` — adds a note to the commit message.
- `~/bin/brain-backup --auto` — same behaviour; used by the daily cron caller.

Exit 0 = all verified. Exit 1 = a step or check failed.

## Interaction rules

- Plain language only. To Marcus, this is "backing up the brain", never "commit/push/sync/rebase".
- Confirm with "Ready to back up the brain?" before running, unless he has already told you to proceed.
- After running, report plainly: backed up + verified, or what failed and the fix applied.

## Verification (the built-in tests, all must pass)

1. Working tree clean (nothing uncommitted).
2. No file >95MB in un-backed-up history.
3. Local HEAD == origin/main (GitHub current).
4. Supabase checkpoint == HEAD (gbrain in sync).

## Known failure modes + remedies (already handled by the engine)

- Large file (>100MB) blocks the push: the engine unstages oversize files at staging time, and if one is already in un-backed-up history it purges that blob via `git filter-branch` over `origin/main..HEAD` and retries the push once. Origin only sees clean history. (Origin of this lesson: a 219MB `inbox/Prosemino chat.zip` blocked 50+ commits, 2026-06-18.)
- After a history rewrite, `gbrain sync` finds its stored checkpoint SHA gone and does a full re-sync. Expected; it self-heals and the checkpoint advances to the new HEAD.
- The daily syncs (step 4) BEFORE enrichment (step 5) edits files, so the backup step (6) re-syncs to capture the same-run enrichment edits. Always sync as part of backup, not just commit/push.

## When you improve the process

If you hit a failure the engine does not handle: fix `~/bin/brain-backup`, re-test with `--check` plus one real run, update `concepts/brain-backup-process` (brain) and the memory note `feedback_brain_backup_process`, so the lesson sticks.
