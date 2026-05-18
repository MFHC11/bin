#!/bin/zsh
# brain-run-tests-phase4.zsh — tests for Phase 4 (inbox & enrich).
# Uses a mock `claude` binary so no real LLM calls are made (cost: $0).

set -uo pipefail

source "$HOME/bin/lib/brain-run-test.zsh"

# ─── Mock claude factory ─────────────────────────────────────────────────────
# Writes a stub `claude` CLI to $TEST_TMP/claude-mock that:
#   - records its argv to $TEST_TMP/claude-args.txt for inspection
#   - emits JSON result with the configured total_cost_usd
#   - optionally simulates inbox file processing (moves a meeting file)
#   - exits with the configured code
#
# Tunables (env vars):
#   MOCK_CLAUDE_COST=0.42        cost for the JSON output
#   MOCK_CLAUDE_EXIT=0           exit code (1 for failure tests)
#   MOCK_CLAUDE_MOVE_MEETING=1   simulate moving one meeting file out of inbox/
make_mock_claude_phase4() {
  local mock="$TEST_TMP/claude-mock"
  cat > "$mock" <<'SH'
#!/bin/sh
ARGS_FILE="${MOCK_CLAUDE_ARGS_FILE:-$TEST_TMP/claude-args.txt}"
: > "$ARGS_FILE"
for a in "$@"; do
  printf '%s\n' "$a" >> "$ARGS_FILE"
done

# Optionally simulate the agent moving a meeting-typed file from inbox/
# into meetings/ (Step 2.3 of inbox-enrich.md).
if [ "${MOCK_CLAUDE_MOVE_MEETING:-0}" = "1" ] && [ -n "${BRAIN_DIR:-}" ]; then
  mkdir -p "$BRAIN_DIR/meetings"
  src="$BRAIN_DIR/inbox/2026-05-01-meeting-fake.md"
  if [ -f "$src" ]; then
    mv "$src" "$BRAIN_DIR/meetings/2026-05-01-fake.md"
  fi
fi

cost="${MOCK_CLAUDE_COST:-0.42}"
# MOCK_CLAUDE_MAX_TURNS=1 simulates the agent hitting the turn budget:
# is_error=true, terminal_reason=max_turns, exit 1 — but Phase 4 should
# treat this as partial success (rc forced to 0).
if [ "${MOCK_CLAUDE_MAX_TURNS:-0}" = "1" ]; then
  printf '{"type":"result","subtype":"error_max_turns","is_error":true,"total_cost_usd":%s,"terminal_reason":"max_turns","errors":["Reached maximum number of turns (30)"]}\n' "$cost"
  exit 1
fi

printf '{"type":"result","subtype":"success","is_error":false,"total_cost_usd":%s,"result":"mock done"}\n' "$cost"

exit "${MOCK_CLAUDE_EXIT:-0}"
SH
  chmod +x "$mock"
  export CLAUDE_BIN="$mock"
  export MOCK_CLAUDE_ARGS_FILE="$TEST_TMP/claude-args.txt"
}

# Stub prompt file for Phase 4
make_stub_prompt_phase4() {
  local prompt="$TEST_TMP/inbox-prompt.md"
  cat > "$prompt" <<'MD'
# Test stub prompt
You are a mock inbox-enrich agent. Do nothing. Exit cleanly.
MD
  export PROMPT_INBOX="$prompt"
}

# Seed an inbox file (and optionally a meeting-typed one) so Phase 4 has
# something to count.
seed_inbox() {
  mkdir -p "$BRAIN_DIR/inbox"
  cat > "$BRAIN_DIR/inbox/2026-04-15-email-fake-thread.md" <<'MD'
---
type: inbox
tags: [email]
---
# Fake email thread
MD
  if [ "${SEED_MEETING:-0}" = "1" ]; then
    cat > "$BRAIN_DIR/inbox/2026-05-01-meeting-fake.md" <<'MD'
---
type: meeting
tags: [meeting]
---
# Fake meeting
MD
  fi
}

# ─── T25: Phase 4 runs under --weekly, skipped under --quick/--no-enrich ────
test_phase4_runs_under_weekly() {
  make_mock_claude_phase4
  make_stub_prompt_phase4
  seed_inbox
  ~/bin/brain-run --weekly --run-id=p4-weekly </dev/null >/dev/null 2>&1
  LAST_EXIT_CODE=$?

  assert_state p4-weekly 4 "succeeded" "T25 — phase 4 runs and succeeds under --weekly"
  assert_exit_code 0 "T25 — exit 0 on clean weekly run"
}

