#!/usr/bin/env bash
# brain-daily.sh — runs once daily at 17:00 via cron.
#
# Order:
#   1. Pull Gmail via email-collector  (if CLAWVISOR creds present + script installed)
#   2. Sync Google Calendar            (if CLAWVISOR creds present + script installed)
#   3. Import Granola meetings         (if Granola desktop cache reachable)
#   4. gbrain sync + embed --stale + extract all
#   5. Submit Sonnet enrichment subagent job to the gbrain supervisor
#
# Each step's stdout/stderr is appended to a dated logfile under
# ~/.gbrain/cron/. A heartbeat row is appended on success or failure so
# `gbrain integrations doctor` can read the status of each source.
#
# Designed to be SAFE under partial setup: missing creds skip the source
# rather than aborting the run.

set -u  # error on unset vars; we deliberately do NOT `set -e` so one source's
        # failure doesn't kill the others.

# ─── Environment ──────────────────────────────────────────────────────────────

export PATH="$HOME/.bun/bin:$HOME/.local/bin:$HOME/bin:/usr/local/bin:/usr/bin:/bin"
export GBRAIN_DISABLE_DIRECT_POOL=1

# Prefer ~/.gbrain/secrets.env (readable from cron). Fall back to keychain
# pulls for interactive runs on a fresh machine. Re-materialise the file with
# ~/bin/gbrain-export-secrets.sh after rotating any key.
SECRETS_FILE="$HOME/.gbrain/secrets.env"
if [ -r "$SECRETS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$SECRETS_FILE"
else
    export OPENAI_API_KEY="$(security find-generic-password -a "$USER" -s OPENAI_API_KEY -w 2>/dev/null || true)"
    export DATABASE_URL="$(security find-generic-password -a "$USER" -s DATABASE_URL -w 2>/dev/null || true)"
    export CLAWVISOR_URL="$(security find-generic-password -a "$USER" -s CLAWVISOR_URL -w 2>/dev/null || true)"
    export CLAWVISOR_AGENT_TOKEN="$(security find-generic-password -a "$USER" -s CLAWVISOR_AGENT_TOKEN -w 2>/dev/null || true)"
    export CLAWVISOR_BRAIN_TASK_ID="$(security find-generic-password -a "$USER" -s CLAWVISOR_BRAIN_TASK_ID -w 2>/dev/null || true)"
    export ANTHROPIC_API_KEY="$(security find-generic-password -a "$USER" -s ANTHROPIC_API_KEY -w 2>/dev/null || true)"
fi

# ─── Paths + logging ──────────────────────────────────────────────────────────

DATE_TAG="$(date -u +%Y-%m-%d)"
LOG_DIR="$HOME/.gbrain/cron"
LOG_FILE="$LOG_DIR/brain-daily-${DATE_TAG}.log"
HEARTBEAT_BASE="$HOME/.gbrain/integrations"
mkdir -p "$LOG_DIR" "$HEARTBEAT_BASE"

log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG_FILE" >&2; }
heartbeat() {
    # heartbeat <integration_id> <status> <details_json>
    local id="$1" status="$2" details="${3:-{\}}"
    local dir="$HEARTBEAT_BASE/$id"
    mkdir -p "$dir"
    printf '{"ts":"%s","event":"daily_run","status":"%s","details":%s}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$status" "$details" \
        >> "$dir/heartbeat.jsonl"
}

log "═══ brain-daily.sh start ═══"

# ─── 1. Email collector (Gmail via ClawVisor) ─────────────────────────────────

EMAIL_COLLECTOR="$HOME/bin/brain-email-collect.py"
if [ -n "${CLAWVISOR_AGENT_TOKEN:-}" ] && [ -n "${CLAWVISOR_BRAIN_TASK_ID:-}" ] && [ -x "$EMAIL_COLLECTOR" ]; then
    log "→ email-to-brain: collecting Gmail via ClawVisor (newer_than:1d)"
    if python3 "$EMAIL_COLLECTOR" collect+digest >> "$LOG_FILE" 2>&1; then
        heartbeat email-to-brain ok '{"step":"collect+digest"}'
        log "  ✓ email-to-brain done"
    else
        heartbeat email-to-brain error '{"step":"collect+digest"}'
        log "  ✗ email-to-brain failed (see log)"
    fi
else
    log "→ email-to-brain: SKIP (CLAWVISOR creds or task_id missing, or collector not installed)"
    heartbeat email-to-brain skipped '{"reason":"no-creds-or-no-task-or-no-script"}'
fi

# ─── 2. Calendar sync (Google Calendar via ClawVisor) ─────────────────────────

CAL_SYNC="$HOME/bin/brain-calendar-sync.py"
if [ -n "${CLAWVISOR_AGENT_TOKEN:-}" ] && [ -n "${CLAWVISOR_BRAIN_TASK_ID:-}" ] && [ -x "$CAL_SYNC" ]; then
    log "→ calendar-to-brain: syncing Google Calendar via ClawVisor (last 7d + next 14d)"
    if python3 "$CAL_SYNC" --start "$(date -v-7d +%Y-%m-%d)" --end "$(date -v+14d +%Y-%m-%d)" \
        >> "$LOG_FILE" 2>&1; then
        heartbeat calendar-to-brain ok '{"window":"-7d..+14d"}'
        log "  ✓ calendar-to-brain done"
    else
        heartbeat calendar-to-brain error '{"window":"-7d..+14d"}'
        log "  ✗ calendar-to-brain failed (see log)"
    fi
else
    log "→ calendar-to-brain: SKIP (CLAWVISOR creds or task_id missing, or sync script not installed)"
    heartbeat calendar-to-brain skipped '{"reason":"no-creds-or-no-task-or-no-script"}'
fi

# ─── 3. Granola import (local desktop cache + API) ────────────────────────────

GRANOLA="$HOME/bin/brain-granola-import.py"
if [ -n "${CLAWVISOR_AGENT_TOKEN:-}" ] && [ -n "${CLAWVISOR_BRAIN_TASK_ID:-}" ] && [ -x "$GRANOLA" ]; then
    log "→ granola: importing last 7 days of meetings (via ClawVisor)"
    if python3 "$GRANOLA" >> "$LOG_FILE" 2>&1; then
        heartbeat granola ok '{"window":"-7d","via":"clawvisor"}'
        log "  ✓ granola done"
    else
        heartbeat granola error '{"window":"-7d","via":"clawvisor"}'
        log "  ✗ granola failed (see log)"
    fi
else
    # Fallback to the older local-cache wrapper if ClawVisor creds are missing.
    LEGACY="$HOME/bin/granola-to-brain"
    if [ -x "$LEGACY" ]; then
        log "→ granola: ClawVisor unavailable, falling back to local cache via $LEGACY"
        if "$LEGACY" >> "$LOG_FILE" 2>&1; then
            heartbeat granola ok '{"window":"-7d","via":"local-cache"}'
            log "  ✓ granola (local cache) done"
        else
            heartbeat granola error '{"window":"-7d","via":"local-cache","hint":"open Granola desktop app to refresh token"}'
            log "  ✗ granola (local cache) failed — open Granola desktop app to refresh"
        fi
    else
        log "→ granola: SKIP (neither ClawVisor nor local cache script available)"
        heartbeat granola skipped '{"reason":"no-clawvisor-and-no-script"}'
    fi
fi

# ─── 4. gbrain sync + embed + extract ─────────────────────────────────────────

log "→ gbrain sync --repo ~/brain"
gbrain sync --repo "$HOME/brain" >> "$LOG_FILE" 2>&1 \
    && log "  ✓ sync done" \
    || log "  ✗ sync failed"

log "→ gbrain embed --stale"
gbrain embed --stale >> "$LOG_FILE" 2>&1 \
    && log "  ✓ embed done" \
    || log "  ✗ embed failed"

# extract dies intermittently on transient Supabase pooler drops
# (write CONNECTION_CLOSED ...pooler.supabase.com:5432) — retry up to 3x.
log "→ gbrain extract all --source db"
EXTRACT_OK=0
for _attempt in 1 2 3; do
    if gbrain extract all --source db >> "$LOG_FILE" 2>&1; then
        EXTRACT_OK=1
        log "  ✓ extract done (attempt $_attempt)"
        break
    fi
    log "  ✗ extract attempt $_attempt failed (pooler drop is usually transient)"
    [ "$_attempt" -lt 3 ] && sleep 30
done
[ "$EXTRACT_OK" -eq 1 ] || log "  ✗ extract failed after 3 attempts"

# Repair pass (2026-07-07): re-insert wikilink edges the extractor drops.
# Two upstream gbrain bugs: (1) addLinksBatch text[] encoding breaks on
# contexts with embedded quotes and silently loses the whole 100-row batch;
# (2) the extractor's DIR_PATTERN whitelist omits daily/, inbox/, sources/,
# signals/ etc, so the calendar index chain never links. Server-side
# INSERT..SELECT, idempotent. Details: ~/bin/brain-link-backfill header.
LINK_BACKFILL="$HOME/bin/brain-link-backfill"
if [ -x "$LINK_BACKFILL" ]; then
    log "→ link-backfill: repairing dropped wikilink edges"
    "$LINK_BACKFILL" >> "$LOG_FILE" 2>&1 \
        && log "  ✓ link-backfill done" \
        || log "  ✗ link-backfill failed (see log)"
fi

# ─── 5. inbox-enrich subagent (Sonnet) ────────────────────────────────────────

# Canonical instruction set: ~/bin/prompts/inbox-enrich.md
# Skill discovery file:      ~/bin/skills/inbox-enrich/SKILL.md
#
# This deliberately does NOT use any gbrain default ingestion skill
# (data-research, ingest, meeting-ingestion) — those have different filing
# rules and would double-process or misroute content. CLAUDE.md enforces
# this; the prompt file is the contract.
#
# Routing inside the prompt:
#   - Real meeting recaps that landed in inbox/  → moved to meetings/
#   - Emails + docs                              → stay in inbox/, wikilinks rewritten
#   - Entity stubs created (capped 50 people / 25 companies per run)
#   - Compiled-truth APPEND under `## Open Threads` / `## Recent Activity`
#   - Timeline entries with [Source: [[inbox/...]]] citations
#
# Compiled-truth REWRITES (the heavier workflow we ran on 2026-05-13) are a
# separate manual pass; the daily cron stays append-only.

PROMPT_FILE="$HOME/bin/prompts/inbox-enrich.md"
SKILL_FILE="$HOME/bin/skills/inbox-enrich/SKILL.md"

if [ -r "$PROMPT_FILE" ] && command -v claude >/dev/null 2>&1; then
    # Auth routing (2026-06-12 fix — this step failed every cron run since
    # ~14 May with "Not logged in": the Max-plan OAuth credential lives in the
    # login keychain, which cron cannot read).
    #   Preferred: CLAUDE_CODE_OAUTH_TOKEN in ~/.gbrain/secrets.env (mint once
    #   interactively with `claude setup-token`) → Max plan, $0 marginal.
    #   Fallback:  keep ANTHROPIC_API_KEY set → pay-per-token API billing, but
    #   the enrichment actually runs. Brain health > token cost (CLAUDE.md).
    CLAUDE_CODE_OAUTH_TOKEN="${CLAUDE_CODE_OAUTH_TOKEN:-}"
    log "  diag: ANTHROPIC_API_KEY(parent)=${#ANTHROPIC_API_KEY}ch CLAUDE_CODE_OAUTH_TOKEN=${#CLAUDE_CODE_OAUTH_TOKEN}ch CLAWVISOR_AGENT_TOKEN=${#CLAWVISOR_AGENT_TOKEN}ch CLAWVISOR_BRAIN_TASK_ID=${#CLAWVISOR_BRAIN_TASK_ID}ch"
    # Run Claude Code non-interactively, piping the prompt file as the user
    # message. --permission-mode bypassPermissions is required because
    # `claude --print` cannot prompt interactively for tool-use approval; the
    # cron job needs to write to ~/brain/ unattended.
    if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
        AUTH_MODE="max-plan-oauth-token"
        log "→ inbox-enrich: invoking claude --print with $PROMPT_FILE (Sonnet, Max plan via CLAUDE_CODE_OAUTH_TOKEN)"
        (unset ANTHROPIC_API_KEY; claude --print --model sonnet --permission-mode bypassPermissions < "$PROMPT_FILE") >> "$LOG_FILE" 2>&1
        ENRICH_RC=$?
    else
        AUTH_MODE="api-key-fallback"
        log "→ inbox-enrich: invoking claude --print with $PROMPT_FILE (Sonnet, API-key billing — run 'claude setup-token' once and add CLAUDE_CODE_OAUTH_TOKEN to ~/.gbrain/secrets.env to route back to Max plan)"
        claude --print --model sonnet --permission-mode bypassPermissions < "$PROMPT_FILE" >> "$LOG_FILE" 2>&1
        ENRICH_RC=$?
    fi
    if [ "$ENRICH_RC" -eq 0 ]; then
        heartbeat inbox-enrich ok "{\"model\":\"sonnet\",\"auth\":\"$AUTH_MODE\",\"prompt\":\"~/bin/prompts/inbox-enrich.md\"}"
        log "  ✓ inbox-enrich completed ($AUTH_MODE)"
    else
        heartbeat inbox-enrich error "{\"model\":\"sonnet\",\"auth\":\"$AUTH_MODE\",\"prompt\":\"~/bin/prompts/inbox-enrich.md\"}"
        log "  ✗ inbox-enrich failed (see log; auth=$AUTH_MODE)"
    fi
else
    REASON=""
    [ ! -r "$PROMPT_FILE" ] && REASON="prompt-file-missing"
    command -v claude >/dev/null 2>&1 || REASON="${REASON:+$REASON,}claude-cli-missing"
    log "→ inbox-enrich: SKIP ($REASON)"
    heartbeat inbox-enrich skipped "{\"reason\":\"$REASON\"}"
fi

# ─── 6. Git backup: commit + push + Supabase sync (verified) ──────────────────
#
# Single best-practice backup engine: ~/bin/brain-backup. It stages with a >95MB
# guard, commits, pushes (auto-purges a large-file block from unpushed history
# and retries — the 219MB-zip remedy), re-syncs Supabase, and verifies that
# HEAD == origin/main and the gbrain checkpoint == HEAD. Runs here, after enrich
# and before the detached pdf drain, so this run's enrichment edits are committed,
# pushed AND synced in the same pass. Never aborts the daily.
# Authoritative process + skill: concepts/brain-backup-process; ~/bin/skills/brain-backup.

BACKUP="$HOME/bin/brain-backup"
if [ -x "$BACKUP" ]; then
    log "→ git-backup: ~/bin/brain-backup --auto"
    if "$BACKUP" --auto --reason "brain-daily ${DATE_TAG}" >> "$LOG_FILE" 2>&1; then
        heartbeat git-backup ok '{"engine":"brain-backup","verified":true}'
        log "  ✓ git-backup: committed, pushed, synced and verified"
    else
        heartbeat git-backup error '{"engine":"brain-backup"}'
        log "  ✗ git-backup: brain-backup reported a failure (see log)"
    fi
else
    log "→ git-backup: SKIP (~/bin/brain-backup not executable)"
    heartbeat git-backup skipped '{"reason":"no-brain-backup"}'
fi

# ─── 7. pdf-to-brain: async drain of inbox PDFs ───────────────────────────────
#
# Convert any PDFs sitting in inbox/ into rich sources/ pages, AFTER this daily
# run, as a DETACHED background job so big decks (≈1 min/vision page) don't block
# the cron. Resulting pages are ingested by the NEXT daily's gbrain sync (step 4),
# ≈24h later — idempotent via content_hash. Mostly-text PDFs take a cheap
# pure-python pymupdf4llm path; only chart/table decks pay for the vision pipeline.
# The worker is self-healing: a PDF stays in inbox/ until it converts, so a killed
# detached run is simply re-drained next daily.

PDF_WORKER="$HOME/bin/brain-pdf-worker"
shopt -s nullglob; _inbox_pdfs=( "$HOME"/brain/inbox/*.pdf ); shopt -u nullglob
if [ ${#_inbox_pdfs[@]} -eq 0 ]; then
    log "→ pdf-to-brain: no inbox PDFs"
    heartbeat pdf-to-brain skipped '{"reason":"no-pdfs"}'
elif [ -x "$PDF_WORKER" ] && command -v claude >/dev/null 2>&1; then
    log "→ pdf-to-brain: ${#_inbox_pdfs[@]} inbox PDF(s) → async drain (detached; pages picked up next daily)"
    nohup "$PDF_WORKER" </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null || true
    heartbeat pdf-to-brain ok "{\"queued\":${#_inbox_pdfs[@]},\"mode\":\"async-detached\"}"
else
    log "→ pdf-to-brain: SKIP (worker not executable or claude CLI missing)"
    heartbeat pdf-to-brain skipped '{"reason":"no-worker-or-claude"}'
fi

# ─── Done ─────────────────────────────────────────────────────────────────────

log "═══ brain-daily.sh complete ═══"
