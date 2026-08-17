#!/bin/bash
# scripts/guard.sh — one row per rule it enforces.
#
# This script decides EVERY write in EVERY project using hats, and until now
# nothing checked it. Five consecutive releases (4.3.1..4.3.5) fixed what the
# previous one broke; that is what an unchecked mechanism looks like from the
# outside.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PROJECT=$(make_project)
trap 'rm -rf "$PROJECT"' EXIT
G=guard.sh

echo "guard.sh — the fence around writes"

# ── no role set: the guard stands aside ───────────────────────────────────────
rm -f "$PROJECT/.hats/role"
out=$(cd "$PROJECT" && echo '{"tool_name":"Write","tool_input":{"file_path":"src/x.ts"}}' \
      | bash "$HATS_ROOT/scripts/$G" 2>&1); code=$?
assert_eq "no .hats/role -> permissive (plain Claude keeps working)" "$code" "0"

# ── the role file itself is always writable, or roles could never switch ──────
assert_allow "any role may write .hats/role"            $G qa        "$PROJECT/.hats/role"
assert_allow "plan-mode files are open to every role"   $G qa        "$PROJECT/.claude/plans/p.md"

# ── .feature belongs to the manager ───────────────────────────────────────────
assert_allow "manager writes a spec"                    $G manager   "$PROJECT/.hats/shared/specs/auth.feature"
assert_block "qa may not write a .feature"              $G qa        "$PROJECT/.hats/shared/specs/auth.feature" "owned by the manager"
assert_block "developer may not write a .feature"       $G developer "$PROJECT/.hats/shared/specs/auth.feature" "owned by the manager"

# ── only the developer touches the project itself ─────────────────────────────
assert_allow "developer writes source"                  $G developer "$PROJECT/src/index.ts"
assert_block "manager cannot write source"              $G manager   "$PROJECT/src/index.ts" "can only write inside .hats/"
assert_block "qa cannot write source"                   $G qa        "$PROJECT/src/index.ts" "can only write inside .hats/"
assert_block "cto cannot write source"                  $G cto       "$PROJECT/src/index.ts" "can only write inside .hats/"

# ── threads are the one open channel, and only for .md ────────────────────────
assert_allow "any role appends to a thread"             $G developer "$PROJECT/.hats/shared/threads/auth.md"
assert_allow "threads may nest"                         $G qa        "$PROJECT/.hats/shared/threads/auth/login.md"
assert_block "threads take .md only"                    $G qa        "$PROJECT/.hats/shared/threads/notes.txt" "must end .md"

# ── each role owns its own drawer and no one else's ───────────────────────────
assert_allow "qa writes its own workspace"              $G qa        "$PROJECT/.hats/qa/steps/login.ts"
assert_block "qa cannot reach into cto's"               $G qa        "$PROJECT/.hats/cto/notes.md" "cannot write to .hats/cto/"
assert_block "developer cannot reach into qa's"         $G developer "$PROJECT/.hats/qa/steps/login.ts" "cannot write to .hats/qa/"
assert_block "manager cannot reach into developer's"    $G manager   "$PROJECT/.hats/developer/notes.md" "cannot write to .hats/developer/"

# ── shared/ is a set of named mailboxes, not a free-for-all ───────────────────
assert_allow "manager -> manager2team.md"               $G manager   "$PROJECT/.hats/shared/manager2team.md"
assert_block "manager cannot write stack.md"            $G manager   "$PROJECT/.hats/shared/stack.md" "Manager can only write"
assert_block "manager cannot write into designs/"       $G manager   "$PROJECT/.hats/shared/designs/home.md" "owned by Designer"

assert_allow "designer -> designs/"                     $G designer  "$PROJECT/.hats/shared/designs/home.md"
assert_allow "designer -> designer2team.md"             $G designer  "$PROJECT/.hats/shared/designer2team.md"
assert_block "designer cannot write into specs/"        $G designer  "$PROJECT/.hats/shared/specs/auth.md" "owned by Manager"

