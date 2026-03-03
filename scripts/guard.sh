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

# 1. Always allow writing .hats-role (role activation file)
if [ "$(basename "$FILE_PATH")" = ".hats-role" ]; then
  exit 0
fi

# 2. .feature files are owned by the manager -- no other role may write them
if [ "$ROLE" != "manager" ] && echo "$FILE_PATH" | grep -qE '\.feature$'; then
  echo "Blocked: .feature files are owned by the manager role" >&2
  exit 2
fi

# 3. Non-developer roles must write inside .hats/
if [ "$ROLE" != "developer" ]; then
  if ! (echo "$FILE_PATH" | grep -q "/.hats/" || echo "$FILE_PATH" | grep -q "^.hats/"); then
    echo "Blocked: ${ROLE} can only write inside .hats/" >&2
    exit 2
  fi
fi

# 4. Per-role blocked dirs and shared/ file restrictions
case "$ROLE" in
  manager)   BLOCKED=".hats/designer/ .hats/cto/ .hats/qa/"
             if echo "$FILE_PATH" | grep -q "\.hats/shared/"; then
               BASENAME=$(basename "$FILE_PATH")
               case "$BASENAME" in
                 manager2team.md) ;;  # allowed
                 *) echo "Blocked: Manager can only write manager2team.md in .hats/shared/" >&2
                    exit 2 ;;
               esac
             fi ;;
  designer)  BLOCKED=".hats/manager/ .hats/cto/ .hats/qa/"
             if echo "$FILE_PATH" | grep -q "\.hats/shared/"; then
               BASENAME=$(basename "$FILE_PATH")
               case "$BASENAME" in
                 designer2team.md) ;;  # allowed
                 *) echo "Blocked: Designer can only write designer2team.md in .hats/shared/" >&2
                    exit 2 ;;
               esac
             fi ;;
  cto)       BLOCKED=".hats/manager/ .hats/designer/ .hats/qa/"
             if echo "$FILE_PATH" | grep -q "\.hats/shared/"; then
               BASENAME=$(basename "$FILE_PATH")
               case "$BASENAME" in
                 stack.md|setup.md|api.md|cto2team.md) ;;  # allowed
                 *) echo "Blocked: CTO can only write stack.md, setup.md, api.md, cto2team.md in .hats/shared/" >&2
                    exit 2 ;;
               esac
             fi ;;
  qa)        BLOCKED=".hats/manager/ .hats/designer/ .hats/cto/"
             if echo "$FILE_PATH" | grep -q "\.hats/shared/"; then
               BASENAME=$(basename "$FILE_PATH")
               case "$BASENAME" in
                 qa-report.md|qa2dev.md|qa2designer.md) ;;  # allowed
                 *) echo "Blocked: QA can only write qa-report.md, qa2dev.md, qa2designer.md in .hats/shared/" >&2
                    exit 2 ;;
               esac
             fi ;;
  developer) BLOCKED=".hats/manager/ .hats/designer/ .hats/cto/ .hats/qa/"
             if echo "$FILE_PATH" | grep -q "\.hats/shared/"; then
               BASENAME=$(basename "$FILE_PATH")
               case "$BASENAME" in
                 setup.md|api.md|dev2qa.md|dev2designer.md) ;;  # allowed
                 *) echo "Blocked: Developer can only write setup.md, api.md, dev2qa.md, dev2designer.md in .hats/shared/" >&2
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
