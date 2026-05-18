#!/usr/bin/env bash
# gbrain-export-secrets.sh — materialise the macOS login-keychain items the
# daily cron path needs into ~/.gbrain/secrets.env (chmod 600).
#
# Why this exists: cron's process context cannot read login-keychain items by
# default (no audit_session_id → silent empty return from
# `security find-generic-password`). brain-daily-9am.sh therefore sources this
# file instead of pulling from keychain at run time. Re-run this script after
# rotating any of the listed keys.
#
# Run interactively from your shell — NOT from cron.

set -euo pipefail

SECRETS_FILE="$HOME/.gbrain/secrets.env"
mkdir -p "$(dirname "$SECRETS_FILE")"
umask 077
{
  echo "# Generated $(date -u +%Y-%m-%dT%H:%M:%SZ) by gbrain-export-secrets.sh"
  echo "# Source of truth: macOS login keychain. Re-run this script after rotating any key."
  for k in OPENAI_API_KEY ANTHROPIC_API_KEY DATABASE_URL CLAWVISOR_URL CLAWVISOR_AGENT_TOKEN CLAWVISOR_BRAIN_TASK_ID; do
    v=$(security find-generic-password -a "$USER" -s "$k" -w 2>/dev/null || true)
    if [ -n "$v" ]; then
      printf 'export %s=%q\n' "$k" "$v"
    else
      printf '# %s: NOT IN KEYCHAIN\n' "$k"
    fi
  done
} > "$SECRETS_FILE"
chmod 600 "$SECRETS_FILE"
echo "wrote $SECRETS_FILE ($(wc -l < "$SECRETS_FILE") lines)"
