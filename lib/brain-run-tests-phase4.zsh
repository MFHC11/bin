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
  assert_file_contains "$cost_log" '"cost_usd": 2.0' "T27 — estimate of \$2.00"
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

# ─── Driver ──────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "  Phase 4 tests (inbox & enrich, mocked claude) — T25–T32"
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

print_summary