test_phase4_skipped_under_quick() {
  make_mock_claude_phase4
  make_stub_prompt_phase4
  seed_inbox
  ~/bin/brain-run --quick --run-id=p4-quick </dev/null >/dev/null 2>&1
  LAST_EXIT_CODE=$?

  assert_state p4-quick 4 "" "T25 — phase 4 NOT started under --quick (state file absent)"
  assert_exit_code 0 "T25 — quick run still exits 0"
}

test_phase4_skipped_with_no_enrich_flag() {
  make_mock_claude_phase4
  make_stub_prompt_phase4
  seed_inbox
  ~/bin/brain-run --weekly --no-enrich --run-id=p4-noenrich </dev/null >/dev/null 2>&1
  LAST_EXIT_CODE=$?

  assert_state p4-noenrich 4 "skipped" "T25 — phase 4 skipped under --no-enrich"
  assert_exit_code 0 "T25 — --no-enrich run exits 0"
}

# ─── T26: Phase 4 invokes claude with the right flags ────────────────────────
test_phase4_invokes_claude_with_right_flags() {
  make_mock_claude_phase4
  make_stub_prompt_phase4
  seed_inbox
  ~/bin/brain-run --weekly --run-id=p4-args </dev/null >/dev/null 2>&1

  assert_file_exists "$MOCK_CLAUDE_ARGS_FILE" "T26 — claude was invoked"

  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "--model" "T26 — --model flag passed"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "claude-sonnet-4-6" "T26 — Sonnet 4.6 model"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "--max-turns" "T26 — --max-turns flag"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "30" "T26 — max-turns=30"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "--allowedTools" "T26 — --allowedTools flag"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "mcp__gbrain__" "T26 — gbrain tools granted"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "mcp__plugin_claude-mem_mcp-search__" "T26 — claude-mem search tools granted"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "--output-format" "T26 — --output-format flag"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "json" "T26 — output format json"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "--print" "T26 — --print flag (headless)"

  # Phase 4 should NOT grant Gmail/Calendar tools — those are Phase 3 only.
  if grep -q "mcp__claude_ai_Gmail__" "$MOCK_CLAUDE_ARGS_FILE"; then
    _fail "T26 — Gmail tools should NOT be granted to Phase 4"
  else
    _pass "T26 — Gmail tools correctly NOT granted to Phase 4"
  fi
}

