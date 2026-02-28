#!/bin/bash
# Blocks Write/Edit to directories passed as arguments.
# Usage: guard.sh tests/ features/ shared/
# Reads PreToolUse hook JSON from stdin.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

for blocked in "$@"; do
  if echo "$FILE_PATH" | grep -q "/${blocked}" || echo "$FILE_PATH" | grep -q "^${blocked}"; then
    echo "Blocked: this role cannot write to ${blocked}" >&2
    exit 2
  fi
done

exit 0
