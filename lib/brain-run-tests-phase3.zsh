#!/bin/zsh
# brain-run-tests-phase3.zsh — tests for Phase 3 (cal-mail sync).
# Uses a mock `claude` binary so no real LLM calls are made (cost: $0).

set -uo pipefail

source "$HOME/bin/lib/brain-run-test.zsh"

# ─── Mock claude factory ─────────────────────────────────────────────────────
# Writes a stub `claude` CLI to $TEST_TMP/claude-mock that:
#   - records its argv to $TEST_TMP/claude-args.txt for inspection
#   - writes a fake watermark to $BRAIN_DIR/.last-email-sync (simulating what
#     real Phase 3 prompt would do via the agent's Write tool)
#   - emits JSON result with the configured total_cost_usd
#   - exits with the configured code
#
# Tunables (env vars):
#   MOCK_CLAUDE_COST=0.42      cost for the JSON output
#   MOCK_CLAUDE_EXIT=0         exit code (1 for failure tests)
#   MOCK_CLAUDE_WATERMARK=...  what to write to .last-email-sync
#   MOCK_CLAUDE_NO_WATERMARK=1 don't write the watermark (failure path)
make_mock_claude() {
  local mock="$TEST_TMP/claude-mock"
  cat > "$mock" <<'SH'
#!/bin/sh
# Record argv (one arg per line) for the test to inspect
ARGS_FILE="${MOCK_CLAUDE_ARGS_FILE:-$TEST_TMP/claude-args.txt}"
: > "$ARGS_FILE"
for a in "$@"; do
  printf '%s\n' "$a" >> "$ARGS_FILE"
done

# Simulate the agent updating the watermark (the real prompt's hard rule
# says claude must write it ONLY at end after all writes succeed).
if [ -z "${MOCK_CLAUDE_NO_WATERMARK:-}" ] && [ -n "${BRAIN_DIR:-}" ]; then
  echo "${MOCK_CLAUDE_WATERMARK:-2026-05-08T12:00:00+0000}" > "$BRAIN_DIR/.last-email-sync"
fi

# Emit JSON to stdout (claude --output-format json shape)
cost="${MOCK_CLAUDE_COST:-0.42}"
printf '{"type":"result","subtype":"success","is_error":false,"total_cost_usd":%s,"result":"mock done"}\n' "$cost"

exit "${MOCK_CLAUDE_EXIT:-0}"
SH
  chmod +x "$mock"
  export CLAUDE_BIN="$mock"
  export MOCK_CLAUDE_ARGS_FILE="$TEST_TMP/claude-args.txt"
}

# Stub prompt file for Phase 3
make_stub_prompt() {
  local prompt="$TEST_TMP/cal-mail-prompt.md"
  cat > "$prompt" <<'MD'
# Test stub prompt
You are a mock agent. Do nothing. Exit cleanly.
MD
  export PROMPT_CALMAIL="$prompt"
}

# ─── T19: Phase 3 runs under --weekly, skipped under --quick ─────────────────
test_phase3_runs_under_weekly() {
  make_mock_claude
  make_stub_prompt
  ~/bin/brain-run --weekly --no-enrich --run-id=p3-weekly </dev/null >/dev/null 2>&1
  LAST_EXIT_CODE=$?

  assert_state p3-weekly 3 "succeeded" "T19 — phase 3 runs and succeeds under --weekly"
  assert_exit_code 0 "T19 — exit 0 on clean weekly run"
}

test_phase3_skipped_under_quick() {
  make_mock_claude
  make_stub_prompt
  ~/bin/brain-run --quick --run-id=p3-quick </dev/null >/dev/null 2>&1
  LAST_EXIT_CODE=$?

  assert_state p3-quick 3 "" "T19 — phase 3 NOT started under --quick (state file absent)"
  assert_exit_code 0 "T19 — quick run still exits 0"
}

test_phase3_skipped_with_no_mail_flag() {
  make_mock_claude
  make_stub_prompt
  ~/bin/brain-run --weekly --no-mail --run-id=p3-nomail </dev/null >/dev/null 2>&1
  LAST_EXIT_CODE=$?

  assert_state p3-nomail 3 "skipped" "T19 — phase 3 skipped under --no-mail"
  assert_exit_code 0 "T19 — --no-mail run exits 0"
}

# ─── T20: Phase 3 invokes claude with the right flags ────────────────────────
test_phase3_invokes_claude_with_right_flags() {
  make_mock_claude
  make_stub_prompt
  ~/bin/brain-run --weekly --no-enrich --run-id=p3-args </dev/null >/dev/null 2>&1

  assert_file_exists "$MOCK_CLAUDE_ARGS_FILE" "T20 — claude was invoked"

  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "--model" "T20 — --model flag passed"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "claude-sonnet-4-6" "T20 — Sonnet 4.6 model"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "--max-turns" "T20 — --max-turns flag"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "30" "T20 — max-turns=30"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "--allowedTools" "T20 — --allowedTools flag"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "mcp__claude_ai_Gmail__" "T20 — Gmail tools granted"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "mcp__claude_ai_Google_Calendar__" "T20 — Calendar tools granted"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "--output-format" "T20 — --output-format flag"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "json" "T20 — output format json (for cost capture)"
  assert_file_contains "$MOCK_CLAUDE_ARGS_FILE" "--print" "T20 — --print flag (headless)"
}

