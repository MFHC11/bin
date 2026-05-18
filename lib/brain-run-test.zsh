#!/bin/zsh
# brain-run-test.zsh — assertion helpers + test isolation for brain-run.
#
# Usage:
#   source ~/bin/lib/brain-run-test.zsh        # use as a library
#   ~/bin/lib/brain-run-test.zsh --self-test   # verify the helpers themselves
#
# Each test gets its own tmpdir set as $BRAIN_DIR + $GBRAIN_HOME so tests
# never touch the real ~/brain or ~/.gbrain.

# ─── Test state ──────────────────────────────────────────────────────────────
typeset -g TESTS_RUN=0
typeset -g TESTS_PASSED=0
typeset -g TESTS_FAILED=0
typeset -ga TEST_FAILURES
TEST_FAILURES=()
typeset -g CURRENT_TEST=""

# Capture mode: when 1, _pass/_fail tally to _CAPTURED_* instead of the real
# counters. Used so the harness can self-test its own failure path.
typeset -g _CAPTURE_MODE=0
typeset -g _CAPTURED_PASS=0
typeset -g _CAPTURED_FAIL=0
typeset -g _CAPTURED_MSG=""

# Per-test state
typeset -g TEST_TMP=""
typeset -g LAST_EXIT_CODE=0
typeset -g LAST_RUN_ID=""

# Colors (skip if not a tty)
if [ -t 1 ]; then
  typeset -g _C_GREEN=$'\033[32m'
  typeset -g _C_RED=$'\033[31m'
  typeset -g _C_YELLOW=$'\033[33m'
  typeset -g _C_BOLD=$'\033[1m'
  typeset -g _C_DIM=$'\033[2m'
  typeset -g _C_RESET=$'\033[0m'
else
  typeset -g _C_GREEN="" _C_RED="" _C_YELLOW="" _C_BOLD="" _C_DIM="" _C_RESET=""
fi

# ─── Internal: pass/fail with capture-mode awareness ─────────────────────────
_pass() {
  local msg="$1"
  if [ "$_CAPTURE_MODE" = "1" ]; then
    _CAPTURED_PASS=$((_CAPTURED_PASS + 1))
    _CAPTURED_MSG="$msg"
    return 0
  fi
  TESTS_PASSED=$((TESTS_PASSED + 1))
  TESTS_RUN=$((TESTS_RUN + 1))
  printf "    %s✓%s %s\n" "$_C_GREEN" "$_C_RESET" "$msg"
}

_fail() {
  local msg="$1"
  local detail="${2:-}"
  if [ "$_CAPTURE_MODE" = "1" ]; then
    _CAPTURED_FAIL=$((_CAPTURED_FAIL + 1))
    _CAPTURED_MSG="$msg"
    return 0
  fi
  TESTS_FAILED=$((TESTS_FAILED + 1))
  TESTS_RUN=$((TESTS_RUN + 1))
  TEST_FAILURES+=("$CURRENT_TEST :: $msg")
  printf "    %s✗%s %s\n" "$_C_RED" "$_C_RESET" "$msg"
  if [ -n "$detail" ]; then
    printf "      %s%s%s\n" "$_C_YELLOW" "$detail" "$_C_RESET"
  fi
}

_capture_start() {
  _CAPTURE_MODE=1
  _CAPTURED_PASS=0
  _CAPTURED_FAIL=0
  _CAPTURED_MSG=""
}

_capture_end() {
  _CAPTURE_MODE=0
}

# ─── Test isolation ──────────────────────────────────────────────────────────
setup_test_env() {
  local name="$1"
  CURRENT_TEST="$name"
  TEST_TMP=$(mktemp -d -t brain-run-test.XXXXXX)

  export BRAIN_DIR="$TEST_TMP/brain"
  export GBRAIN_HOME="$TEST_TMP/gbrain"
  export BRAIN_RUN_SKIP_SUPERVISOR=1
  # Mock external binaries for mechanical-phase tests. /usr/bin/true accepts
  # any args and exits 0, so phases that call them succeed with empty output.
  export GRANOLA_BIN=/usr/bin/true
  export GBRAIN_BIN=/usr/bin/true

  mkdir -p "$BRAIN_DIR" "$GBRAIN_HOME" "$BRAIN_DIR/.tasks" "$BRAIN_DIR/inbox"

  # Set up brain as a git repo with a bare origin, so `git pull --rebase`
  # in Phase 1 has somewhere to fetch from.
  (
    cd "$TEST_TMP"
    git init --bare brain-origin >/dev/null 2>&1
    cd brain
    git init -b main >/dev/null 2>&1
    git config user.email "test@test.local"
    git config user.name "Test"
    git config commit.gpgsign false
    echo "# brain (test fixture)" > README.md
    git add README.md
    git commit -m "init" >/dev/null 2>&1
    git remote add origin "$TEST_TMP/brain-origin"
    git push -u origin main >/dev/null 2>&1
  )

  LAST_EXIT_CODE=0
  LAST_RUN_ID=""
}