assert_allow "cto -> stack.md"                          $G cto       "$PROJECT/.hats/shared/stack.md"
assert_allow "cto -> api.md"                            $G cto       "$PROJECT/.hats/shared/api.md"
assert_block "cto cannot write qa-report.md"            $G cto       "$PROJECT/.hats/shared/qa-report.md" "CTO can only write"

assert_allow "qa -> qa-report.md"                       $G qa        "$PROJECT/.hats/shared/qa-report.md"
assert_allow "qa -> test-contract.md"                   $G qa        "$PROJECT/.hats/shared/test-contract.md"
assert_block "qa cannot write stack.md"                 $G qa        "$PROJECT/.hats/shared/stack.md" "QA can only write"

assert_allow "developer -> dev2qa.md"                   $G developer "$PROJECT/.hats/shared/dev2qa.md"
assert_allow "developer -> setup.md"                    $G developer "$PROJECT/.hats/shared/setup.md"
assert_block "developer cannot write qa2dev.md"         $G developer "$PROJECT/.hats/shared/qa2dev.md" "Developer can only write"

# ── an unknown role is confined, not waved through ────────────────────────────
# I got this wrong on the first pass and asserted the opposite. Rule 3
# (`ROLE != developer`) runs BEFORE the per-role case, so a role nobody has
# heard of is treated as «not the developer»: it may write inside .hats/ and
# nowhere else. Only the drawer-and-mailbox rules below it are skipped.
# Stated here because the next reader will guess, and half the guesses are wrong.
assert_block "an unknown role cannot write source"  $G solo "$PROJECT/src/index.ts" "can only write inside .hats/"
assert_allow "an unknown role may write inside .hats/" $G solo "$PROJECT/.hats/shared/notes.md"
assert_allow "an unknown role is not held to the mailbox list" $G solo "$PROJECT/.hats/shared/stack.md"

# ── channels are directories now, and ownership did not move ─────────────────
# `shared/qa2dev.md` became `shared/qa2dev/0143-2026-08-02-qa.md`. The rules
# below know channels by basename, so without the reduction in guard.sh every
# write to the new shape would be refused and the migration would strand.
mkdir -p "$PROJECT/.hats/shared"/{qa2dev,dev2qa,manager2team}
assert_allow "qa writes an entry into its own channel"   $G qa        "$PROJECT/.hats/shared/qa2dev/0143-2026-08-02-qa.md"
assert_block "developer cannot write into qa's channel"  $G developer "$PROJECT/.hats/shared/qa2dev/0143-2026-08-02-qa.md" "Developer can only write"
assert_allow "developer writes an entry into dev2qa"     $G developer "$PROJECT/.hats/shared/dev2qa/0007-2026-08-02-developer.md"
assert_block "qa cannot write into dev2qa"               $G qa        "$PROJECT/.hats/shared/dev2qa/0007-2026-08-02-developer.md" "QA can only write"
assert_allow "manager writes into manager2team"          $G manager   "$PROJECT/.hats/shared/manager2team/0064-2026-08-02-manager.md"
assert_block "cto cannot write into manager2team"        $G cto       "$PROJECT/.hats/shared/manager2team/0064-2026-08-02-manager.md" "CTO can only write"
assert_block "channel entries take .md only"             $G qa        "$PROJECT/.hats/shared/qa2dev/notes.txt" "must end .md"
# The generated files live in the channel and belong to whoever owns it.
assert_allow "the channel owner may write its INDEX.md"  $G qa        "$PROJECT/.hats/shared/qa2dev/INDEX.md"
assert_block "and nobody else may"                       $G developer "$PROJECT/.hats/shared/qa2dev/INDEX.md" "Developer can only write"
# The old flat shape keeps working — projects migrate when they choose to.
assert_allow "the pre-migration flat file still works"   $G qa        "$PROJECT/.hats/shared/qa2dev.md"

