#!/bin/bash
# Blocks Read/Glob/Grep to directories the current role cannot access.
# Called from hooks/hooks.json. Reads .hats/role for the active agent.

INPUT=$(cat)

# shellcheck source=common.sh
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

ROLE=$(hats_role "$INPUT")
if [ -z "$ROLE" ]; then
  exit 0
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Read uses file_path, Glob uses pattern/path, Grep uses path/pattern
PATH_VAL=$(echo "$INPUT" | jq -r '
  .tool_input.file_path //
  .tool_input.path //
  .tool_input.pattern //
  empty
')

if [ -z "$PATH_VAL" ]; then
  exit 0
fi

# Resolve symlinks (legacy compat — v4.0.0 removed symlinks but this is harmless)
# Only resolve if the parent directory exists (i.e. it's a real path, not a pattern)
PARENT=$(dirname "$PATH_VAL")
if [ -d "$PARENT" ]; then
  PATH_VAL="$(cd "$PARENT" && pwd -P)/$(basename "$PATH_VAL")"
fi

# Debug logging helper for blocked reads
read_block() {
  if [ -f ".hats/debug" ]; then
    LOG_DIR=".hats/logs"; mkdir -p "$LOG_DIR"
    HV=$(hats_version)
    MODEL=$(hats_model "$INPUT")
    echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"hv\":\"$HV\",\"model\":\"$MODEL\",\"event\":\"read_block\",\"role\":\"$ROLE\",\"file\":\"$PATH_VAL\",\"tool\":\"$TOOL_NAME\",\"reason\":\"$1\"}" >> "$LOG_DIR/$(date -u +%Y-%m-%d).jsonl"
  fi
  echo "Blocked: $1" >&2
  exit 2
}

# G1 — QA MAY NOT READ THE IMPLEMENTATION.
#
# The README sold this as the product: «the Developer literally can't read
# tests, and the QA can't read source code». Only the first half was ever
# enforced — `qa) BLOCKED=""`. QA could read every line of `src/`.
#
# It is not a detail, it is the thesis. Roles are split so that QA writes tests
# from the SPEC and cannot inherit the implementation's blind spots. A QA that
# has read the code tests what the code does, which is the exact failure the
# split exists to prevent, wearing a badge that says it was prevented.
#
# WHY THIS ONE IS AN ALLOW-LIST AND NOT A BLOCK-LIST. There is no way to name
# «the implementation» — it is whatever the project happens to call its
# directories. So for QA the project root is closed and a short list is opened:
# the things it genuinely cannot write tests without. Anything else it needs
# belongs in `stack.md` or `setup.md`, which is what those files are for.
#
# ESCAPE HATCH, on purpose. `.hats/qa/read-allow` — one glob per line — widens
# the list per project. A fence with no gate gets torn down; a fence with a
# gate that has to be written down stays up.
qa_may_read() {
  local p="$1" base allow
  base=$(basename "$p")
  case "$base" in
    package.json|package-lock.json|pnpm-lock.yaml|yarn.lock|Package.swift|\
    requirements.txt|pyproject.toml|poetry.lock|go.mod|go.sum|Gemfile|\
    Gemfile.lock|Cargo.toml|composer.json|Makefile|justfile|\
    docker-compose.yml|docker-compose.yaml|Dockerfile|\
    tsconfig.json|.env.example|README.md|\
    playwright.config.*|jest.config.*|vitest.config.*|cypress.config.*|\
    pytest.ini|tox.ini|.mocharc.*|karma.conf.*)
      return 0 ;;
  esac
  if [ -f ".hats/qa/read-allow" ]; then
    while IFS= read -r allow; do
      [ -n "$allow" ] || continue
      case "$allow" in \#*) continue ;; esac
      # shellcheck disable=SC2254
      case "$p" in $allow) return 0 ;; esac
    done < ".hats/qa/read-allow"
  fi
  return 1
}

# Per-role read restrictions
case "$ROLE" in
  manager)   BLOCKED=".hats/qa/" ;;
  designer)  BLOCKED=".hats/qa/" ;;
  cto)       BLOCKED="" ;;
  qa)        BLOCKED=""
             # Inside .hats/ everything QA is allowed elsewhere stays allowed:
             # specs, stack, designs, its own tests, the channels.
             case "$PATH_VAL" in
               */.hats/*|.hats/*) : ;;
               *) qa_may_read "$PATH_VAL" || read_block "QA writes tests from the SPEC, not from the implementation — reading the project's source would hand it the blind spots the roles are split to avoid. Manifests, configs and README are open; anything else you need belongs in .hats/shared/stack.md or setup.md. To widen this for THIS project, add a glob line to .hats/qa/read-allow" ;;
             esac ;;
  developer) BLOCKED=".hats/qa/" ;;
  *) exit 0 ;;
esac

# The directory ITSELF must match, not only paths inside it. `$BLOCKED` entries
# carry a trailing slash, so the old `grep "/${blocked}"` missed a path that
# ends at the directory — and Grep/Glob are handed exactly that shape. The
# fence looked closed and had a gap the width of one character.
for blocked in $BLOCKED; do
  b=$(echo "${blocked%/}" | sed 's/\./\\./g')
  if echo "$PATH_VAL" | grep -qE "(^|/)${b}(/|$)"; then
    read_block "${ROLE} cannot read ${blocked}"
  fi
done

exit 0
