#!/bin/bash
# `.hats/role` — where the fence keeps its own position.
#
# The guards are real mechanisms. But WHICH rules they apply was read from a
# plain file, per-DIRECTORY and writable by the very agent being fenced. Two
# consequences, both once demonstrated here by doing them:
#
#   G3  two sessions in one repo shared one fence   -> CLOSED below
#   G2  a role could take its own fence off in one write
#                                                   -> closed under HATS_ROLE,
#                                                      audited otherwise
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PROJECT=$(make_project)
trap 'rm -rf "$PROJECT"' EXIT
G=guard.sh

echo "role store — the fence's own position"

# ── the switch has to work, or hats does not work ─────────────────────────────
SESSION=A
switch_role none qa
assert_eq "a role may still be switched (this is required)" "$SWITCH_CODE" "0"
assert_block "and the new role takes effect" $G - "$PROJECT/src/index.ts" "can only write inside .hats/"

# ── G3, CLOSED — each session carries its own position ────────────────────────
#
# Session A is qa. Session B switches itself to developer. A must still be qa:
# B's switch is recorded against B, not against the directory.
SESSION=A; switch_role none qa
SESSION=B; switch_role qa developer
SESSION=B; run_guard $G - "{\"file_path\":\"$PROJECT/src/index.ts\"}"
assert_eq "session B, now developer, may write source" "$GUARD_CODE" "0"
SESSION=A; run_guard $G - "{\"file_path\":\"$PROJECT/src/index.ts\"}"
assert_eq "session A, still qa, is STILL refused source" "$GUARD_CODE" "2"

# ── G2 under HATS_ROLE, CLOSED — the fenced thing cannot relabel itself ───────
SESSION=C
export HATS_ROLE=qa
run_guard $G - "{\"file_path\":\"$PROJECT/src/index.ts\"}"
assert_eq "pinned to qa by the environment: source refused" "$GUARD_CODE" "2"
switch_role qa developer
assert_eq "the self-relabel is REFUSED"    "$SWITCH_CODE" "2"
assert_true "and the refusal says why" grep -q "pinned to 'qa' by HATS_ROLE" <<<"$SWITCH_ERR"
run_guard $G - "{\"file_path\":\"$PROJECT/src/index.ts\"}"
assert_eq "after the attempt, source is still refused" "$GUARD_CODE" "2"
# The env outranks both files, including one written behind the guard's back.
echo developer > "$PROJECT/.hats/role"
run_guard $G - "{\"file_path\":\"$PROJECT/src/index.ts\"}"
assert_eq "even a hand-written role file loses to HATS_ROLE" "$GUARD_CODE" "2"
unset HATS_ROLE

# ── G2 without the env — still open, but no longer invisible ──────────────────
#
# Left deliberately: the same door serves the human at the wheel, and refusing
# it everywhere would mean one session per role for everyone. What changed is
# that it is written down as it happens.
SESSION=D
switch_role qa developer
gap G2 assert_eq "without HATS_ROLE a role can still relabel itself" "$SWITCH_CODE" "2"

assert_true "every switch leaves an audit line" test -f "$PROJECT/.hats/role-history"
assert_true "the audit names from, to and the session" \
  grep -qE "^[0-9T:-]+Z +[A-Za-z0-9-]+ +qa -> developer$" "$PROJECT/.hats/role-history"
assert_true "the audit does NOT depend on the debug flag" test ! -f "$PROJECT/.hats/debug"

# ── the hand-written path keeps working, and wins when it is newer ────────────
#
# `echo x > .hats/role` in a Bash call never passes the Write/Edit hook, so the
# session file cannot learn about it. Newest-wins keeps that path honest instead
# of quietly aiming the fence at a stale role.
SESSION=E
switch_role none cto                      # session file says cto
echo manager > "$PROJECT/.hats/role"      # a human, by hand, afterwards
run_guard $G - "{\"file_path\":\"$PROJECT/.hats/shared/manager2team.md\"}"
assert_eq "a hand-written role newer than the session file wins" "$GUARD_CODE" "0"

# THE CASE THAT DECIDES THE RULE, and the one the first version of this file
# did not have: another session switched after us, and a human then hand-wrote
# something else. Both conditions hold at once — another session holds a value
# different from
# ours AND another session claims a different value — only the CONTENT of the
# shared file tells a hand-edit from a switch.
# Without the content check, the hand-edit is swallowed as if it were the other
# session's switch, and the human is silently ignored.
SESSION=F; switch_role none qa            # F: qa
SESSION=G; switch_role qa developer       # G switches after F
# `designer` on purpose: no session in this file holds it. The first attempt
# used `cto`, which session E above happens to hold — and the row failed,
# correctly, on the one ambiguity this rule cannot resolve (a human writing
# exactly what some other live session already has). That is worth knowing
# about, so it is said out loud rather than dodged silently.
echo designer > "$PROJECT/.hats/role"     # a human writes what nobody claims
SESSION=F; run_guard $G - "{\"file_path\":\"$PROJECT/.hats/shared/designs/home.md\"}"
assert_eq "a hand-edit is not mistaken for another session's switch" "$GUARD_CODE" "0"
SESSION=F; run_guard $G - "{\"file_path\":\"$PROJECT/src/index.ts\"}"
assert_eq "and the hand-written designer is still fenced out of source" "$GUARD_CODE" "2"

# The ambiguity itself, pinned so nobody rediscovers it as a bug: when the
# hand-written value IS claimed by another session, the session's own position
# wins. Timestamps could not have told these apart either.
echo cto > "$PROJECT/.hats/role"          # session E holds `cto`
SESSION=F; run_guard $G - "{\"file_path\":\"$PROJECT/src/index.ts\"}"
assert_eq "hand-writing a value another session holds keeps ours (known limit)" "$GUARD_CODE" "2"

summary