# ─── T21: cost estimate logged before actual ─────────────────────────────────
test_phase3_logs_estimate_then_actual() {
  make_mock_claude
  make_stub_prompt
  export MOCK_CLAUDE_COST=0.73
  ~/bin/brain-run --weekly --no-enrich --run-id=p3-cost </dev/null >/dev/null 2>&1
  unset MOCK_CLAUDE_COST

  local cost_log="$GBRAIN_HOME/cost-30d.jsonl"
  assert_file_exists "$cost_log" "T21 — cost log written"

  local est_count
  est_count=$(grep -c '"phase": 3' "$cost_log" 2>/dev/null || echo 0)
  est_count=$(echo "$est_count" | tr -d ' ')
  assert_greater_than "$est_count" 1 "T21 — at least 2 lines for phase 3 (estimate + actual)"

  assert_file_contains "$cost_log" '"kind": "estimate"' "T21 — estimate kind logged"
  assert_file_contains "$cost_log" '"kind": "actual"' "T21 — actual kind logged"
  assert_file_contains "$cost_log" '"cost_usd": 1.0' "T21 — estimate of \$1.00"
  assert_file_contains "$cost_log" '"cost_usd": 0.73' "T21 — actual of \$0.73 (mock JSON)"

  # Estimate must come BEFORE actual in the log (audit ordering)
  local first_line
  first_line=$(grep '"phase": 3' "$cost_log" | head -1)
  if echo "$first_line" | grep -q '"kind": "estimate"'; then
    _pass "T21 — estimate line precedes actual"
  else
    _fail "T21 — estimate should come first, but first phase-3 line is:" "$first_line"
  fi

  # Manifest reflects actual cost
  local manifest_cost
  manifest_cost=$(python3 -c "
import json
m = json.load(open('$GBRAIN_HOME/runs/p3-cost/manifest.json'))
print(m['phases']['3']['cost_actual_usd'])
")
  assert_equal "0.73" "$manifest_cost" "T21 — manifest's cost_actual_usd matches"
}

# ─── T22: watermark restored on Phase 3 failure ──────────────────────────────
test_phase3_watermark_restored_on_failure() {
  make_mock_claude
  make_stub_prompt
  echo "2026-05-01T00:00:00+0000" > "$BRAIN_DIR/.last-email-sync"
  local before
  before=$(<"$BRAIN_DIR/.last-email-sync")

  # Mock claude advances watermark THEN exits 1
  export MOCK_CLAUDE_EXIT=1
  ~/bin/brain-run --weekly --no-enrich --run-id=p3-fail </dev/null >/dev/null 2>&1
  LAST_EXIT_CODE=$?
  unset MOCK_CLAUDE_EXIT

  assert_state p3-fail 3 "failed" "T22 — phase 3 marked failed"
  assert_exit_code 1 "T22 — overall exit 1 when phase 3 fails"

  local after
  after=$(<"$BRAIN_DIR/.last-email-sync")
  assert_equal "$before" "$after" "T22 — watermark restored to pre-call value"

  # Status file reflects the failure
  local status_file="$GBRAIN_HOME/last-run.json"
  assert_file_contains "$status_file" '"status": "failed"' "T22 — status file shows failed"
  assert_file_contains "$status_file" '3' "T22 — failed_phases includes 3"
}

# ─── T23: watermark advances on Phase 3 success ──────────────────────────────
test_phase3_watermark_advances_on_success() {
  make_mock_claude
  make_stub_prompt
  echo "2026-05-01T00:00:00+0000" > "$BRAIN_DIR/.last-email-sync"
  export MOCK_CLAUDE_WATERMARK="2026-05-08T12:00:00+0000"

  ~/bin/brain-run --weekly --no-enrich --run-id=p3-ok </dev/null >/dev/null 2>&1
  LAST_EXIT_CODE=$?
  unset MOCK_CLAUDE_WATERMARK

  assert_state p3-ok 3 "succeeded" "T23 — phase 3 succeeded"

  local after
  after=$(<"$BRAIN_DIR/.last-email-sync")
  assert_equal "2026-05-08T12:00:00+0000" "$after" "T23 — watermark advanced to mock-set value"
}

# ─── T24: missing prompt file → clean failure ────────────────────────────────
test_phase3_missing_prompt_fails_cleanly() {
  make_mock_claude
  export PROMPT_CALMAIL="$TEST_TMP/does-not-exist.md"

  ~/bin/brain-run --weekly --no-enrich --run-id=p3-noprompt </dev/null >/dev/null 2>&1
  LAST_EXIT_CODE=$?

  assert_state p3-noprompt 3 "failed" "T24 — phase 3 fails when prompt missing"
  assert_exit_code 1 "T24 — overall exit 1"
  assert_log_contains p3-noprompt "prompt file missing" "T24 — log explains the missing prompt"
}

# ─── Driver ──────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "  Phase 3 tests (cal-mail sync, mocked claude) — T19–T24"
echo "═══════════════════════════════════════════════════════════════"

run_test "T19a: phase 3 runs under --weekly"               test_phase3_runs_under_weekly
run_test "T19b: phase 3 skipped under --quick"             test_phase3_skipped_under_quick
run_test "T19c: phase 3 skipped under --no-mail"           test_phase3_skipped_with_no_mail_flag
run_test "T20: phase 3 invokes claude with right flags"    test_phase3_invokes_claude_with_right_flags
run_test "T21: phase 3 logs estimate before actual"        test_phase3_logs_estimate_then_actual
run_test "T22: phase 3 watermark restored on failure"      test_phase3_watermark_restored_on_failure
run_test "T23: phase 3 watermark advances on success"      test_phase3_watermark_advances_on_success
run_test "T24: phase 3 missing prompt fails cleanly"       test_phase3_missing_prompt_fails_cleanly

print_summary
