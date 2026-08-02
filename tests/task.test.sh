#!/bin/bash
# Tasks as folders in git, and the three gates around their status.
#
# The gates are checked TWICE on purpose: once through `task.sh`, which is the
# path a role takes when it uses the helper, and once through `guard.sh`, which
# is the path a role takes when it edits `task.md` by hand. A gate that only
# the helper enforces is a convention wearing a mechanism's coat.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PROJECT=$(make_project)
trap 'rm -rf "$PROJECT"' EXIT
T="bash $HATS_ROOT/scripts/task.sh"
G=guard.sh

echo "tasks — folders in git, and the three gates"

run_t() { ( cd "$PROJECT" && $T "$@" 2>&1 ); }

# ── a task is a folder with a header a human can read ────────────────────────
DIR=$(run_t new "Runner is flaky on login" 1 developer "@auth")
assert_eq "the first task is numbered 0001" "$(basename "$DIR" | cut -c1-4)" "0001"
assert_true "it has a task.md" test -f "$PROJECT/$DIR/task.md"
assert_true "the header carries status"   grep -q '^status: open' "$PROJECT/$DIR/task.md"
assert_true "the header carries priority" grep -q '^priority: 1' "$PROJECT/$DIR/task.md"
assert_true "the header carries owner"    grep -q '^owner: developer' "$PROJECT/$DIR/task.md"
assert_true "the header links a spec"     grep -q '^spec: @auth' "$PROJECT/$DIR/task.md"
assert_true "the title survives as a title" grep -q '^# Runner is flaky on login' "$PROJECT/$DIR/task.md"
assert_true "an index is generated"       test -f "$PROJECT/.hats/tasks/INDEX.md"
assert_true "the index lists it"          grep -q "Runner is flaky on login" "$PROJECT/.hats/tasks/INDEX.md"

# ── gate 1: a task cannot close without ever being in work ───────────────────
out=$(run_t status "$DIR" done) && code=0 || code=$?
assert_eq "open -> done is refused"  "$code" "1"
assert_true "and the refusal says the whole path out" \
  grep -q "in_progress" <<<"$out"
assert_true "the status did not move"  grep -q '^status: open' "$PROJECT/$DIR/task.md"

# ── gate 2: work starts with a sentence about what the job is ────────────────
out=$(run_t status "$DIR" in_progress) && code=0 || code=$?
assert_eq "in_progress without understanding.md is refused" "$code" "1"
assert_true "and it NAMES the file" grep -q "understanding.md" <<<"$out"
: > "$PROJECT/$DIR/understanding.md"
out=$(run_t status "$DIR" in_progress) && code=0 || code=$?
assert_eq "an EMPTY understanding.md is still refused" "$code" "1"
echo "The login test races the fixture, not the code." > "$PROJECT/$DIR/understanding.md"
run_t status "$DIR" in_progress >/dev/null
assert_true "with a real one, work starts" grep -q '^status: in_progress' "$PROJECT/$DIR/task.md"

# ── gate 3: closing owes what was checked and what it concluded ──────────────
out=$(run_t status "$DIR" done) && code=0 || code=$?
assert_eq "done without resolution.md is refused" "$code" "1"
assert_true "and it NAMES the file" grep -q "resolution.md" <<<"$out"
echo "Fixture now seeded before the suite. 40 runs, 0 flakes." > "$PROJECT/$DIR/resolution.md"
run_t status "$DIR" done >/dev/null
assert_true "with a real one, it closes" grep -q '^status: done' "$PROJECT/$DIR/task.md"
assert_true "the index followed" grep -q "done" "$PROJECT/.hats/tasks/INDEX.md"

# ── the queue: priority first, and it ignores what is finished ───────────────
run_t new "Small copy fix" 3 developer >/dev/null
HOT=$(run_t new "Payments are down" 1 developer)
assert_eq "next takes the hottest open task" "$(cd "$PROJECT" && $T next)" "$HOT"

# ── THE SAME GATES, BY HAND — this is the half that matters ──────────────────
#
# A role does not have to use task.sh. It can Edit task.md. If the gates live
# only in the helper, every one of them is optional in practice.
BY_HAND=$(run_t new "Edited by hand" 2 qa)
TASKMD="$PROJECT/$BY_HAND/task.md"

run_guard $G developer "{\"file_path\":\"$TASKMD\",\"content\":\"status: done\"}"
assert_eq "by hand: open -> done is refused too" "$GUARD_CODE" "2"
assert_true "and the by-hand refusal shows the way out" \
  grep -q "in_progress" <<<"$GUARD_ERR"

run_guard $G developer "{\"file_path\":\"$TASKMD\",\"content\":\"status: in_progress\"}"
assert_eq "by hand: in_progress without understanding.md is refused" "$GUARD_CODE" "2"
assert_true "and it names the file"  grep -q "understanding.md" <<<"$GUARD_ERR"

echo "Copy is wrong on the empty state." > "$PROJECT/$BY_HAND/understanding.md"
run_guard $G developer "{\"file_path\":\"$TASKMD\",\"content\":\"status: in_progress\"}"
assert_eq "with the file, by hand works" "$GUARD_CODE" "0"

# Edit carries a fragment, not the whole file — the gate must read that too.
run_guard $G developer "{\"file_path\":\"$TASKMD\",\"new_string\":\"status: done\"}" Edit
assert_eq "Edit is gated exactly like Write" "$GUARD_CODE" "2"
assert_true "and names resolution.md" grep -q "resolution.md" <<<"$GUARD_ERR"

# ── writes that touch no status are not the gate's business ──────────────────
run_guard $G developer "{\"file_path\":\"$TASKMD\",\"content\":\"# Edited by hand\\n\\nMore detail.\"}"
assert_eq "editing the body of a task is free" "$GUARD_CODE" "0"
assert_allow "and so is writing understanding.md" $G developer "$PROJECT/$BY_HAND/understanding.md"
assert_allow "and resolution.md"                  $G developer "$PROJECT/$BY_HAND/resolution.md"
assert_allow "any role may work the task board"   $G qa        "$PROJECT/.hats/tasks/INDEX.md"

summary
