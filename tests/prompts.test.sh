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
assert_true "the task discipline exists"    test -f agents/_shared/tasks.md
assert_true "the evidence discipline exists" test -f agents/_shared/evidence.md
for r in $ROLES; do
  assert_true "$r is sent to the route map"        grep -q "_shared/pipeline.md" "agents/$r.md"
  assert_true "$r is sent to the channel discipline" grep -q "_shared/channels.md" "agents/$r.md"
  assert_true "$r is sent to the task discipline"    grep -q "_shared/tasks.md" "agents/$r.md"
  assert_true "$r is sent to the evidence discipline" grep -q "_shared/evidence.md" "agents/$r.md"
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

# The skills say the same things the agent files do, and drifted apart once
# already: `autopilot` kept sending roles to `qa2dev.md` for eight lines after
# the channels became directories, and no row could see it.
for s in skills/*/SKILL.md; do
  stale=$(grep -oE '[a-z0-9]+2[a-z0-9]+\.md' "$s" | sort -u | tr '\n' ' ')
  assert_eq "$(dirname "$s") names no channel as a flat .md" "$stale" ""
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
assert_true "it says how firmly the role is pinned"  grep -q "HATS_ROLE" agents/_shared/pipeline.md
assert_true "it says switches are recorded"          grep -q "role-history" agents/_shared/pipeline.md
assert_true "it names the edge of the fences"        grep -q "A shell command is not inspected" agents/_shared/pipeline.md

# ── the channel discipline says the thing that broke ──────────────────────────
assert_true "it explains why one file per entry" grep -q "2000 lines" agents/_shared/channels.md
assert_true "it says read the index first"       grep -q "INDEX.md" agents/_shared/channels.md
assert_true "it covers un-migrated projects"     grep -q "not migrated" agents/_shared/channels.md
assert_true "it keeps threads as they were"      grep -q "threads" agents/_shared/channels.md
assert_true "it says status.json is not a channel" \
  grep -q "state file, not a channel" agents/_shared/channels.md
assert_true "it names the 106 KB that proves it"  grep -q "106 KB" agents/_shared/channels.md
assert_true "it explains unread against directories" grep -q "read_by" agents/_shared/channels.md

# ── the task discipline says what the gates are and why ───────────────────────
assert_true "it names the open->done refusal"     grep -q "open -> done" agents/_shared/tasks.md
assert_true "it names understanding.md"           grep -q "understanding.md" agents/_shared/tasks.md
assert_true "it names resolution.md"              grep -q "resolution.md" agents/_shared/tasks.md
assert_true "it says the gates are in the hook"   grep -q "enforced by the hook" agents/_shared/tasks.md
assert_true "it carries the queue rule"           grep -q "take tasks by priority" agents/_shared/tasks.md
assert_true "and the ask-before-continuing half"  grep -q "then ASK whether to" agents/_shared/tasks.md

# ── evidence: the rule that pays for itself ───────────────────────────────────
assert_true "it demands the test be seen going red" \
  grep -q "watch the row go red" agents/_shared/evidence.md
assert_true "it says a falsification that changes nothing IS the finding" \
  grep -q "changes nothing is the finding" agents/_shared/evidence.md
assert_true "a report owes what was checked"   grep -q "What was checked" agents/_shared/evidence.md
assert_true "and what was concluded"           grep -q "What was concluded" agents/_shared/evidence.md
assert_true "it forbids reporting unrun work"  grep -q "written, not yet run" agents/_shared/evidence.md
assert_true "it asks for the number, verbatim" grep -q "give the number" agents/_shared/evidence.md
assert_true "it says how to falsify before an implementation exists" \
  grep -q "nothing yet to break" agents/_shared/evidence.md
assert_true "and names the reference/broken stub pattern" \
  grep -q "broken stub" agents/_shared/evidence.md

# ── the helpers can actually be found ─────────────────────────────────────────
# The docs named `$HATS_PLUGIN` and nothing set it; a live role went hunting
# through the filesystem for the plugin root.
assert_true "no doc names a variable nobody sets" \
  bash -c '! grep -rl "HATS_PLUGIN/scripts" agents/ README.md MIGRATIONS.md 2>/dev/null | grep -q .'
assert_true "the channel discipline says how to locate the scripts" \
  grep -q "HATS=" agents/_shared/channels.md

# ── the QA report carries a signature, not prose about effort ─────────────────
assert_true "the report template has a Signature block" grep -q "^## Signature" agents/qa.md
assert_true "it asks what was checked"    grep -q "^- Checked:" agents/qa.md
assert_true "it asks what was concluded"  grep -q "^- Concluded:" agents/qa.md
assert_true "it asks what was falsified"  grep -q "^- Falsified:" agents/qa.md
assert_true "and says a green never seen failing is not evidence" \
  grep -q "not evidence" agents/qa.md

# ── QA is told about its own fence, not just fenced ───────────────────────────
assert_true "qa is told it cannot read source"  grep -q "cannot read the project's source" agents/qa.md
assert_true "and what stays open"               grep -q "Manifests, test configs" agents/qa.md
assert_true "and where to put the rest"         grep -q "stack.md\` or \`setup.md" agents/qa.md
assert_true "and the escape hatch"              grep -q "read-allow" agents/qa.md

# ── doctor knows about the migration and about sizes ──────────────────────────
assert_true "doctor offers the channel migration" grep -q "channel.sh" skills/doctor/SKILL.md
assert_true "doctor checks status.json size"      grep -q "status.json.* over 4 KB" skills/doctor/SKILL.md
assert_true "doctor checks channel size"          grep -q "INDEX.md.* over 100 KB" skills/doctor/SKILL.md
assert_true "doctor checks stray build output"    grep -q "node_modules" skills/doctor/SKILL.md
assert_true "doctor checks the task board"        grep -q "no .understanding.md" skills/doctor/SKILL.md
assert_true "doctor spots a stalled task"         grep -q "untouched for more than" skills/doctor/SKILL.md
assert_true "init creates the task board"         grep -q ".hats/tasks/" skills/init/SKILL.md

summary
