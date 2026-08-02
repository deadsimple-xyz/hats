#!/bin/bash
# `.hats/role` — where the fence keeps its own position.
#
# The guards are real mechanisms. But WHICH rules they apply is read from a
# plain file that the fenced agent may write at any moment — rule 1 of
# guard.sh allows it unconditionally, because roles must be able to switch.
#
# So the configuration of the mechanism is itself an instruction. These rows
# state what that costs, in the only way worth stating anything: by doing it.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PROJECT=$(make_project)
trap 'rm -rf "$PROJECT"' EXIT
G=guard.sh

echo "role store — the fence's own position"

# ── the switch has to work, or hats does not work ─────────────────────────────
assert_allow "a role may write .hats/role (this is required)" $G qa "$PROJECT/.hats/role"

# ── G2 — and therefore any role can take off its own fence in one write ───────
#
# Sequence, entirely within the rules as written:
#   1. role is `qa`; a write to src/ is refused
#   2. `qa` writes `developer` into .hats/role — allowed by rule 1
#   3. the same write to src/ now passes
#
# Nothing here is a trick. It is the documented behaviour, and it is how a
# human operator switches roles too. The point is that the fence cannot tell
# the operator from the agent, so «the QA literally can't write source» holds
# only as long as the QA does not decide otherwise.
assert_block "step 1 — as qa, source is refused" $G qa "$PROJECT/src/index.ts" "can only write inside .hats/"
echo developer > "$PROJECT/.hats/role"   # step 2: the write rule 1 permits
run_guard $G developer "{\"file_path\":\"$PROJECT/src/index.ts\"}"
gap G2 assert_eq "step 3 — after self-relabelling, source is still refused" "$GUARD_CODE" "2"

# ── G3 — the role is ambient: two sessions in one repo share one position ─────
#
# `.hats/role` is per-DIRECTORY, not per-session. Two Claude Code sessions in
# the same repo (one per product, a subagent alongside its parent, an autopilot
# beside a human) read and write the same byte. The second session's switch
# silently re-aims the first session's fence.
#
# Simulated here by doing exactly what two sessions do: write, then have the
# other one write.
echo qa > "$PROJECT/.hats/role"            # session A becomes qa
echo developer > "$PROJECT/.hats/role"     # session B becomes developer
run_guard $G developer "{\"file_path\":\"$PROJECT/src/index.ts\"}"
# Session A believes it is qa and that source is closed to it. It is not.
gap G3 assert_eq "session A's fence survives session B's role switch" "$GUARD_CODE" "2"

# ── the state is also sticky across time, which is a smaller version of G3 ────
# Left as a plain observation with a row, because the skills DO check activation
# status on entry — this one is handled by convention, and the convention works.
echo cto > "$PROJECT/.hats/role"
assert_block "a role left behind yesterday still rules today" $G cto "$PROJECT/src/x.ts" "can only write inside .hats/"

summary
