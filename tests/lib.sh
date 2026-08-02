#!/bin/bash
# Tiny assertion harness for hats' own tests. No dependencies beyond bash + jq,
# because a plugin that needs a test framework installed to check itself will
# not be checked.
#
# Every assertion prints one line. A failing run exits non-zero.

PASS=0
FAIL=0
FAILURES=()
GAPS=()
GAP_ID=""

HATS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export HATS_ROOT

# A throwaway project that looks like a real hats project. Each test file gets
# its own, so a test cannot leave state for the next one.
make_project() {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/.hats"/{manager,designer,cto,qa,developer,shared/{specs,designs,threads}}
  mkdir -p "$dir/src"
  echo "$dir"
}

# Feed one tool call to a guard script exactly as Claude Code would.
# Usage: run_guard <script> <role> <json tool_input> [tool_name]
# Sets: GUARD_CODE, GUARD_ERR
# `sid` is what makes a session a session. Tests that care about two sessions
# set SESSION themselves; everything else shares one, exactly like today.
SESSION="${SESSION:-test-session-A}"

run_guard() {
  local script="$1" role="$2" tool_input="$3" tool="${4:-Write}"
  [ "$role" = "-" ] || echo "$role" > "$PROJECT/.hats/role"
  local out
  out=$(cd "$PROJECT" && echo "{\"session_id\":\"$SESSION\",\"tool_name\":\"$tool\",\"tool_input\":$tool_input}" \
        | bash "$HATS_ROOT/scripts/$script" 2>&1)
  GUARD_CODE=$?
  GUARD_ERR="$out"
}

# Switch a role the way a skill does: a Write to .hats/role that passes through
# the guard, so the guard gets its chance to record and to refuse.
switch_role() {
  local from="$1" to="$2"
  echo "$from" > "$PROJECT/.hats/role"
  local out
  out=$(cd "$PROJECT" && echo "{\"session_id\":\"$SESSION\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$PROJECT/.hats/role\",\"content\":\"$to\"}}" \
        | bash "$HATS_ROOT/scripts/guard.sh" 2>&1)
  SWITCH_CODE=$?
  SWITCH_ERR="$out"
  # The guard only decides; Claude Code performs the write. Mirror that here,
  # or the test would be checking a world the guard never allows to exist.
  [ "$SWITCH_CODE" -eq 0 ] && echo "$to" > "$PROJECT/.hats/role"
  return 0
}

# A KNOWN GAP is a promise the code does not keep yet, stated as a row instead
# of quietly dropped. It counts as neither pass nor failure — but it flips to a
# FAILURE the moment it starts passing, because a gap that closed itself and
# stayed on the list is how a list stops meaning anything.
gap() { GAP_ID="$1"; shift; "$@"; GAP_ID=""; }

_ok() {
  if [ -n "$GAP_ID" ]; then
    FAIL=$((FAIL+1)); FAILURES+=("gap ${GAP_ID} is CLOSED -- delete it from tests/KNOWN-GAPS.md")
    printf '  FAIL gap %s is CLOSED -- delete it from tests/KNOWN-GAPS.md\n' "$GAP_ID"
  else
    PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  fi
}
_fail() {
  if [ -n "$GAP_ID" ]; then
    GAPS+=("${GAP_ID}: $1"); printf '  gap  %-8s %s\n' "$GAP_ID" "$1"
  else
    FAIL=$((FAIL+1)); FAILURES+=("$1 -- $2"); printf '  FAIL %s\n       %s\n' "$1" "$2"
  fi
}

# The role may write this path.
assert_allow() {
  local desc="$1" script="$2" role="$3" path="$4"
  run_guard "$script" "$role" "{\"file_path\":\"$path\"}"
  if [ "$GUARD_CODE" -eq 0 ]; then _ok "$desc"
  else _fail "$desc" "blocked with: $GUARD_ERR"; fi
}

# The role may NOT write this path, and the refusal says why.
# The `why` argument is not decoration: a refusal nobody can act on is the jam
# this project has paid for once already.
assert_block() {
  local desc="$1" script="$2" role="$3" path="$4" why="$5"
  run_guard "$script" "$role" "{\"file_path\":\"$path\"}"
  if [ "$GUARD_CODE" -ne 2 ]; then
    _fail "$desc" "expected exit 2, got $GUARD_CODE ($GUARD_ERR)"
  elif ! echo "$GUARD_ERR" | grep -q "$why"; then
    _fail "$desc" "blocked, but the reason does not say \"${why}\": ${GUARD_ERR}"
  else _ok "$desc"; fi
}

# Same, for the read guard, which takes Read/Glob/Grep shapes.
assert_read_allow() {
  local desc="$1" role="$2" json="$3" tool="$4"
  run_guard read-guard.sh "$role" "$json" "$tool"
  if [ "$GUARD_CODE" -eq 0 ]; then _ok "$desc"
  else _fail "$desc" "blocked with: $GUARD_ERR"; fi
}

assert_read_block() {
  local desc="$1" role="$2" json="$3" tool="$4" why="$5"
  run_guard read-guard.sh "$role" "$json" "$tool"
  if [ "$GUARD_CODE" -ne 2 ]; then
    _fail "$desc" "expected exit 2, got $GUARD_CODE ($GUARD_ERR)"
  elif ! echo "$GUARD_ERR" | grep -q "$why"; then
    _fail "$desc" "blocked, but the reason does not say \"${why}\": ${GUARD_ERR}"
  else _ok "$desc"; fi
}

assert_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then _ok "$desc"
  else _fail "$desc" "expected \"${expected}\", got \"${actual}\""; fi
}

assert_true() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then _ok "$desc"
  else _fail "$desc" "command failed: $*"; fi
}

summary() {
  echo
  local g=""
  [ "${#GAPS[@]}" -gt 0 ] && g=", ${#GAPS[@]} known gap(s)"
  if [ "$FAIL" -eq 0 ]; then
    echo "  $PASS passed, 0 failed${g}"
    for x in ${GAPS[@]+"${GAPS[@]}"}; do echo "    ~ $x"; done
    return 0
  fi
  echo "  $PASS passed, $FAIL FAILED${g}:"
  for f in "${FAILURES[@]}"; do echo "    - $f"; done
  return 1
}
