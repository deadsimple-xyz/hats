#!/bin/bash
# Blocks Write/Edit to directories the current role cannot access.
# Called from hooks/hooks.json. Reads .hats-role for the active agent.

INPUT=$(cat)

ROLE_FILE=".hats-role"
if [ ! -f "$ROLE_FILE" ]; then
  exit 0
fi

ROLE=$(cat "$ROLE_FILE")
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Per-role write restrictions
case "$ROLE" in
  manager)  BLOCKED="designer/ shared/ developer/ qa/" ;;
  designer) BLOCKED="manager/ shared/ developer/ qa/" ;;
  cto)      BLOCKED="manager/ designer/ developer/ qa/" ;;
  qa)       BLOCKED="manager/ designer/ developer/"
            # qa CAN write shared/qa-report.md but nothing else in shared/
            if echo "$FILE_PATH" | grep -q "shared/" && ! echo "$FILE_PATH" | grep -q "shared/qa-report.md"; then
              echo "Blocked: QA can only write shared/qa-report.md" >&2
              exit 2
            fi ;;
  developer) BLOCKED="manager/ designer/ qa/" ;;
  *) exit 0 ;;
esac

for blocked in $BLOCKED; do
  if echo "$FILE_PATH" | grep -q "/${blocked}" || echo "$FILE_PATH" | grep -q "^${blocked}"; then
    echo "Blocked: ${ROLE} cannot write to ${blocked}" >&2
    exit 2
  fi
done

exit 0
