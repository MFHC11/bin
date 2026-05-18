#!/bin/zsh
# brain-run-tests-features.zsh — tests for Opus review items 3, 4, 5:
# T10–T12: cost estimate vs actual (item 4)
# T13–T15: status file for Automator (item 5)
# T16–T18: watermark guard (item 3)

set -uo pipefail

source "$HOME/bin/lib/brain-run-test.zsh"

_load_brain_run_lib() {
  export BRAIN_RUN_LIB_MODE=1
  export COST_LOG="$TEST_TMP/cost.jsonl"
  export RUN_ID="features-test"
  export STATUS_FILE="$TEST_TMP/last-run.json"
  source "$HOME/bin/brain-run"
}

# ═════════════════════════════════════════════════════════════════════════════
# Item 4 — separate cost estimate from actual
# ═════════════════════════════════════════════════════════════════════════════

test_record_cost_estimate_logs_kind_estimate() {
  _load_brain_run_lib
  record_cost_estimate 3 claude-sonnet-4-6 1.00

  assert_file_contains "$COST_LOG" '"kind": "estimate"' "T10 — kind=estimate logged"
  assert_file_contains "$COST_LOG" '"phase": 3' "T10 — phase recorded"
  assert_file_contains "$COST_LOG" '"cost_usd": 1.0' "T10 — estimate cost recorded"
  assert_equal "1.00" "${PHASE_COST_ESTIMATE[3]}" "T10 — PHASE_COST_ESTIMATE[3] populated"
  # Estimate must NOT touch PHASE_COST (which is the actual)
  assert_equal "" "${PHASE_COST[3]:-}" "T10 — estimate doesn't update PHASE_COST"
}

test_record_cost_actual_logs_kind_actual() {
  _load_brain_run_lib
  record_cost_actual 3 claude-sonnet-4-6 0.87

  assert_file_contains "$COST_LOG" '"kind": "actual"' "T11 — kind=actual logged"
  assert_file_contains "$COST_LOG" '"cost_usd": 0.87' "T11 — actual cost recorded"
  assert_equal "0.87" "${PHASE_COST[3]}" "T11 — PHASE_COST[3] populated (manifest source)"
  assert_equal "0.87" "${PHASE_COST_ACTUAL[3]}" "T11 — PHASE_COST_ACTUAL[3] populated"
}

test_estimate_then_actual_both_logged() {
  _load_brain_run_lib
  record_cost_estimate 3 claude-sonnet-4-6 1.00
  record_cost_actual 3 claude-sonnet-4-6 0.87

  local lines
  lines=$(wc -l < "$COST_LOG" | tr -d ' ')
  assert_equal "2" "$lines" "T12 — both lines written"

  local est_count
  est_count=$(grep -c '"kind": "estimate"' "$COST_LOG")
  local act_count
  act_count=$(grep -c '"kind": "actual"' "$COST_LOG")
  assert_equal "1" "$est_count" "T12 — exactly 1 estimate line"
  assert_equal "1" "$act_count" "T12 — exactly 1 actual line"

  assert_equal "1.00" "${PHASE_COST_ESTIMATE[3]}" "T12 — estimate preserved across actual"
  assert_equal "0.87" "${PHASE_COST[3]}" "T12 — actual is the canonical PHASE_COST"
}

test_record_cost_backward_compat_alias() {
  _load_brain_run_lib
  # Legacy callers: `record_cost` should still work as alias for actual
  record_cost 3 claude-sonnet-4-6 0.42

  assert_file_contains "$COST_LOG" '"kind": "actual"' "T12b — alias logs as actual"
  assert_equal "0.42" "${PHASE_COST[3]}" "T12b — alias updates PHASE_COST"
}

# ═════════════════════════════════════════════════════════════════════════════
# Item 5 — Automator-readable status file
# ═════════════════════════════════════════════════════════════════════════════