teardown_test_env() {
  if [ -n "$TEST_TMP" ] && [ -d "$TEST_TMP" ]; then
    rm -rf "$TEST_TMP"
  fi
  TEST_TMP=""
  unset BRAIN_DIR GBRAIN_HOME BRAIN_RUN_SKIP_SUPERVISOR GRANOLA_BIN GBRAIN_BIN
  # Lib-mode + per-run state leak across tests if not cleared. T13 hit this
  # when T10–T12 (lib mode) left BRAIN_RUN_LIB_MODE=1 in env, causing T13's
  # subprocess invocation to skip main() entirely.
  unset BRAIN_RUN_LIB_MODE RUN_ID RUN_DIR RUN_LOG MANIFEST RUN_STARTED_AT
  unset COST_LOG STATUS_FILE
  # Don't unset CLAUDE_BIN here — tests that set it should manage it.
}

# Engineer a stash-pop conflict for Phase 1 (T5).
# Pushes a remote change to `shared.md`, then leaves a conflicting
# uncommitted change in the working tree. `git stash pop` after rebase
# will conflict.
cause_stash_conflict_scenario() {
  local helper="$TEST_TMP/conflict-helper"
  git clone "$TEST_TMP/brain-origin" "$helper" >/dev/null 2>&1
  (
    cd "$helper"
    git config user.email "helper@test.local"
    git config user.name "Helper"
    git config commit.gpgsign false
    echo "remote line A" > shared.md
    git add shared.md
    git commit -m "remote change to shared.md" >/dev/null 2>&1
    git push origin main >/dev/null 2>&1
  )
  rm -rf "$helper"

  # Conflicting LOCAL change (not committed — will be stashed)
  echo "local line B" > "$BRAIN_DIR/shared.md"
}

# ─── Brain-run invocation helper ─────────────────────────────────────────────
# Captures exit code; extracts --run-id from args for later assertions.
run_brain_run() {
  LAST_RUN_ID=""
  for arg in "$@"; do
    case "$arg" in
      --run-id=*) LAST_RUN_ID="${arg#--run-id=}" ;;
    esac
  done

  # Run with stdin closed so the Opus approval gate's `read -t` falls through.
  ~/bin/brain-run "$@" </dev/null
  LAST_EXIT_CODE=$?
}

# ─── Assertion helpers ───────────────────────────────────────────────────────
assert_equal() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-equal}"
  if [ "$expected" = "$actual" ]; then
    _pass "$msg"
  else
    _fail "$msg" "expected: '$expected', got: '$actual'"
  fi
}

assert_not_equal() {
  local a="$1"
  local b="$2"
  local msg="${3:-not equal}"
  if [ "$a" != "$b" ]; then
    _pass "$msg"
  else
    _fail "$msg" "both values: '$a'"
  fi
}

assert_greater_than() {
  local actual="$1"
  local floor="$2"
  local msg="${3:-greater than $floor}"
  # Integer-or-float aware compare via awk
  local cmp
  cmp=$(awk -v a="$actual" -v b="$floor" 'BEGIN { print (a+0 > b+0) ? 1 : 0 }')
  if [ "$cmp" = "1" ]; then
    _pass "$msg"
  else
    _fail "$msg" "expected > $floor, got: $actual"
  fi
}

# NOTE: in zsh, `path` (lowercase) is tied to $PATH — never use `local path=...`
# It silently corrupts the command lookup table for the function's duration.
assert_file_exists() {
  local file="$1"
  local msg="${2:-file exists}"
  if [ -e "$file" ]; then
    _pass "$msg"
  else
    _fail "$msg" "missing: $file"
  fi
}

