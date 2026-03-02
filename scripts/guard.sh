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

# Resolve symlinks so .hats-* paths map back to real directories
PARENT=$(dirname "$FILE_PATH")
if [ -d "$PARENT" ]; then
  FILE_PATH="$(cd "$PARENT" && pwd -P)/$(basename "$FILE_PATH")"
fi

# .feature files are owned by the manager -- no other role may write them
if [ "$ROLE" != "manager" ] && echo "$FILE_PATH" | grep -qE '\.feature$'; then
  echo "Blocked: .feature files are owned by the manager role" >&2
  exit 2
fi

# Per-role write restrictions
case "$ROLE" in
  manager)  BLOCKED="designer/ shared/ developer/ qa/" ;;
  designer) BLOCKED="manager/ shared/ developer/ qa/" ;;
  cto)      BLOCKED="manager/ designer/ developer/ qa/"
            # cto CAN write stack.md, setup.md, api.md in shared/ but nothing else
            if echo "$FILE_PATH" | grep -q "shared/"; then
              BASENAME=$(basename "$FILE_PATH")
              case "$BASENAME" in
                stack.md|setup.md|api.md) ;;  # allowed
                *) echo "Blocked: CTO can only write stack.md, setup.md, api.md in shared/" >&2
                   exit 2 ;;
              esac
            fi ;;
  qa)       BLOCKED="manager/ designer/ developer/"
            # qa CAN write shared/qa-report.md but nothing else in shared/
            if echo "$FILE_PATH" | grep -q "shared/"; then
              BASENAME=$(basename "$FILE_PATH")
              if [ "$BASENAME" != "qa-report.md" ]; then
                echo "Blocked: QA can only write shared/qa-report.md" >&2
                exit 2
              fi
            fi ;;
  developer) BLOCKED="manager/ designer/ qa/"
            # developer CAN write setup.md, api.md in shared/ but nothing else
            if echo "$FILE_PATH" | grep -q "shared/"; then
              BASENAME=$(basename "$FILE_PATH")
              case "$BASENAME" in
                setup.md|api.md) ;;  # allowed
                *) echo "Blocked: Developer can only write setup.md, api.md in shared/" >&2
                   exit 2 ;;
              esac
            fi ;;
  *) exit 0 ;;
esac

for blocked in $BLOCKED; do
  if echo "$FILE_PATH" | grep -q "/${blocked}" || echo "$FILE_PATH" | grep -q "^${blocked}"; then
    echo "Blocked: ${ROLE} cannot write to ${blocked}" >&2
    exit 2
  fi
done

exit 0
