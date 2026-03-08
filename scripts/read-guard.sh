#!/bin/bash
# Blocks Read/Glob/Grep to directories the current role cannot access.
# Called from hooks/hooks.json. Reads .hats/role for the active agent.

INPUT=$(cat)

ROLE_FILE=".hats/role"
if [ ! -f "$ROLE_FILE" ]; then
  exit 0
fi

ROLE=$(cat "$ROLE_FILE")
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
    echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"read_block\",\"role\":\"$ROLE\",\"file\":\"$PATH_VAL\",\"tool\":\"$TOOL_NAME\",\"reason\":\"$1\"}" >> "$LOG_DIR/$(date -u +%Y-%m-%d).jsonl"
  fi
  echo "Blocked: $1" >&2
  exit 2
}

# Per-role read restrictions
case "$ROLE" in
  manager)   BLOCKED=".hats/qa/" ;;
  designer)  BLOCKED=".hats/qa/" ;;
  cto)       BLOCKED=".hats/qa/" ;;
  qa)        BLOCKED="" ;;
  developer) BLOCKED=".hats/qa/" ;;
  *) exit 0 ;;
esac

for blocked in $BLOCKED; do
  if echo "$PATH_VAL" | grep -q "/${blocked}" || echo "$PATH_VAL" | grep -q "^${blocked}"; then
    read_block "${ROLE} cannot read ${blocked}"
  fi
done

exit 0
