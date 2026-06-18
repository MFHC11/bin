---
name: macos-cron-keychain-silent-fail
description: "macOS cron processes cannot read login-keychain items — `security find-generic-password` returns empty silently, breaking unattended scripts"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ea027121-63cc-45be-8bf7-9e258f2d6934
---

macOS cron's process context has no audit_session_id attached to it, so `security find-generic-password -a "$USER" -s SOMEKEY -w` returns empty (and exit 0) for any item stored in `login.keychain-db`. With `|| true` swallowing the failure, the script proceeds with `KEY=""` and the dependent step then fails or "skips" with a misleading message ("creds missing").

**Why:** Diagnosed 2026-05-14 when brain-daily.sh's (then `brain-daily-9am.sh`, 09:00) cron run silently skipped email-to-brain and calendar-to-brain (CLAWVISOR creds "missing") and inbox-enrich failed with "Not logged in" — yet all three secrets WERE in the keychain and worked from interactive shells. Test via `at` or a fresh cron entry confirmed cron-context keychain reads return 0-length strings.

**How to apply:** For any unattended script (cron, launchd background agent without GUI session, CI runner on macOS):
- Don't pull secrets from login.keychain at run time. Source them from a file written by an interactive helper that DID have keychain access.
- Pattern: `~/bin/gbrain-export-secrets.sh` materialises keychain → `~/.gbrain/secrets.env` (chmod 600). The cron script does `[ -r "$SECRETS_FILE" ] && . "$SECRETS_FILE"`, with the keychain block as fallback for first-run/interactive.
- Re-run the export helper after rotating any secret.
- Add a diagnostic log line (key lengths, not values) just before any auth-sensitive step, so future failures aren't mute.

**Bonus gotcha discovered alongside:** `claude --print` in cron also needs `--permission-mode bypassPermissions` — without it, write operations block at runtime since there's no TUI to approve. Affects any unattended Claude Code invocation that edits files.
