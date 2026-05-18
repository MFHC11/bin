#!/bin/zsh
# brain-run-tests-cost.zsh — unit tests for record_cost().
# Sources brain-run as a library (BRAIN_RUN_LIB_MODE=1) so it can call the
# function directly without spending real LLM dollars.

set -uo pipefail

source "$HOME/bin/lib/brain-run-test.zsh"

# Helper: set up a fake run context, source brain-run, expose record_cost.
_load_brain_run_lib() {
  export BRAIN_RUN_LIB_MODE=1
  export COST_LOG="$TEST_TMP/cost.jsonl"
  export RUN_ID="cost-unit-test"
  source "$HOME/bin/brain-run"
}

test_record_cost_writes_jsonl_line() {
  _load_brain_run_lib
  record_cost 3 claude-sonnet-4-6 0.42

  assert_file_exists "$COST_LOG" "T6 — cost log file created"

  local line_count
  line_count=$(wc -l < "$COST_LOG" | tr -d ' ')
  assert_equal "1" "$line_count" "T6 — exactly one line written"

  assert_file_contains "$COST_LOG" '"phase": 3' "T6 — phase number recorded"
  assert_file_contains "$COST_LOG" '"model": "claude-sonnet-4-6"' "T6 — model recorded"
  assert_file_contains "$COST_LOG" '"cost_usd": 0.42' "T6 — cost recorded"
  assert_file_contains "$COST_LOG" '"run_id": "cost-unit-test"' "T6 — run_id recorded"
  assert_file_contains "$COST_LOG" '"ts":' "T6 — timestamp field present"

  # Validate JSON structure
  local valid_json
  valid_json=$(python3 -c "
import json
with open('$COST_LOG') as f:
    for ln in f:
        d = json.loads(ln)
        assert 'run_id' in d and 'phase' in d and 'model' in d
        assert 'cost_usd' in d and 'ts' in d
print('ok')
" 2>&1)
  assert_equal "ok" "$valid_json" "T6 — every line is valid JSON with required keys"
}

test_record_cost_appends_not_overwrites() {
  _load_brain_run_lib
  record_cost 3 claude-sonnet-4-6 0.42
  record_cost 4 claude-sonnet-4-6 1.87
  record_cost 6 claude-opus-4-7 6.06

  local line_count
  line_count=$(wc -l < "$COST_LOG" | tr -d ' ')
  assert_equal "3" "$line_count" "T7 — 3 lines after 3 appends"

  assert_file_contains "$COST_LOG" '"phase": 3' "T7 — phase 3 line present"
  assert_file_contains "$COST_LOG" '"phase": 4' "T7 — phase 4 line present"
  assert_file_contains "$COST_LOG" '"phase": 6' "T7 — phase 6 line present"
  assert_file_contains "$COST_LOG" '"cost_usd": 6.06' "T7 — Opus cost recorded"
}

test_record_cost_updates_phase_cost_array() {
  _load_brain_run_lib
  # PHASE_COST starts empty in lib mode (no run state initialized)
  record_cost 3 claude-sonnet-4-6 0.42

  assert_equal "0.42" "${PHASE_COST[3]}" "T8 — PHASE_COST[3] reflects the recorded cost"

  # Overwrite (e.g., on resume re-running the phase)
  record_cost 3 claude-sonnet-4-6 0.99
  assert_equal "0.99" "${PHASE_COST[3]}" "T8 — PHASE_COST[3] overwrites on second call"

  # Other phases unaffected
  record_cost 4 claude-sonnet-4-6 1.87
  assert_equal "0.99" "${PHASE_COST[3]}" "T8 — PHASE_COST[3] unaffected by phase 4 record"
  assert_equal "1.87" "${PHASE_COST[4]}" "T8 — PHASE_COST[4] reflects its own recorded cost"
}

test_record_cost_creates_parent_dir() {
  _load_brain_run_lib
  # Point COST_LOG at a path whose parent doesn't yet exist
  COST_LOG="$TEST_TMP/nested/dir/cost.jsonl"
  record_cost 3 claude-sonnet-4-6 0.42

  assert_file_exists "$TEST_TMP/nested/dir" "T9 — record_cost creates parent directories"
  assert_file_exists "$COST_LOG" "T9 — cost log written into nested path"
}

# ─── Driver ──────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "  brain-run cost-capture tests — T6, T7, T8, T9"
echo "═══════════════════════════════════════════════════════════════"

run_test "T6: record_cost writes JSONL line"      test_record_cost_writes_jsonl_line
run_test "T7: record_cost appends, doesn't overwrite" test_record_cost_appends_not_overwrites
run_test "T8: record_cost updates PHASE_COST"     test_record_cost_updates_phase_cost_array
run_test "T9: record_cost creates parent dir"     test_record_cost_creates_parent_dir

print_summary