assert_file_not_exists() {
  local file="$1"
  local msg="${2:-file absent}"
  if [ ! -e "$file" ]; then
    _pass "$msg"
  else
    _fail "$msg" "unexpectedly exists: $file"
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local msg="${3:-file contains pattern}"
  if [ -f "$file" ] && grep -qF -- "$pattern" "$file"; then
    _pass "$msg"
  else
    _fail "$msg" "file: $file, pattern: '$pattern'"
  fi
}

assert_exit_code() {
  local expected="$1"
  local msg="${2:-exit code $expected}"
  if [ "$LAST_EXIT_CODE" = "$expected" ]; then
    _pass "$msg"
  else
    _fail "$msg" "expected: $expected, got: $LAST_EXIT_CODE"
  fi
}

# brain-run-specific assertions ------------------------------------------------

# Reads $GBRAIN_HOME/runs/$run_id/phase-$phase.state and compares.
# expected="" matches a missing file (phase never started).
assert_state() {
  local run_id="$1"
  local phase="$2"
  local expected="$3"
  local msg="${4:-phase-$phase state == '$expected'}"
  local file="$GBRAIN_HOME/runs/$run_id/phase-$phase.state"
  local actual=""
  [ -f "$file" ] && actual=$(<"$file")
  if [ "$expected" = "$actual" ]; then
    _pass "$msg"
  else
    _fail "$msg" "expected: '$expected', got: '$actual', file: $file"
  fi
}

assert_log_contains() {
  local run_id="$1"
  local pattern="$2"
  local msg="${3:-run log contains '$pattern'}"
  local file="$GBRAIN_HOME/runs/$run_id/run.log"
  if [ -f "$file" ] && grep -qF -- "$pattern" "$file"; then
    _pass "$msg"
  else
    _fail "$msg" "log: $file"
  fi
}