# ─── T27: Cost estimate logged before actual ─────────────────────────────────
test_phase4_logs_estimate_then_actual() {
  make_mock_claude_phase4
  make_stub_prompt_phase4
  seed_inbox
  export MOCK_CLAUDE_COST=0.85
  ~/bin/brain-run --weekly --run-id=p4-cost </dev/null >/dev/null 2>&1
  unset MOCK_CLAUDE_COST

  local cost_log="$GBRAIN_HOME/cost-30d.jsonl"
  assert_file_exists "$cost_log" "T27 — cost log written"

  local est_count
  est_count=$(grep -c '"phase": 4' "$cost_log" 2>/dev/null || echo 0)
  est_count=$(echo "$est_count" | tr -d ' ')
  assert_greater_than "$est_count" 1 "T27 — at least 2 lines for phase 4 (estimate + actual)"

  assert_file_contains "$cost_log" '"phase": 4' "T27 — phase 4 cost line present"
  # New auto-scaling code estimates n × $0.15 (1 file × $0.15 = $0.15)
  assert_file_contains "$cost_log" '"cost_usd": 0.15' "T27 — estimate of \$0.15 (1 file × \$0.15)"
  assert_file_contains "$cost_log" '"cost_usd": 0.85' "T27 — actual of \$0.85 (mock JSON)"

  # Estimate must come BEFORE actual in the log (audit ordering)
  local first_line
  first_line=$(grep '"phase": 4' "$cost_log" | head -1)
  if echo "$first_line" | grep -q '"kind": "estimate"'; then
    _pass "T27 — estimate line precedes actual"
  else
    _fail "T27 — estimate should come first, but first phase-4 line is:" "$first_line"
  fi

  # Manifest reflects actual cost
  local manifest_cost
  manifest_cost=$(python3 -c "
import json
m = json.load(open('$GBRAIN_HOME/runs/p4-cost/manifest.json'))
print(m['phases']['4']['cost_actual_usd'])
")
  assert_equal "0.85" "$manifest_cost" "T27 — manifest's cost_actual_usd matches"
}

# ─── T28: Missing prompt file → clean failure ────────────────────────────────
test_phase4_missing_prompt_fails_cleanly() {
  make_mock_claude_phase4
  export PROMPT_INBOX="$TEST_TMP/does-not-exist.md"

  ~/bin/brain-run --weekly --run-id=p4-noprompt </dev/null >/dev/null 2>&1
  LAST_EXIT_CODE=$?

  assert_state p4-noprompt 4 "failed" "T28 — phase 4 fails when prompt missing"
  assert_exit_code 1 "T28 — overall exit 1"
  assert_log_contains p4-noprompt "prompt file missing" "T28 — log explains the missing prompt"
}

# ─── T29: Watermark untouched (Phase 4 has no watermark) ─────────────────────
test_phase4_does_not_touch_watermark() {
  make_mock_claude_phase4
  make_stub_prompt_phase4
  seed_inbox
  echo "2026-05-01T00:00:00+0000" > "$BRAIN_DIR/.last-email-sync"
  local before
  before=$(<"$BRAIN_DIR/.last-email-sync")

  # Phase 3 will also run and is mocked; it advances the watermark. To prove
  # Phase 4 doesn't touch it, run with --no-mail so only Phase 4 executes.
  ~/bin/brain-run --weekly --no-mail --run-id=p4-nowm </dev/null >/dev/null 2>&1
  LAST_EXIT_CODE=$?

  local after
  after=$(<"$BRAIN_DIR/.last-email-sync")
  assert_equal "$before" "$after" "T29 — Phase 4 alone leaves the cal-mail watermark unchanged"
}

# ─── T30: Inbox delta metric is captured ─────────────────────────────────────
test_phase4_records_inbox_delta() {
  make_mock_claude_phase4
  make_stub_prompt_phase4
  export SEED_MEETING=1
  seed_inbox
  unset SEED_MEETING
  export MOCK_CLAUDE_MOVE_MEETING=1

  ~/bin/brain-run --weekly --no-mail --run-id=p4-delta </dev/null >/dev/null 2>&1
  LAST_EXIT_CODE=$?
  unset MOCK_CLAUDE_MOVE_MEETING

  local metric="$GBRAIN_HOME/runs/p4-delta/phase-4.metric.processed"
  assert_file_exists "$metric" "T30 — phase-4.metric.processed written"

  local processed
  processed=$(<"$metric")
  assert_equal "1" "$processed" "T30 — exactly 1 inbox file moved out (the meeting)"
}

# ─── T31: max-turns is treated as partial success, not failure ──────────────
test_phase4_max_turns_is_partial_success() {
  make_mock_claude_phase4
  make_stub_prompt_phase4
  seed_inbox
  export MOCK_CLAUDE_MAX_TURNS=1
  export MOCK_CLAUDE_COST=1.13

  ~/bin/brain-run --weekly --no-mail --run-id=p4-maxturns </dev/null >/dev/null 2>&1
  LAST_EXIT_CODE=$?

  unset MOCK_CLAUDE_MAX_TURNS MOCK_CLAUDE_COST

  # Phase 4 should mark itself succeeded even though claude returned 1,
  # because terminal_reason=max_turns means bounded budget not a crash.
  assert_state p4-maxturns 4 "succeeded" "T31 — max-turns → phase 4 succeeded (partial)"
  assert_exit_code 0 "T31 — overall exit 0 (max-turns is not a real failure)"
  assert_log_contains p4-maxturns "max-turns budget" "T31 — log explains the bounded stop"

  # Cost is still recorded
  local manifest_cost
  manifest_cost=$(python3 -c "
import json
m = json.load(open('$GBRAIN_HOME/runs/p4-maxturns/manifest.json'))
print(m['phases']['4']['cost_actual_usd'])
")
  assert_equal "1.13" "$manifest_cost" "T31 — actual cost still recorded on max-turns"
}

# ─── T32: real claude failure (not max-turns) still marks phase failed ──────
test_phase4_real_failure_still_fails() {
  make_mock_claude_phase4
  make_stub_prompt_phase4
  seed_inbox
  # MOCK_CLAUDE_EXIT=1 without MOCK_CLAUDE_MAX_TURNS → emits success-shaped
  # JSON but exits 1. terminal_reason will be "" so the partial-success
  # branch should NOT trigger.
  export MOCK_CLAUDE_EXIT=1

  ~/bin/brain-run --weekly --no-mail --run-id=p4-realfail </dev/null >/dev/null 2>&1
  LAST_EXIT_CODE=$?
  unset MOCK_CLAUDE_EXIT

  assert_state p4-realfail 4 "failed" "T32 — non-max-turns failure still marks phase failed"
  assert_exit_code 1 "T32 — overall exit 1 on real failure"
}

# ─── Auto-scaling helpers (T_INBOX_AUTO_*) ───────────────────────────────────
# Counting mock: records each invocation as its own file so tests can assert
# how many subagents the wrapper spawned. Also simulates the agent marking
# files as enriched (so subsequent enumerations don't re-pick them).

make_mock_claude_phase4_counting() {
  local mock="$TEST_TMP/claude-mock"
  cat > "$mock" <<'SH'
#!/bin/sh
DIR="${MOCK_CLAUDE_INVOCATION_DIR:-$TEST_TMP/claude-invocations}"
mkdir -p "$DIR"
f=$(mktemp "$DIR/invocation-XXXXXX")
for a in "$@"; do printf '%s\n' "$a" >> "$f"; done

# Forward-only simulation: for each file we encounter, distinguish
# email (frontmatter has thread_id:) from non-email and act accordingly.
#   Email   → rm the file (matches the new delete-on-success default)
#   Email + archive: true tag → mv to sources/email/YYYY-MM/
#   Non-email → write `enriched: <date>` watermark (matches the docs flow)
# AUTO_* tests seed without thread_id, so they continue watermarking and
# their assertions remain valid. FORWARD_* tests seed with thread_id to
# exercise the delete path.
#
# Two arrival modes:
#   1) Parallel: the wrapper passes SUBAGENT_FILES: <paths…> in the prompt
#      argument. We extract and process exactly those.
#   2) Single-pass: no SUBAGENT_FILES; real agent would enumerate itself.
#      The mock simulates the same enumeration to keep test coverage honest.

process_one() {
  path="$1"
  [ -f "$path" ] || return 0
  if grep -q '^thread_id:' "$path" 2>/dev/null; then
    if grep -q '^archive: true' "$path" 2>/dev/null; then
      base=$(basename "$path")
      yyyymm=$(printf '%s' "$base" | sed -nE 's/^([0-9]{4})-([0-9]{2})-[0-9]{2}-.*/\1-\2/p')
      archive_dir="${BRAIN_DIR:-$HOME/brain}/sources/email/$yyyymm"
      mkdir -p "$archive_dir"
      mv "$path" "$archive_dir/$base"
    else
      rm -f "$path"
    fi
  else
    python3 - "$path" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
t = p.read_text()
parts = t.split('---', 2)
if len(parts) >= 3:
    p.write_text(parts[0] + '---' + parts[1].rstrip() + '\nenriched: 2026-05-18\n---' + parts[2])
PY
  fi
}

has_subagent_files=0
for a in "$@"; do
  case "$a" in
    *SUBAGENT_FILES:*)
      has_subagent_files=1
      files=$(printf '%s\n' "$a" | sed -n 's/.*SUBAGENT_FILES:[[:space:]]*//p')
      if [ "${MOCK_CLAUDE_SKIP_WATERMARK:-0}" != "1" ]; then
        for path in $files; do process_one "$path"; done
      fi
      ;;
  esac
done

# Single-pass mode: enumerate inbox/ ourselves the way the real agent would.
if [ "$has_subagent_files" = "0" ] && [ "${MOCK_CLAUDE_SKIP_WATERMARK:-0}" != "1" ]; then
  INBOX="${BRAIN_DIR:-$HOME/brain}/inbox"
  if [ -d "$INBOX" ]; then
    for f in "$INBOX"/*.md; do
      [ -f "$f" ] || continue
      base=$(basename "$f")
      [ "$base" = "README.md" ] && continue
      grep -q '^legacy-inbox:' "$f" 2>/dev/null && continue
      grep -q '^enriched:' "$f" 2>/dev/null && continue
      grep -q 'skip-enrich' "$f" 2>/dev/null && continue
      process_one "$f"
    done
  fi
fi

cost="${MOCK_CLAUDE_COST:-0.42}"
printf '{"type":"result","subtype":"success","is_error":false,"total_cost_usd":%s,"result":"mock done"}\n' "$cost"
exit "${MOCK_CLAUDE_EXIT:-0}"
SH
  chmod +x "$mock"
  export CLAUDE_BIN="$mock"
  export MOCK_CLAUDE_INVOCATION_DIR="$TEST_TMP/claude-invocations"
  rm -rf "$MOCK_CLAUDE_INVOCATION_DIR"
}

# Seed N inbox files shaped like real emails: frontmatter includes thread_id.
# The mock's forward-only path will DELETE these on success.
seed_inbox_email_n() {
  local n="$1" i dd ii
  mkdir -p "$BRAIN_DIR/inbox"
  for i in $(seq 1 $n); do
    dd=$(printf '%02d' $((i % 28 + 1)))
    ii=$(printf '%04d' $i)
    cat > "$BRAIN_DIR/inbox/2026-04-$dd-email-real-$ii.md" <<MD
---
type: inbox
tags: ["email"]
date: 2026-04-$dd
thread_id: mock-thread-$ii
---
# Mock email $i
MD
  done
}

# Seed one legacy file with the frozen-cohort marker.
seed_inbox_legacy_one() {
  local i="${1:-99}"
  mkdir -p "$BRAIN_DIR/inbox"
  cat > "$BRAIN_DIR/inbox/2026-04-01-email-legacy-$i.md" <<MD
---
type: inbox
tags: ["email"]
date: 2026-04-01
thread_id: legacy-thread-$i
enriched: 2026-04-15
legacy-inbox: 2026-05-19
---
# Legacy email $i (frozen cohort)
MD
}

# Seed one email with archive: true tag (archive-route exception).
seed_inbox_archive_one() {
  local i="${1:-1}" dd
  dd=$(printf '%02d' $((i % 28 + 1)))
  mkdir -p "$BRAIN_DIR/inbox"
  cat > "$BRAIN_DIR/inbox/2026-04-$dd-email-archive-$i.md" <<MD
---
type: inbox
tags: ["email"]
date: 2026-04-$dd
thread_id: archive-thread-$i
archive: true
---
# Archive email $i (unique content path)
MD
}

seed_inbox_n() {
  local n="$1" i dd ii
  mkdir -p "$BRAIN_DIR/inbox"
  for i in $(seq 1 $n); do
    dd=$(printf '%02d' $((i % 28 + 1)))
    ii=$(printf '%04d' $i)
    cat > "$BRAIN_DIR/inbox/2026-04-$dd-email-fake-$ii.md" <<MD
---
type: inbox
tags: [email]
---
# Fake email $i
MD
  done
}

count_invocations() {
  ls "$MOCK_CLAUDE_INVOCATION_DIR" 2>/dev/null | grep -c '^invocation-' | tr -d ' '
}

# ─── T_INBOX_AUTO_1: 0 unprocessed → exit clean, no claude invocations ──────
test_inbox_auto_zero_files() {
  make_mock_claude_phase4_counting
  make_stub_prompt_phase4
  mkdir -p "$BRAIN_DIR/inbox"
  # No files seeded.

  ~/bin/brain-run --weekly --no-mail --no-granola --run-id=auto-zero </dev/null >/dev/null 2>&1
  LAST_EXIT_CODE=$?

  assert_state auto-zero 4 "succeeded" "T_INBOX_AUTO_1 — phase 4 succeeded on empty inbox"
  assert_exit_code 0 "T_INBOX_AUTO_1 — exit 0"
  assert_equal "0" "$(count_invocations)" "T_INBOX_AUTO_1 — no claude invocations"
  assert_log_contains auto-zero "inbox empty" "T_INBOX_AUTO_1 — log says inbox empty"
}

# ─── T_INBOX_AUTO_2: 5 files → 1 invocation (single-pass) ───────────────────
test_inbox_auto_single_pass() {
  make_mock_claude_phase4_counting
  make_stub_prompt_phase4
  seed_inbox_n 5

  ~/bin/brain-run --weekly --no-mail --no-granola --run-id=auto-single </dev/null >/dev/null 2>&1

  assert_state auto-single 4 "succeeded" "T_INBOX_AUTO_2 — phase 4 succeeded on 5 files"
  assert_equal "1" "$(count_invocations)" "T_INBOX_AUTO_2 — single claude invocation"
  local args
  args=$(cat "$MOCK_CLAUDE_INVOCATION_DIR"/invocation-* 2>/dev/null)
  if echo "$args" | grep -q "SUBAGENT_FILES:"; then
    _fail "T_INBOX_AUTO_2 — single-pass should NOT pass SUBAGENT_FILES"
  else
    _pass "T_INBOX_AUTO_2 — single-pass omits SUBAGENT_FILES"
  fi
}

# ─── T_INBOX_AUTO_3: 15 files → 2 subagents (parallel) ──────────────────────
test_inbox_auto_15_files_two_subagents() {
  make_mock_claude_phase4_counting
  make_stub_prompt_phase4
  seed_inbox_n 15

  ~/bin/brain-run --weekly --no-mail --no-granola --run-id=auto-15 </dev/null >/dev/null 2>&1

  assert_state auto-15 4 "succeeded" "T_INBOX_AUTO_3 — phase 4 succeeded on 15 files"
  assert_equal "2" "$(count_invocations)" "T_INBOX_AUTO_3 — exactly 2 subagents (10+5)"
  local sub_count
  sub_count=$(grep -l "SUBAGENT_FILES:" "$MOCK_CLAUDE_INVOCATION_DIR"/invocation-* 2>/dev/null | wc -l | tr -d ' ')
  assert_equal "2" "$sub_count" "T_INBOX_AUTO_3 — both invocations are subagent mode"
}

# ─── T_INBOX_AUTO_4: 75 files → 8 subagents (--force-inbox required) ────────
test_inbox_auto_75_files_eight_subagents() {
  make_mock_claude_phase4_counting
  make_stub_prompt_phase4
  seed_inbox_n 75

  # 75 × $0.15 = $11.25 → exceeds $10 confirm; needs --force-inbox in tests.
  ~/bin/brain-run --weekly --no-mail --no-granola --force-inbox --run-id=auto-75 </dev/null >/dev/null 2>&1

  assert_state auto-75 4 "succeeded" "T_INBOX_AUTO_4 — phase 4 succeeded on 75 files"
  assert_equal "8" "$(count_invocations)" "T_INBOX_AUTO_4 — exactly 8 subagent batches"
}

# ─── T_INBOX_AUTO_5: 150 files → cost-guard refusal / --force-large allow ───
test_inbox_auto_150_files_cost_guard() {
  make_mock_claude_phase4_counting
  make_stub_prompt_phase4
  seed_inbox_n 150

  # Without flags: refused (non-interactive + >$10)
  ~/bin/brain-run --weekly --no-mail --no-granola --run-id=auto-150 </dev/null >/dev/null 2>&1

  assert_state auto-150 4 "failed" "T_INBOX_AUTO_5 — refused without flags"
  assert_log_contains auto-150 "cost guard" "T_INBOX_AUTO_5 — log mentions cost guard"
  assert_equal "0" "$(count_invocations)" "T_INBOX_AUTO_5 — no subagents when refused"

  # With --force-large (implies --force-inbox): 15 batches
  rm -rf "$MOCK_CLAUDE_INVOCATION_DIR"
  ~/bin/brain-run --weekly --no-mail --no-granola --force-large --run-id=auto-150-force </dev/null >/dev/null 2>&1
  assert_state auto-150-force 4 "succeeded" "T_INBOX_AUTO_5 — --force-large allows the run"
  assert_equal "15" "$(count_invocations)" "T_INBOX_AUTO_5 — 15 batches spawned with force"
}

# ─── T_INBOX_AUTO_6: subagent failure → split-in-half retry ─────────────────
# Mock uses mkdir-lock for deterministic single-failure under parallelism.
test_inbox_auto_subagent_failure_retry() {
  local mock="$TEST_TMP/claude-mock"
  cat > "$mock" <<'SH'
#!/bin/sh
DIR="${MOCK_CLAUDE_INVOCATION_DIR:-$TEST_TMP/claude-invocations}"
mkdir -p "$DIR"
f=$(mktemp "$DIR/invocation-XXXXXX")
for a in "$@"; do printf '%s\n' "$a" >> "$f"; done

LOCK="$DIR/.first-invocation-lock"
if mkdir "$LOCK" 2>/dev/null; then
  printf '{"type":"result","subtype":"error","is_error":true,"total_cost_usd":0.0,"errors":["mock-first-fail"]}\n'
  exit 1
fi
printf '{"type":"result","subtype":"success","is_error":false,"total_cost_usd":0.42,"result":"mock done"}\n'
exit 0
SH
  chmod +x "$mock"
  export CLAUDE_BIN="$mock"
  export MOCK_CLAUDE_INVOCATION_DIR="$TEST_TMP/claude-invocations"
  rm -rf "$MOCK_CLAUDE_INVOCATION_DIR"

  make_stub_prompt_phase4
  seed_inbox_n 20  # 2 batches (10+10) — no canary, both run; one fails, retried as 5+5

  ~/bin/brain-run --weekly --no-mail --no-granola --run-id=auto-retry </dev/null >/dev/null 2>&1

  # Expected: 1 initial fail + 1 initial ok + 2 retry halves = 4 invocations
  assert_state auto-retry 4 "succeeded" "T_INBOX_AUTO_6 — phase 4 succeeded after split retry"
  assert_equal "4" "$(count_invocations)" "T_INBOX_AUTO_6 — 4 invocations (1 fail + 1 ok + 2 retry halves)"
  assert_log_contains auto-retry "split-in-half retry" "T_INBOX_AUTO_6 — log records the retry"
}

# ─── Forward-only tests (T_INBOX_FORWARD_*) ─────────────────────────────────
# These cover the 2026-05-19 forward-only flow: legacy-inbox skip,
# email-delete-on-success, archive-route exception, prompt content rules.

PROMPT_INBOX_REAL="$HOME/bin/prompts/inbox-enrich.md"
SKILL_INBOX_REAL="$HOME/bin/skills/inbox-enrich/SKILL.md"

# T_INBOX_FORWARD_1: enumeration skips files with legacy-inbox: marker.
# Seed 3 fresh emails + 2 legacy. Expect single-pass (5 → 1 invocation
# over the 3 fresh files, since 2 are skipped). After run, the 2 legacy
# files remain untouched on disk.
test_inbox_forward_legacy_skip() {
  make_mock_claude_phase4_counting
  make_stub_prompt_phase4
  seed_inbox_email_n 3
  seed_inbox_legacy_one 1
  seed_inbox_legacy_one 2

  ~/bin/brain-run --weekly --no-mail --no-granola --run-id=fwd-legacy </dev/null >/dev/null 2>&1

  assert_state fwd-legacy 4 "succeeded" "T_INBOX_FORWARD_1 — phase 4 succeeded"
  assert_equal "1" "$(count_invocations)" "T_INBOX_FORWARD_1 — single-pass (3 fresh; 2 legacy skipped)"
  # Legacy files must survive untouched
  assert_file_exists "$BRAIN_DIR/inbox/2026-04-01-email-legacy-1.md" "T_INBOX_FORWARD_1 — legacy file 1 untouched"
  assert_file_exists "$BRAIN_DIR/inbox/2026-04-01-email-legacy-2.md" "T_INBOX_FORWARD_1 — legacy file 2 untouched"
}

# T_INBOX_FORWARD_2: emails get deleted from inbox/ after successful enrichment.
# Seed 5 email-shaped files (thread_id present). The mock deletes them.
# Phase-4 metric should report 5 fully processed.
test_inbox_forward_email_delete() {
  make_mock_claude_phase4_counting
  make_stub_prompt_phase4
  seed_inbox_email_n 5

  ~/bin/brain-run --weekly --no-mail --no-granola --run-id=fwd-delete </dev/null >/dev/null 2>&1

  assert_state fwd-delete 4 "succeeded" "T_INBOX_FORWARD_2 — phase 4 succeeded"
  # All 5 should be gone from inbox/
  local remaining
  remaining=$(find "$BRAIN_DIR/inbox" -maxdepth 1 -name "2026-04-*-email-real-*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  assert_equal "0" "$remaining" "T_INBOX_FORWARD_2 — all 5 emails deleted from inbox/"
  local metric
  metric=$(<"$GBRAIN_HOME/runs/fwd-delete/phase-4.metric.processed")
  assert_equal "5" "$metric" "T_INBOX_FORWARD_2 — metric reports 5 emails fully processed"
}

# T_INBOX_FORWARD_3: files with `archive: true` route to sources/email/YYYY-MM/.
# Seed 1 archive-marked email; expect it to land in sources/email/2026-04/.
test_inbox_forward_archive_route() {
  make_mock_claude_phase4_counting
  make_stub_prompt_phase4
  seed_inbox_archive_one 1

  ~/bin/brain-run --weekly --no-mail --no-granola --run-id=fwd-archive </dev/null >/dev/null 2>&1

  assert_state fwd-archive 4 "succeeded" "T_INBOX_FORWARD_3 — phase 4 succeeded"
  # File moved to sources/email/YYYY-MM/
  local moved
  moved=$(find "$BRAIN_DIR/sources/email" -name "2026-*-email-archive-1.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  assert_equal "1" "$moved" "T_INBOX_FORWARD_3 — archive-tagged file moved to sources/email/"
  # And gone from inbox/
  local in_inbox
  in_inbox=$(find "$BRAIN_DIR/inbox" -maxdepth 1 -name "2026-*-email-archive-1.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  assert_equal "0" "$in_inbox" "T_INBOX_FORWARD_3 — archive file removed from inbox/"
}

# T_INBOX_FORWARD_4: real prompt declares the gmail citation form and the
# re-entry guard. Asserts against the live ~/bin/prompts/inbox-enrich.md
# rather than the stub. This is the contract test for the prompt itself.
test_inbox_forward_prompt_contract() {
  assert_file_exists "$PROMPT_INBOX_REAL" "T_INBOX_FORWARD_4 — real prompt exists"
  assert_file_contains "$PROMPT_INBOX_REAL" "gmail:<thread-id>" "T_INBOX_FORWARD_4 — prompt uses gmail:<thread-id> citation form"
  assert_file_contains "$PROMPT_INBOX_REAL" "mail.google.com/mail/u/0" "T_INBOX_FORWARD_4 — prompt builds clickable Gmail URL"
  assert_file_contains "$PROMPT_INBOX_REAL" "Re-entry guard" "T_INBOX_FORWARD_4 — prompt has Re-entry guard rule"
  assert_file_contains "$PROMPT_INBOX_REAL" "legacy-inbox" "T_INBOX_FORWARD_4 — prompt enumerates legacy-inbox skip"
  # No legacy citation form in the prompt's forward instructions
  if grep -nE '\[Source: \[\[inbox/' "$PROMPT_INBOX_REAL" >/dev/null 2>&1; then
    _fail "T_INBOX_FORWARD_4 — prompt still emits [Source: [[inbox/...]]] (legacy citation form)"
  else
    _pass "T_INBOX_FORWARD_4 — prompt does not emit legacy [[inbox/...]] citations"
  fi
}

# T_INBOX_FORWARD_5: real prompt declares the mechanical dedup criteria
# (email local-part vs email: frontmatter OR exact name in aliases: list).
test_inbox_forward_dedup_contract() {
  assert_file_exists "$PROMPT_INBOX_REAL" "T_INBOX_FORWARD_5 — real prompt exists"
  assert_file_contains "$PROMPT_INBOX_REAL" "Mechanical alias dedup" "T_INBOX_FORWARD_5 — prompt names the dedup step"
  assert_file_contains "$PROMPT_INBOX_REAL" "email local-part" "T_INBOX_FORWARD_5 — prompt criterion (a) names email-local-part match"
  assert_file_contains "$PROMPT_INBOX_REAL" "aliases:" "T_INBOX_FORWARD_5 — prompt criterion (b) references aliases: list"
  # New stubs include aliases: in frontmatter
  assert_file_contains "$PROMPT_INBOX_REAL" "aliases: [\"<full display name>\"" "T_INBOX_FORWARD_5 — stub template includes aliases:"
}

# ─── Driver ──────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "  Phase 4 tests (inbox & enrich, mocked claude) — T25–T32 + AUTO_1–6 + FORWARD_1–5"
echo "═══════════════════════════════════════════════════════════════"

run_test "T25a: phase 4 runs under --weekly"               test_phase4_runs_under_weekly
run_test "T25b: phase 4 skipped under --quick"             test_phase4_skipped_under_quick
run_test "T25c: phase 4 skipped under --no-enrich"         test_phase4_skipped_with_no_enrich_flag
run_test "T26: phase 4 invokes claude with right flags"    test_phase4_invokes_claude_with_right_flags
run_test "T27: phase 4 logs estimate before actual"        test_phase4_logs_estimate_then_actual
run_test "T28: phase 4 missing prompt fails cleanly"       test_phase4_missing_prompt_fails_cleanly
run_test "T29: phase 4 does not touch cal-mail watermark"  test_phase4_does_not_touch_watermark
run_test "T30: phase 4 records inbox delta metric"         test_phase4_records_inbox_delta
run_test "T31: max-turns is partial success, not failure"  test_phase4_max_turns_is_partial_success
run_test "T32: real failure still marks phase failed"      test_phase4_real_failure_still_fails

run_test "T_INBOX_AUTO_1: 0 files → exit clean"            test_inbox_auto_zero_files
run_test "T_INBOX_AUTO_2: 5 files → single-pass"           test_inbox_auto_single_pass
run_test "T_INBOX_AUTO_3: 15 files → 2 subagents"          test_inbox_auto_15_files_two_subagents
run_test "T_INBOX_AUTO_4: 75 files → 8 subagents"          test_inbox_auto_75_files_eight_subagents
run_test "T_INBOX_AUTO_5: 150 files → cost guard"          test_inbox_auto_150_files_cost_guard
run_test "T_INBOX_AUTO_6: subagent fail → split retry"     test_inbox_auto_subagent_failure_retry

run_test "T_INBOX_FORWARD_1: legacy-inbox skipped"         test_inbox_forward_legacy_skip
run_test "T_INBOX_FORWARD_2: emails deleted on success"    test_inbox_forward_email_delete
run_test "T_INBOX_FORWARD_3: archive: true routes file"    test_inbox_forward_archive_route
run_test "T_INBOX_FORWARD_4: prompt has gmail citation"    test_inbox_forward_prompt_contract
run_test "T_INBOX_FORWARD_5: prompt has dedup criteria"    test_inbox_forward_dedup_contract

print_summary
