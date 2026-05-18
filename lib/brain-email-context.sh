#!/usr/bin/env bash
# brain-email-context.sh — generate dynamic brain context block for email
# classification (cal-mail-weekly-sync Phase 3, two-pass Haiku→Sonnet pipeline).
#
# Output: stdout (intended to be captured and prepended to the Haiku prompt
#         before the email batch).
# Cost:   $0 LLM. Runs 2× `gbrain query` (vector+keyword hybrid search, local)
#         + 1× file read. No Anthropic API call.
# Cache:  none. Refreshes on every run, as requested.
#
# Usage:
#   CONTEXT="$(~/bin/lib/brain-email-context.sh)"
#   # ...then prepend "$CONTEXT" to each Haiku classification prompt this run.
#
# Hook point: call once per pipeline run (not per batch — the context is
# identical for all batches in a given run).

set -euo pipefail

BRAIN_ROOT="${BRAIN_ROOT:-$HOME/brain}"
DATE_STAMP="$(date '+%Y-%m-%d %H:%M %Z')"

# Keep the injected block compact (~50 lines, ~750 tokens at typical width).
HOT_LP_LIMIT=20
PORTFOLIO_LIMIT=10
ACTIONS_LIMIT=20
LINE_MAXLEN=100

# --- gbrain query result parser ---
# gbrain emits per result:
#   [1.0518] companies/lp-moritz-de-chaisemartin -- # Moritz de Chaisemartin
#   <multi-line snippet>
# We keep ONLY the score-prefixed header line, strip the score+slug, and
# strip a leading `# ` so the result is the page title (or first snippet
# if there's no h1).
gbrain_titles() {
    local query="$1"
    local limit="$2"
    gbrain query "$query" --limit "$limit" --detail low 2>/dev/null \
        | awk '/^\[[0-9.]+\]/' \
        | sed -E 's/^\[[0-9.]+\] [^ ]+ -- //' \
        | sed -E 's/^# //' \
        | cut -c1-"$LINE_MAXLEN" \
        || true
}

format_list() {
    local list="$1"
    if [[ -z "${list// }" ]]; then
        printf '  - (none)\n'
    else
        echo "$list" | awk 'NF' | sed -E 's/^/  - /'
    fi
}

# 1) Hot LPs — pipeline opportunities to prioritise
HOT_LPS="$(gbrain_titles "qualified opportunity LP pipeline" "$HOT_LP_LIMIT")"

# 2) Active portfolio situations
PORTFOLIO="$(gbrain_titles "Anthro Green Li-ion Blixt Methanox Immaterial Redoxion term sheet" "$PORTFOLIO_LIMIT")"

# 3) Open actions — checkbox lines from tasks/active.md
ACTIVE_TASKS_FILE="$BRAIN_ROOT/tasks/active.md"
if [[ -f "$ACTIVE_TASKS_FILE" ]]; then
    OPEN_ACTIONS="$(grep -E '^- \[ \]' "$ACTIVE_TASKS_FILE" \
        | sed -E 's/^- \[ \] *//' \
        | cut -c1-"$LINE_MAXLEN" \
        | head -n "$ACTIONS_LIMIT" \
        || true)"
else
    OPEN_ACTIONS=""
fi

cat <<EOF
LIVE BRAIN CONTEXT ($DATE_STAMP):

Hot LPs — prioritise their emails:
$(format_list "$HOT_LPS")

Active portfolio situations:
$(format_list "$PORTFOLIO")

Open actions needing follow-up:
$(format_list "$OPEN_ACTIONS")
EOF
