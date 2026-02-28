#!/bin/bash
# Blocks Read/Glob/Grep access to directories passed as arguments.
# Usage: read-guard.sh src/ tests/
# Reads PreToolUse hook JSON from stdin.

INPUT=$(cat)

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

for blocked in "$@"; do
  if echo "$PATH_VAL" | grep -q "/${blocked}" || echo "$PATH_VAL" | grep -q "^${blocked}"; then
    echo "Blocked: this role cannot read ${blocked}" >&2
    exit 2
  fi
done

exit 0
