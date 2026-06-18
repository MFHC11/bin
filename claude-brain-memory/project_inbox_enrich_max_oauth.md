---
name: project_inbox_enrich_max_oauth
description: "Why brain-daily inbox-enrich must run on Max via CLAUDE_CODE_OAUTH_TOKEN, not the Anthropic API key"
metadata: 
  node_type: memory
  type: project
  originSessionId: c4290452-6164-4907-9486-40c82505a2fa
---

brain-daily.sh's inbox-enrich step (`claude --print --model sonnet`) has two auth paths: if `CLAUDE_CODE_OAUTH_TOKEN` is set it takes the Max path (`unset ANTHROPIC_API_KEY; claude --print`, $0 marginal); otherwise it falls back to the `ANTHROPIC_API_KEY` console account. The console account is intentionally UNFUNDED, so the fallback fails with **"Credit balance is too low"** and the daily inbox step dies. This is by design (Marcus runs everything on Max), so the ONLY working path is the OAuth token.

Fix (applied 2026-06-16): generate the token once with `claude setup-token` (must run in a REAL terminal — the Claude Code `!` in-session runner detaches the process so the paste-code-back step hangs with empty output), store it in secrets.env. Verified working end-to-end (source secrets → unset ANTHROPIC_API_KEY → `claude --print` returns normally, no credit error). `~/bin/gbrain-export-secrets.sh` now materializes `CLAUDE_CODE_OAUTH_TOKEN`, `ZEROENTROPY_API_KEY`, and `GRANOLA_API_TOKEN` from the keychain (the latter two were previously hand-added and would have been dropped on a re-run). Token is ~220 chars (`sk-ant-oat01-...`); re-run setup-token + the export script if it ever expires. See [[feedback_macos_cron_keychain]].
