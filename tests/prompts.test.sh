#!/bin/bash
# The prompts — because a mechanism nobody is told about is a mechanism nobody
# uses, and half of hats IS its prompts.
#
# These rows do not judge writing. They check the things that go silently wrong:
# a role still pointed at a file that is now a directory, a shared fragment
# nobody reads, a helper nobody is told exists.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$HATS_ROOT"
ROLES="manager designer cto qa developer"

echo "prompts — what the roles are actually told"

# ── the shared fragments exist and are reachable from every role ──────────────
assert_true "the route map exists"        test -f agents/_shared/pipeline.md
assert_true "the channel discipline exists" test -f agents/_shared/channels.md
for r in $ROLES; do
  assert_true "$r is sent to the route map"        grep -q "_shared/pipeline.md" "agents/$r.md"
  assert_true "$r is sent to the channel discipline" grep -q "_shared/channels.md" "agents/$r.md"
done

# ── nobody is still pointed at a channel FILE ─────────────────────────────────
#
# This is the row that would have caught the migration stranding: the shape
# changed under the prompts, and a prompt that says «read qa2dev.md» sends the
# role to a path that no longer exists — or worse, to the ARCHIVE.
for r in $ROLES; do
  stale=$(grep -oE '[a-z0-9]+2[a-z0-9]+\.md' "agents/$r.md" | sort -u | tr '\n' ' ')
  assert_eq "$r names no channel as a flat .md" "$stale" ""
done

# ── and everyone is told how to write one ─────────────────────────────────────
for r in $ROLES; do
  assert_true "$r is told about channel.sh append" grep -q "channel.sh\" append\|channel.sh append" "agents/$r.md"
done

# ── the route map earns its place ─────────────────────────────────────────────
# Not a style check: each of these is a defect this cycle paid for once.
assert_true "the map names all five stations" \
  bash -c 'for r in manager designer cto qa developer; do grep -qi "$r" agents/_shared/pipeline.md || exit 1; done'
assert_true "it says what is reachable without asking"  grep -q "REACHABLE" agents/_shared/pipeline.md
assert_true "it says what needs the human"              grep -q "NEEDS THE HUMAN" agents/_shared/pipeline.md
assert_true "it says what is impossible"                grep -q "IMPOSSIBLE" agents/_shared/pipeline.md
assert_true "it caps retries instead of letting them run" grep -q "TWO ATTEMPTS" agents/_shared/pipeline.md
assert_true "it forbids asking the human to run what you can run" \
  grep -q "DO NOT ASK THE HUMAN TO RUN" agents/_shared/pipeline.md
assert_true "it defines done as shown-red, not just green" \
  grep -q "red for the stated reason" agents/_shared/pipeline.md
assert_true "it routes escalation instead of leaving it to taste" \
  grep -q "Escalate along the line" agents/_shared/pipeline.md

# ── the channel discipline says the thing that broke ──────────────────────────
assert_true "it explains why one file per entry" grep -q "2000 lines" agents/_shared/channels.md
assert_true "it says read the index first"       grep -q "INDEX.md" agents/_shared/channels.md
assert_true "it covers un-migrated projects"     grep -q "not migrated" agents/_shared/channels.md
assert_true "it keeps threads as they were"      grep -q "threads" agents/_shared/channels.md

# ── doctor knows about the migration and about sizes ──────────────────────────
assert_true "doctor offers the channel migration" grep -q "channel.sh" skills/doctor/SKILL.md
assert_true "doctor checks status.json size"      grep -q "status.json.* over 4 KB" skills/doctor/SKILL.md
assert_true "doctor checks channel size"          grep -q "INDEX.md.* over 100 KB" skills/doctor/SKILL.md
assert_true "doctor checks stray build output"    grep -q "node_modules" skills/doctor/SKILL.md

summary
