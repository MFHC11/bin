#!/bin/zsh
# brain-run-tests-skeleton.zsh — runs T1, T3, T4, T5 from the spec
# against the skeleton implementation (Phases 0, 1, 9 + stubs for 2, 5, 7, 8).
#
# Usage:  ~/bin/lib/brain-run-tests-skeleton.zsh

set -uo pipefail

source "$HOME/bin/lib/brain-run-test.zsh"

# ─── T1: --quick runs Phase 0,1,2,5,7,8,9 only ───────────────────────────────
test_quick_skips_llm_phases() {
  run_brain_run --quick --run-id=test-quick-1

  assert_exit_code 0 "T1 — exit 0 on clean --quick"

  assert_state test-quick-1 0 "succeeded" "T1 — phase 0 (preflight) succeeded"
  assert_state test-quick-1 1 "succeeded" "T1 — phase 1 (git safety) succeeded"
  assert_state test-quick-1 2 "succeeded" "T1 — phase 2 (granola) succeeded"
  assert_state test-quick-1 3 ""          "T1 — phase 3 (cal-mail) NOT run under --quick"
  assert_state test-quick-1 4 ""          "T1 — phase 4 (enrich) NOT run under --quick"
  assert_state test-quick-1 5 "succeeded" "T1 — phase 5 (gbrain dream) succeeded"
  assert_state test-quick-1 6 ""          "T1 — phase 6 (opus) NOT run under --quick"
  assert_state test-quick-1 7 "succeeded" "T1 — phase 7 (backup) succeeded"
  assert_state test-quick-1 8 "succeeded" "T1 — phase 8 (verify) succeeded"
  assert_state test-quick-1 9 "succeeded" "T1 — phase 9 (summary) succeeded"

  assert_total_cost test-quick-1 "0.00" "T1 — total cost is \$0.00 (no LLM phases)"
}

# ─── T3: missing claude → exit 2 ─────────────────────────────────────────────
test_missing_claude_exits_2() {
  CLAUDE_BIN=/nonexistent/claude run_brain_run --quick --run-id=test-missing-claude
  unset CLAUDE_BIN

  assert_exit_code 2 "T3 — exit 2 on missing claude CLI"
  assert_log_contains test-missing-claude "claude CLI not found" \
    "T3 — log contains 'claude CLI not found'"
  assert_state test-missing-claude 0 "failed" "T3 — phase 0 marked failed"
  assert_state test-missing-claude 1 "" "T3 — phase 1 never started"
}

# ─── T4: dirty tree gets stashed and restored ────────────────────────────────
test_dirty_tree_is_stashed_and_popped() {
  echo "dirty content unique to T4" > "$BRAIN_DIR/test-dirty.md"

  run_brain_run --quick --run-id=test-dirty-1

  assert_exit_code 0 "T4 — exit 0 on clean dirty-tree run"
  assert_state test-dirty-1 1 "succeeded" "T4 — phase 1 succeeded"
  assert_file_exists "$BRAIN_DIR/test-dirty.md" "T4 — dirty file restored after stash pop"
  assert_log_contains test-dirty-1 "stashed" "T4 — log records stash operation"
  assert_log_contains test-dirty-1 "stash popped clean" "T4 — log records successful pop"

  # Content preserved
  local content
  content=$(<"$BRAIN_DIR/test-dirty.md")
  assert_equal "dirty content unique to T4" "$content" "T4 — file content preserved"
}

# ─── T5: stash pop conflict → exit 3 ─────────────────────────────────────────
test_stash_conflict_exits_3() {
  cause_stash_conflict_scenario

  run_brain_run --quick --run-id=test-conflict-1

  assert_exit_code 3 "T5 — exit 3 on stash pop conflict"
  assert_state test-conflict-1 1 "failed" "T5 — phase 1 marked failed"
  assert_log_contains test-conflict-1 "stash pop produced conflicts" \
    "T5 — log records conflict"
}

# ─── Driver ──────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "  brain-run skeleton tests — T1, T3, T4, T5"
echo "═══════════════════════════════════════════════════════════════"

run_test "T1: --quick skips LLM phases"          test_quick_skips_llm_phases
run_test "T3: missing claude → exit 2"           test_missing_claude_exits_2
run_test "T4: dirty tree stashed & restored"     test_dirty_tree_is_stashed_and_popped
run_test "T5: stash pop conflict → exit 3"       test_stash_conflict_exits_3

print_summary
