---
name: gbrain shell jobs need GBRAIN_ALLOW_SHELL_JOBS=1 on the worker, not just the supervisor
description: When invoking `gbrain jobs submit shell --follow`, export GBRAIN_ALLOW_SHELL_JOBS=1 in the calling shell — the CLI flag only configures the supervisor; the inline worker that --follow spawns reads the env var
type: feedback
originSessionId: 9a9587e0-e211-4e8d-a602-02e0bccf38e9
---
When calling `gbrain jobs submit shell --follow ...`, you **must export** `GBRAIN_ALLOW_SHELL_JOBS=1` in the shell that invokes the command — not only when starting the supervisor.

**Why:** `--follow` spawns an inline worker process that handles the job in-process, and that worker only honors the env var, *not* the supervisor's `--allow-shell-jobs` flag. Without the env var, jobs are rejected with: `shell handler disabled on this worker (set GBRAIN_ALLOW_SHELL_JOBS=1 to execute shell jobs)`. Discovered when porting brain-eod's logic into brain-run — brain-eod has the export and it isn't decorative; the comment there even calls out that flag-only is unreliable.

**How to apply:**
- In any script that calls `gbrain jobs submit shell --follow`: prefix the call with `GBRAIN_ALLOW_SHELL_JOBS=1` or `export` it earlier in the script.
- This applies to Phase 5 (`gbrain dream`) and any future shell-job submitters in the brain pipeline.
- Don't rely on the supervisor having been started with `--allow-shell-jobs` — the worker is a different process.
- Confirmed real-environment behavior 2026-05-08 against gbrain v0.7.x.
