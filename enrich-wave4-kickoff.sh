#!/bin/bash
# One-shot: finish the inbox enrichment backlog (wave 4) via headless Max-plan Claude.
# Installed 2026-06-12 by the governor session. Safe to re-run (idempotent queue).
export PATH="$HOME/.local/bin:$HOME/.bun/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
cd "$HOME/brain" || exit 1
echo "=== wave4 kickoff $(date '+%F %T') ==="
for round in 1 2 3 4 5 6 7 8; do
  FILES=$(python3 - <<'PY'
import glob, re
todo=[]
for f in sorted(glob.glob("inbox/*.md")):
    h=open(f,errors="ignore").read(2000)
    if "legacy-inbox:" in h or "skip-enrich" in h or re.search(r"^enriched:",h,re.M): continue
    todo.append(f)
print(" ".join(todo[:10]))
PY
)
  if [ -z "$FILES" ]; then echo "queue empty after $((round-1)) rounds"; break; fi
  echo "--- round $round: $(echo $FILES | wc -w | tr -d ' ') files"
  claude --print --model fable --permission-mode bypassPermissions \
    --allowedTools "Read,Edit,Write,Bash,Grep,Glob" <<PROMPT
You are an inbox-enrichment subagent for Marcus Clover's second brain at /Users/marcusclover/brain. FIRST ACTION: read /Users/marcusclover/bin/prompts/inbox-enrich.md in full and follow it exactly. You HAVE write access.
FOUR FLEET AMENDMENTS (mandatory): (1) re-entry guard checks ALL FOUR citation forms: "gmail:<tid>", "gmail <tid>", "gmail thread <tid>", and the bare inbox filename; (2) re-run the guard immediately before each write; (3) repair legacy-form citations to canonical gmail form on pages you touch; (4) never stub bulk-marketing/newsletter senders.
SUBAGENT_FILES: $FILES
Process EXACTLY these files. Compiled pages (compiled: frontmatter) are append-only. British spelling, no em dashes. End with the standard counts block.
PROMPT
done
git add -A && git commit -m "Inbox enrichment wave 4 (headless cron rounds)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" 
gbrain sync
echo "=== wave4 done $(date '+%F %T') ==="