# Helper: run brain-run --quick under the test fixture and verify $STATUS_FILE
_run_quick_and_get_status() {
  local extra_env="${1:-}"
  # Use the harness's setup of a tmp brain. Override STATUS_FILE per-run.
  export STATUS_FILE="$GBRAIN_HOME/last-run.json"
  if [ -n "$extra_env" ]; then
    eval "$extra_env ~/bin/brain-run --quick --run-id=feat-1 </dev/null >/dev/null 2>&1"
  else
    ~/bin/brain-run --quick --run-id=feat-1 </dev/null >/dev/null 2>&1
  fi
  LAST_EXIT_CODE=$?
}

test_status_file_succeeded_on_clean_run() {
  _run_quick_and_get_status

  assert_file_exists "$STATUS_FILE" "T13 — status file written"

  local s_status
  s_status=$(python3 -c "import json; print(json.load(open('$STATUS_FILE'))['status'])" 2>/dev/null || echo "?")
  assert_equal "succeeded" "$s_status" "T13 — status=succeeded on clean run"

  local exit_code
  exit_code=$(python3 -c "import json; print(json.load(open('$STATUS_FILE'))['exit_code'])" 2>/dev/null || echo "?")
  assert_equal "0" "$exit_code" "T13 — exit_code=0"

  # Required fields for Automator
  assert_file_contains "$STATUS_FILE" '"run_id"' "T13 — run_id field present"
  assert_file_contains "$STATUS_FILE" '"failed_phases"' "T13 — failed_phases field present"
  assert_file_contains "$STATUS_FILE" '"report_path"' "T13 — report_path field present"
}

test_status_file_failed_when_phase_fails() {
  # Override granola binary to fail. Phase 2 will mark itself failed; the
  # script continues but ANY_PHASE_FAILED is set, exit code is 1, status_file
  # should reflect failure.
  export GRANOLA_BIN=/usr/bin/false
  ~/bin/brain-run --quick --run-id=feat-fail </dev/null >/dev/null 2>&1
  LAST_EXIT_CODE=$?
  unset GRANOLA_BIN
  export GRANOLA_BIN=/usr/bin/true   # restore for subsequent tests
  # The harness's STATUS_FILE was set in setup; brain-run uses GBRAIN_HOME-derived path
  local status_file="$GBRAIN_HOME/last-run.json"

  assert_file_exists "$status_file" "T14 — status file written even on failure"

  assert_exit_code 1 "T14 — brain-run exits 1 when phase fails"

  local s_status
  s_status=$(python3 -c "import json; print(json.load(open('$status_file'))['status'])" 2>/dev/null || echo "?")
  assert_not_equal "succeeded" "$s_status" "T14 — status is NOT 'succeeded'"

  local failed_count
  failed_count=$(python3 -c "import json; print(len(json.load(open('$status_file'))['failed_phases']))" 2>/dev/null || echo 0)
  assert_greater_than "$failed_count" 0 "T14 — failed_phases is non-empty"
}

