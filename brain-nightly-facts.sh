#!/bin/bash
# Nightly brain facts pipeline: sync + extract_facts reconcile.
# Created 2026-06-11 per Marcus's approval (Great Compilation follow-up).
# cron can't read the login keychain, so source the secrets file.
set -u
# cron PATH is minimal; gbrain lives in ~/.bun/bin (fix 2026-06-12)
export PATH="$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
[ -f "$HOME/.gbrain/secrets.env" ] && source "$HOME/.gbrain/secrets.env"
cd "$HOME/brain" || exit 1
echo "=== brain-nightly-facts $(date '+%Y-%m-%d %H:%M') ==="
gbrain sync
gbrain dream --phase extract_facts
echo "=== done $(date '+%H:%M') ==="
