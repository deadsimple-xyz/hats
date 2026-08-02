#!/bin/bash
# scripts/bash-audit.sh — G3, step one. Watch the shell; refuse nothing.
#
# The rows that matter most here are the ones proving it does NOT block. An
# audit that can refuse is a fence, and a fence built on guesses about what a
# command touches is the jam this project has already paid for once.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PROJECT=$(make_project)
trap 'rm -rf "$PROJECT"' EXIT
LOG="$PROJECT/.hats/bash-audit.jsonl"

echo "bash-audit.sh — the shell is watched, not fenced"

audit() {           # audit <role> <command>
  echo "$1" > "$PROJECT/.hats/role"
  local out
  out=$(cd "$PROJECT" && printf '%s' "{\"session_id\":\"t\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":$(printf '%s' "$2" | jq -Rs .)}}" \
        | bash "$HATS_ROOT/scripts/bash-audit.sh" 2>&1)
  AUDIT_CODE=$?
  AUDIT_ERR="$out"
}

lines() { [ -f "$LOG" ] && wc -l < "$LOG" | tr -d ' ' || echo 0; }

# ── IT NEVER BLOCKS. This is the whole design, so it is the first block. ─────
for c in "cat src/counter.ts" "echo x > src/counter.ts" "rm -rf .hats/developer" \
         "npm test" "bash .hats/qa/run-tests.sh" "git commit -am wip"; do
  audit qa "$c"
  assert_eq "never refuses: $(echo "$c" | cut -c1-28)" "$AUDIT_CODE" "0"
done
assert_eq "and says nothing to the role" "$AUDIT_ERR" ""

# ── it records the three shapes that were demonstrated live ─────────────────
: > "$LOG"
audit qa "cat src/counter.ts"
assert_eq "a QA reading source is recorded" "$(lines)" "1"
assert_true "with the reason"  grep -q '"why":"command naming src/"' "$LOG"
assert_true "and the command"  grep -q 'cat src/counter.ts' "$LOG"
assert_true "and the role"     grep -q '"role":"qa"' "$LOG"

: > "$LOG"
audit qa "echo x > src/counter.ts"
assert_true "a write-shaped command is distinguished from a read" \
  grep -q '"why":"write-shaped command naming src/"' "$LOG"

: > "$LOG"
audit developer "echo done > .hats/qa/steps/login.ts"
assert_true "the developer reaching into the qa dir is recorded" \
  grep -q '"why":"write-shaped command naming .hats/qa/"' "$LOG"

# ── ordinary work is not recorded, or the log is noise ──────────────────────
: > "$LOG"
for c in "npm test" "git status" "bash .hats/qa/run-tests.sh" "ls -la"; do
  audit qa "$c"
done
assert_eq "the QA's own tools leave no line" "$(lines)" "0"

: > "$LOG"
audit developer "npx vitest run src/counter.test.ts"
assert_eq "the developer reading its OWN source leaves no line" "$(lines)" "0"

# ── it is not behind the debug flag ─────────────────────────────────────────
# The day you want this log is the day nobody thought to turn logging on.
assert_true "no debug flag was needed for any of the above" test ! -f "$PROJECT/.hats/debug"

# ── one line per command, not one per matching directory ────────────────────
: > "$LOG"
audit qa "cp src/a.ts lib/b.ts"
assert_eq "a command touching two watched dirs is one line" "$(lines)" "1"

# ── an unknown role is not audited, matching the guards ─────────────────────
: > "$LOG"
audit solo "cat src/counter.ts"
assert_eq "an unknown role is left alone here too" "$(lines)" "0"

summary
