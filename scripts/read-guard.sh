#!/bin/bash
# Blocks Read/Glob/Grep to directories the current role cannot access.
# Called from hooks/hooks.json. Reads .hats-role for the active agent.

INPUT=$(cat)

ROLE_FILE=".hats-role"
if [ ! -f "$ROLE_FILE" ]; then
  exit 0
fi

ROLE=$(cat "$ROLE_FILE")

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

# Per-role read restrictions
case "$ROLE" in
  manager)   BLOCKED="developer/ qa/" ;;
  designer)  BLOCKED="developer/ qa/" ;;
  cto)       BLOCKED="developer/ qa/" ;;
  qa)        BLOCKED="developer/" ;;
  developer) BLOCKED="qa/" ;;
  *) exit 0 ;;
esac

for blocked in $BLOCKED; do
  if echo "$PATH_VAL" | grep -q "/${blocked}" || echo "$PATH_VAL" | grep -q "^${blocked}"; then
    echo "Blocked: ${ROLE} cannot read ${blocked}" >&2
    exit 2
  fi
done

exit 0