# ── Codex apply_patch is normalized into the same path decisions ─────────────
PATCH="*** Begin Patch
*** Add File: src/codex.ts
+export const host = 'codex'
*** End Patch"
run_codex_patch developer "$PATCH"
assert_eq "Codex: developer may patch source" "$GUARD_CODE" "0"
run_codex_patch qa "$PATCH"
if [ "$GUARD_CODE" -eq 2 ] && echo "$GUARD_ERR" | grep -q "can only write inside .hats/"; then
  _ok "Codex: qa may not patch source"
else
  _fail "Codex: qa may not patch source" "expected the normal source fence, got $GUARD_CODE ($GUARD_ERR)"
fi

PATCH="*** Begin Patch
*** Add File: .hats/shared/specs/codex.feature
+Feature: Codex hooks
*** End Patch"
run_codex_patch manager "$PATCH"
assert_eq "Codex: manager may patch a spec" "$GUARD_CODE" "0"
run_codex_patch qa "$PATCH"
if [ "$GUARD_CODE" -eq 2 ] && echo "$GUARD_ERR" | grep -q "owned by the manager"; then
  _ok "Codex: qa may not patch a spec"
else
  _fail "Codex: qa may not patch a spec" "expected the feature fence, got $GUARD_CODE ($GUARD_ERR)"
fi

PATCH="*** Begin Patch
*** Update File: src/ok.ts
@@
-old
+new
*** Update File: .hats/qa/secret.test.ts
@@
-old
+new
*** End Patch"
run_codex_patch developer "$PATCH"
if [ "$GUARD_CODE" -eq 2 ] && echo "$GUARD_ERR" | grep -q "cannot write to .hats/qa/"; then
  _ok "Codex: every path in a multi-file patch must pass"
else
  _fail "Codex: every path in a multi-file patch must pass" "expected the qa-dir fence, got $GUARD_CODE ($GUARD_ERR)"
fi

PATCH="*** Begin Patch
*** Update File: src/original.ts
*** Move to: .hats/qa/moved.ts
@@
-old
+new
*** End Patch"
run_codex_patch developer "$PATCH"
if [ "$GUARD_CODE" -eq 2 ] && echo "$GUARD_ERR" | grep -q "cannot write to .hats/qa/"; then
  _ok "Codex: a move checks its destination"
else
  _fail "Codex: a move checks its destination" "expected the move destination fence, got $GUARD_CODE ($GUARD_ERR)"
fi

run_codex_patch qa "not an apply_patch envelope"
if [ "$GUARD_CODE" -eq 2 ] && echo "$GUARD_ERR" | grep -q "recognizable file paths"; then
  _ok "Codex: an unrecognized patch fails closed"
else
  _fail "Codex: an unrecognized patch fails closed" "expected a fail-closed refusal, got $GUARD_CODE ($GUARD_ERR)"
fi

PATCH="*** Begin Patch
*** Update File: .hats/role
@@
-qa
+manager
*** End Patch"
run_codex_patch qa "$PATCH"
if [ "$GUARD_CODE" -eq 0 ] && [ "$(cat "$PROJECT/.hats/sessions/$SESSION")" = "manager" ]; then
  _ok "Codex: a role switch is recorded from patch content"
else
  _fail "Codex: a role switch is recorded from patch content" "code $GUARD_CODE; session role $(cat "$PROJECT/.hats/sessions/$SESSION" 2>/dev/null || echo missing)"
fi

mkdir -p "$PROJECT/.hats/tasks/0001-codex-gate"
printf 'status: open\n' > "$PROJECT/.hats/tasks/0001-codex-gate/task.md"
PATCH="*** Begin Patch
*** Update File: .hats/tasks/0001-codex-gate/task.md
@@
-status: open
+status: done
*** End Patch"
run_codex_patch developer "$PATCH"
if [ "$GUARD_CODE" -eq 2 ] && echo "$GUARD_ERR" | grep -q "open -> done is refused"; then
  _ok "Codex: task transitions still pass through the gates"
else
  _fail "Codex: task transitions still pass through the gates" "expected the open -> done gate, got $GUARD_CODE ($GUARD_ERR)"
fi

summary
