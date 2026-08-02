#!/bin/bash
# G3, step one: WATCH the shell, do not fence it. Never blocks. Always exit 0.
#
# ── WHY THIS AND NOT A FENCE ─────────────────────────────────────────────────
# The guards hook the file tools. Bash is not hooked, so every rule in this
# project holds for a role using `Read`/`Write` and evaporates for one using a
# shell — demonstrated on 2026-08-02: as QA, `cat src/counter.ts` read the
# implementation, `echo x > src/counter.ts` wrote it, and a redirect into
# `task.md` skipped all three task gates.
#
# The obvious answer — add `Bash` to the matcher — is wrong, and expensively so.
# A command line is not a path: `sh -c '…'`, heredocs, `find -exec`, `make`,
# `npm test`, a script that reads a config which names a file. Deciding what a
# command will touch means parsing a shell, and a parser that is 95% right is a
# fence with a hole whose shape nobody knows. Meanwhile roles need Bash
# constantly and legitimately.
#
# So: record first. Let real roles work for a while, look at what they actually
# reach for, and only then decide what is safe to refuse. Guessing the rules in
# advance is how a discipline becomes a jam — this project has paid for that
# once already (#23, six correct criteria refused in a row).
#
# The log is one line per suspicious command, in `.hats/bash-audit.jsonl`. It
# is NOT behind the debug flag: the day you want it is the day nobody thought
# to turn logging on. It costs a `grep` per Bash call.
set -u

INPUT=$(cat)

# shellcheck source=common.sh
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

ROLE=$(hats_role "$INPUT")
[ -n "$ROLE" ] || exit 0

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$CMD" ] || exit 0

# What this role may not touch through the file tools. Deliberately the same
# vocabulary as the guards, so the audit measures the SAME rule rather than a
# second opinion about it.
case "$ROLE" in
  manager)   WATCH=".hats/qa/ .hats/designer/ .hats/cto/ .hats/developer/" ;;
  designer)  WATCH=".hats/qa/ .hats/manager/ .hats/cto/ .hats/developer/" ;;
  cto)       WATCH=".hats/manager/ .hats/designer/ .hats/qa/ .hats/developer/" ;;
  qa)        WATCH=".hats/manager/ .hats/designer/ .hats/cto/ .hats/developer/ src/ lib/ app/ pkg/" ;;
  developer) WATCH=".hats/qa/ .hats/manager/ .hats/designer/ .hats/cto/" ;;
  *) exit 0 ;;
esac

note() {
  local why="$1"
  local out=".hats/bash-audit.jsonl"
  mkdir -p "$(dirname "$out")" 2>/dev/null || exit 0
  # The command is truncated: the point is which shape happened, not to build a
  # second transcript of the session.
  printf '{"ts":"%s","role":"%s","why":"%s","cmd":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ROLE" "$why" \
    "$(printf '%s' "${CMD:0:200}" | jq -Rs .)" >> "$out" 2>/dev/null || true
}

for w in $WATCH; do
  case "$CMD" in
    *"$w"*) : ;;
    *) continue ;;
  esac
  # A redirect into it is a write; anything else naming it is at least a read.
  # Both are recorded, distinguished, and neither is refused.
  if echo "$CMD" | grep -qE ">[[:space:]]*[^|;&]*${w//\//\\/}"; then
    note "write-shaped command naming ${w}"
  else
    note "command naming ${w}"
  fi
  break
done

exit 0