test_status_file_includes_first_error() {
  # Use a mock granola that emits a recognizable error message THEN fails.
  # /usr/bin/false is silent so phase-2.log would be empty — no first_error
  # to capture. Real-world failures usually have a message.
  cat > "$TEST_TMP/granola-with-msg.sh" <<'SH'
#!/bin/sh
echo "GranolaError: connection refused (mock)" >&2
exit 7
SH
  chmod +x "$TEST_TMP/granola-with-msg.sh"
  export GRANOLA_BIN="$TEST_TMP/granola-with-msg.sh"
  ~/bin/brain-run --quick --run-id=feat-err </dev/null >/dev/null 2>&1
  unset GRANOLA_BIN
  export GRANOLA_BIN=/usr/bin/true

  local status_file="$GBRAIN_HOME/last-run.json"
  local err
  err=$(python3 -c "
import json
d = json.load(open('$status_file'))
print(d.get('first_error') or '<none>')
" 2>/dev/null)
  assert_not_equal "<none>" "$err" "T15 — first_error captured from phase log"
  # Bonus: the captured message should mention our marker
  if echo "$err" | grep -q "GranolaError"; then
    _pass "T15 — first_error contains the granola error message"
  else
    _fail "T15 — first_error doesn't reflect actual log content" "got: '$err'"
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# Item 3 — watermark guard
# ═════════════════════════════════════════════════════════════════════════════

test_watermark_guard_restores_on_failure() {
  _load_brain_run_lib
  export BRAIN_DIR
  echo "2026-05-01T00:00:00+0000" > "$BRAIN_DIR/.last-email-sync"
  local before
  before=$(<"$BRAIN_DIR/.last-email-sync")

  # Inner: simulate claude advancing the watermark THEN failing
  _inner_fail() {
    echo "2026-05-08T11:00:00+0000" > "$BRAIN_DIR/.last-email-sync"
    return 42
  }

  with_watermark_guard _inner_fail
  local rc=$?

  assert_equal "42" "$rc" "T16 — guard preserves inner exit code"

  local after
  after=$(<"$BRAIN_DIR/.last-email-sync")
  assert_equal "$before" "$after" "T16 — watermark restored to pre-call value on failure"
  assert_file_not_exists "$BRAIN_DIR/.last-email-sync.bak.$RUN_ID" \
    "T16 — backup file cleaned up after restore"
}

test_watermark_guard_keeps_on_success() {
  _load_brain_run_lib
  export BRAIN_DIR
  echo "2026-05-01T00:00:00+0000" > "$BRAIN_DIR/.last-email-sync"

  _inner_succeed() {
    echo "2026-05-08T11:00:00+0000" > "$BRAIN_DIR/.last-email-sync"
    return 0
  }

  with_watermark_guard _inner_succeed
  local rc=$?

  assert_equal "0" "$rc" "T17 — guard preserves success exit code"

  local after
  after=$(<"$BRAIN_DIR/.last-email-sync")
  assert_equal "2026-05-08T11:00:00+0000" "$after" \
    "T17 — watermark advanced (kept) on success"
  assert_file_not_exists "$BRAIN_DIR/.last-email-sync.bak.$RUN_ID" \
    "T17 — backup cleaned up on success"
}

test_watermark_guard_handles_no_prior_watermark() {
  _load_brain_run_lib
  export BRAIN_DIR
  rm -f "$BRAIN_DIR/.last-email-sync"

  # Inner writes a watermark, then fails. Since there was no prior, guard
  # should remove the stray watermark (defense in depth — prompt rule says
  # claude shouldn't write on failure, but trust-but-verify).
  _inner_writes_then_fails() {
    echo "2026-05-08T11:00:00+0000" > "$BRAIN_DIR/.last-email-sync"
    return 1
  }

  with_watermark_guard _inner_writes_then_fails

  assert_file_not_exists "$BRAIN_DIR/.last-email-sync" \
    "T18 — stray watermark removed when no prior value + failure"
}

# ─── Driver ──────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "  brain-run feature tests — items 3, 4, 5 (T10–T18)"
echo "═══════════════════════════════════════════════════════════════"

run_test "T10: record_cost_estimate logs kind=estimate"      test_record_cost_estimate_logs_kind_estimate
run_test "T11: record_cost_actual logs kind=actual"          test_record_cost_actual_logs_kind_actual
run_test "T12: estimate then actual both logged"             test_estimate_then_actual_both_logged
run_test "T12b: record_cost backward-compat alias"           test_record_cost_backward_compat_alias
run_test "T13: status file written on clean run"             test_status_file_succeeded_on_clean_run
run_test "T14: status file reflects phase failure"           test_status_file_failed_when_phase_fails
run_test "T15: status file captures first_error"             test_status_file_includes_first_error
run_test "T16: watermark guard restores on failure"          test_watermark_guard_restores_on_failure
run_test "T17: watermark guard keeps on success"             test_watermark_guard_keeps_on_success
run_test "T18: watermark guard handles no prior watermark"   test_watermark_guard_handles_no_prior_watermark

print_summary