assert_total_cost() {
  local run_id="$1"
  local expected="$2"
  local msg="${3:-total cost == \$$expected}"
  local manifest="$GBRAIN_HOME/runs/$run_id/manifest.json"
  local actual="???"
  if [ -f "$manifest" ]; then
    actual=$(python3 -c "
import json, sys
try:
    d = json.load(open('$manifest'))
    print(f\"{d.get('totals',{}).get('cost_usd', 0):.2f}\")
except Exception as e:
    print('???')
" 2>/dev/null)
  fi
  if [ "$expected" = "$actual" ]; then
    _pass "$msg"
  else
    _fail "$msg" "expected: '$expected', got: '$actual'"
  fi
}

# ─── Test runner ─────────────────────────────────────────────────────────────
run_test() {
  local name="$1"
  local fn="$2"
  printf "\n  %s%s%s\n" "$_C_BOLD" "$name" "$_C_RESET"
  setup_test_env "$name"
  $fn
  teardown_test_env
}

print_summary() {
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  printf "  %d run, %s%d passed%s, " \
    "$TESTS_RUN" "$_C_GREEN" "$TESTS_PASSED" "$_C_RESET"
  if [ "$TESTS_FAILED" -gt 0 ]; then
    printf "%s%d failed%s\n" "$_C_RED" "$TESTS_FAILED" "$_C_RESET"
    echo ""
    echo "Failures:"
    for f in "${TEST_FAILURES[@]}"; do
      printf "  %s✗%s %s\n" "$_C_RED" "$_C_RESET" "$f"
    done
    echo "═══════════════════════════════════════════════════════════════"
    return 1
  else
    printf "%s0 failed%s\n" "$_C_GREEN" "$_C_RESET"
    echo "═══════════════════════════════════════════════════════════════"
    return 0
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# SELF-TESTS — verify the assertion helpers themselves work.
# Each negative test uses _capture_start / _capture_end so the deliberate
# failure tallies into _CAPTURED_FAIL rather than polluting the real counter.
# ═════════════════════════════════════════════════════════════════════════════

selftest_pass_fail_counters() {
  local before_pass=$TESTS_PASSED
  local before_fail=$TESTS_FAILED
  _pass "(test scaffold) pass increments PASSED"
  if [ "$TESTS_PASSED" = "$((before_pass + 1))" ]; then
    : # already counted by _pass above
  else
    _fail "PASSED counter did not increment"
  fi

  _capture_start
  _fail "this should be captured, not real"
  _capture_end
  if [ "$_CAPTURED_FAIL" = "1" ]; then
    _pass "_capture_start diverts _fail to capture buffer"
  else
    _fail "_capture_start did NOT divert _fail (CAPTURED_FAIL=$_CAPTURED_FAIL)"
  fi
  if [ "$TESTS_FAILED" = "$before_fail" ]; then
    _pass "real TESTS_FAILED untouched during capture"
  else
    _fail "real TESTS_FAILED was incremented during capture"
  fi
}

selftest_assert_equal() {
  assert_equal "foo" "foo" "assert_equal positive: 'foo' == 'foo'"

  _capture_start
  assert_equal "foo" "bar" "neg"
  _capture_end
  if [ "$_CAPTURED_FAIL" = "1" ]; then
    _pass "assert_equal correctly fails on mismatch"
  else
    _fail "assert_equal did NOT fail on mismatch"
  fi

  _capture_start
  assert_equal "" "" "neg"
  _capture_end
  if [ "$_CAPTURED_PASS" = "1" ]; then
    _pass "assert_equal handles empty strings"
  else
    _fail "assert_equal failed on empty string equality"
  fi
}

selftest_assert_not_equal() {
  assert_not_equal "foo" "bar" "assert_not_equal positive: 'foo' != 'bar'"

  _capture_start
  assert_not_equal "foo" "foo" "neg"
  _capture_end
  if [ "$_CAPTURED_FAIL" = "1" ]; then
    _pass "assert_not_equal correctly fails when equal"
  else
    _fail "assert_not_equal did NOT fail when equal"
  fi
}

selftest_assert_greater_than() {
  assert_greater_than 5 3 "assert_greater_than positive: 5 > 3"
  assert_greater_than 0.05 0 "assert_greater_than handles floats"

  _capture_start
  assert_greater_than 1 5 "neg"
  _capture_end
  if [ "$_CAPTURED_FAIL" = "1" ]; then
    _pass "assert_greater_than correctly fails when not greater"
  else
    _fail "assert_greater_than did NOT fail when not greater"
  fi

  _capture_start
  assert_greater_than 5 5 "neg"
  _capture_end
  if [ "$_CAPTURED_FAIL" = "1" ]; then
    _pass "assert_greater_than is strict (5 > 5 is false)"
  else
    _fail "assert_greater_than wrongly accepts equal values"
  fi
}

selftest_assert_file_exists() {
  local tmp="$TEST_TMP/some-file.txt"
  echo "hello" > "$tmp"
  assert_file_exists "$tmp" "assert_file_exists positive"

  _capture_start
  assert_file_exists "$TEST_TMP/missing.txt" "neg"
  _capture_end
  if [ "$_CAPTURED_FAIL" = "1" ]; then
    _pass "assert_file_exists correctly fails on missing"
  else
    _fail "assert_file_exists did NOT fail on missing file"
  fi

  assert_file_not_exists "$TEST_TMP/missing.txt" "assert_file_not_exists positive"
}

selftest_assert_file_contains() {
  local tmp="$TEST_TMP/some.log"
  echo "phase 1 succeeded" > "$tmp"
  echo "phase 2 stashed 3 file(s)" >> "$tmp"
  assert_file_contains "$tmp" "stashed" "assert_file_contains positive"

  _capture_start
  assert_file_contains "$tmp" "absent-pattern-xyz" "neg"
  _capture_end
  if [ "$_CAPTURED_FAIL" = "1" ]; then
    _pass "assert_file_contains correctly fails on missing pattern"
  else
    _fail "assert_file_contains did NOT fail on missing pattern"
  fi
}

selftest_assert_state_helper() {
  # Build a fake run dir
  local run_id="selftest-state"
  mkdir -p "$GBRAIN_HOME/runs/$run_id"
  echo "succeeded" > "$GBRAIN_HOME/runs/$run_id/phase-0.state"

  assert_state "$run_id" 0 "succeeded" "assert_state reads succeeded"
  assert_state "$run_id" 7 "" "assert_state matches missing file with empty string"

  _capture_start
  assert_state "$run_id" 0 "failed" "neg"
  _capture_end
  if [ "$_CAPTURED_FAIL" = "1" ]; then
    _pass "assert_state correctly fails on state mismatch"
  else
    _fail "assert_state did NOT fail on state mismatch"
  fi
}

selftest_assert_log_contains() {
  local run_id="selftest-log"
  mkdir -p "$GBRAIN_HOME/runs/$run_id"
  printf "git: stashed 1 file\nrebase: clean\n" > "$GBRAIN_HOME/runs/$run_id/run.log"

  assert_log_contains "$run_id" "stashed" "assert_log_contains positive"

  _capture_start
  assert_log_contains "$run_id" "absent-xyz" "neg"
  _capture_end
  if [ "$_CAPTURED_FAIL" = "1" ]; then
    _pass "assert_log_contains correctly fails on missing pattern"
  else
    _fail "assert_log_contains did NOT fail"
  fi
}

selftest_assert_total_cost() {
  local run_id="selftest-cost"
  mkdir -p "$GBRAIN_HOME/runs/$run_id"
  cat > "$GBRAIN_HOME/runs/$run_id/manifest.json" <<EOF
{"run_id":"$run_id","totals":{"cost_usd":0}}
EOF
  assert_total_cost "$run_id" "0.00" "assert_total_cost zero"

  cat > "$GBRAIN_HOME/runs/$run_id/manifest.json" <<EOF
{"run_id":"$run_id","totals":{"cost_usd":3.456}}
EOF
  assert_total_cost "$run_id" "3.46" "assert_total_cost rounds 3.456 -> 3.46"
}

selftest_setup_creates_clean_brain() {
  assert_file_exists "$BRAIN_DIR/.git" "setup_test_env created git repo"
  assert_file_exists "$BRAIN_DIR/.git/refs/remotes/origin/main" "setup configured origin remote"
  assert_file_exists "$BRAIN_DIR/inbox" "setup created inbox/"
  assert_file_exists "$BRAIN_DIR/.tasks" "setup created .tasks/"

  # Working tree is clean
  local porcelain_lines
  porcelain_lines=$(cd "$BRAIN_DIR" && git status --porcelain | wc -l | tr -d ' ')
  assert_equal "0" "$porcelain_lines" "fresh fixture has clean working tree"
}

selftest_conflict_scenario_helper() {
  cause_stash_conflict_scenario
  assert_file_exists "$BRAIN_DIR/shared.md" "local conflicting file present"

  # The file should be uncommitted
  local porcelain
  porcelain=$(cd "$BRAIN_DIR" && git status --porcelain shared.md)
  if echo "$porcelain" | grep -qE '^\?\?'; then
    _pass "local shared.md is untracked (will be stashed via -u)"
  else
    _fail "local shared.md status unexpected: '$porcelain'"
  fi

  # Origin should have a different shared.md committed
  local origin_has
  origin_has=$(cd "$TEST_TMP/brain-origin" && git log --all --pretty=format: --name-only | grep -c '^shared.md$' || true)
  assert_greater_than "$origin_has" 0 "origin has a commit touching shared.md"
}

# ─── Self-test driver ────────────────────────────────────────────────────────
run_self_tests() {
  echo "═══════════════════════════════════════════════════════════════"
  echo "  brain-run-test.zsh — self-tests"
  echo "═══════════════════════════════════════════════════════════════"

  run_test "selftest_pass_fail_counters"          selftest_pass_fail_counters
  run_test "selftest_assert_equal"                selftest_assert_equal
  run_test "selftest_assert_not_equal"            selftest_assert_not_equal
  run_test "selftest_assert_greater_than"         selftest_assert_greater_than
  run_test "selftest_assert_file_exists"          selftest_assert_file_exists
  run_test "selftest_assert_file_contains"        selftest_assert_file_contains
  run_test "selftest_assert_state_helper"         selftest_assert_state_helper
  run_test "selftest_assert_log_contains"         selftest_assert_log_contains
  run_test "selftest_assert_total_cost"           selftest_assert_total_cost
  run_test "selftest_setup_creates_clean_brain"   selftest_setup_creates_clean_brain
  run_test "selftest_conflict_scenario_helper"    selftest_conflict_scenario_helper

  print_summary
}

# Run self-tests when invoked directly with --self-test
if [ "${1:-}" = "--self-test" ]; then
  run_self_tests
  exit $?
fi
