#!/bin/bash
# Blocks Write/Edit to directories the current role cannot access.
# Called from hooks/hooks.json. Reads .hats/role for the active agent.

INPUT=$(cat)

# shellcheck source=common.sh
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

ROLE=$(hats_role "$INPUT")
if [ -z "$ROLE" ]; then
  exit 0
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Codex exposes file edits as `apply_patch`. Its hook matcher accepts the
# Claude aliases `Write|Edit`, but the payload still carries the canonical
# tool name and puts the patch in `tool_input.command`, not `file_path`.
#
# Normalize that one multi-file call into the same single-path calls the guard
# has always decided. This keeps the policy below shared: Claude and Codex get
# the same rows, and a patch touching five files must pass all five.
if [ "$TOOL_NAME" = "apply_patch" ] && [ -z "$FILE_PATH" ] && [ -z "${HATS_GUARD_NORMALIZED:-}" ]; then
  PATCH=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
  PATHS=$(printf '%s\n' "$PATCH" | awk '
    /^\*\*\* (Add|Update|Delete) File: / {
      sub(/^\*\*\* (Add|Update|Delete) File: /, ""); print; next
    }
    /^\*\*\* Move to: / {
      sub(/^\*\*\* Move to: /, ""); print
    }
  ' | awk '!seen[$0]++')

  if [ -z "$PATHS" ]; then
    echo "Blocked: apply_patch did not expose any recognizable file paths" >&2
    exit 2
  fi

  while IFS= read -r PATCH_PATH; do
    [ -n "$PATCH_PATH" ] || continue
    # Keep content local to this file. A global collection could accidentally
    # apply `status: done` from one task to another file in the same patch, or
    # record a role name together with unrelated added lines.
    PATCH_CONTENT=$(printf '%s\n' "$PATCH" | awk -v target="$PATCH_PATH" '
      /^\*\*\* (Add|Update|Delete) File: / {
        current = $0
        sub(/^\*\*\* (Add|Update|Delete) File: /, "", current)
        next
      }
      current == target && /^\+/ {
        line = $0; sub(/^\+/, "", line); print line
      }
    ')
    NORMALIZED=$(echo "$INPUT" | jq \
      --arg path "$PATCH_PATH" \
      --arg content "$PATCH_CONTENT" \
      '.tool_name = "Write" | .tool_input = {file_path: $path, content: $content}')
    printf '%s\n' "$NORMALIZED" | HATS_GUARD_NORMALIZED=1 bash "$0"
    NORMALIZED_CODE=$?
    [ "$NORMALIZED_CODE" -eq 0 ] || exit "$NORMALIZED_CODE"
  done <<EOF
$PATHS
EOF
  exit 0
fi

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Resolve symlinks (legacy compat — v4.0.0 removed symlinks but this is harmless)
PARENT=$(dirname "$FILE_PATH")
if [ -d "$PARENT" ]; then
  FILE_PATH="$(cd "$PARENT" && pwd -P)/$(basename "$FILE_PATH")"
fi

# Debug logging helper for blocked writes
guard_block() {
  if [ -f ".hats/debug" ]; then
    LOG_DIR=".hats/logs"; mkdir -p "$LOG_DIR"
    HV=$(hats_version)
    MODEL=$(hats_model "$INPUT")
    echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"hv\":\"$HV\",\"model\":\"$MODEL\",\"event\":\"write_block\",\"role\":\"$ROLE\",\"file\":\"$FILE_PATH\",\"tool\":\"$TOOL_NAME\",\"reason\":\"$1\"}" >> "$LOG_DIR/$(date -u +%Y-%m-%d).jsonl"
  fi
  echo "Blocked: $1" >&2
  exit 2
}

# 1. The role file — the one write that moves the fence itself.
#
# G2/G3. Two things happen here that did not before:
#   * if HATS_ROLE pins the role, the switch is REFUSED. That is the whole
#     point of the env rung: where the fence must be real, the fenced thing
#     cannot relabel itself, and it is told so rather than silently ignored.
#   * otherwise the switch is allowed (skills and humans both need it) and
#     RECORDED — against this session, so a second session in the same repo
#     keeps its own position, and in .hats/role-history, so a switch is never
#     invisible afterwards.
if echo "$FILE_PATH" | grep -q '\.hats/role$'; then
  if [ -n "${HATS_ROLE:-}" ]; then
    guard_block "the role is pinned to '${HATS_ROLE}' by HATS_ROLE for this session; a role cannot relabel itself here"
  fi
  # Write carries `content`, Edit carries `new_string`. Either way it is the
  # role about to take effect.
  NEW_ROLE=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' \
             | tr -d '[:space:]')
  if [ -n "$NEW_ROLE" ]; then
    hats_record_role "$INPUT" "$NEW_ROLE" "$ROLE"
  fi
  exit 0
fi

# 1b. Allow plan-mode files for all roles
if echo "$FILE_PATH" | grep -q '/.claude/plans/'; then
  exit 0
fi

# 2. .feature files are owned by the manager -- no other role may write them
if [ "$ROLE" != "manager" ] && echo "$FILE_PATH" | grep -qE '\.feature$'; then
  guard_block ".feature files are owned by the manager role"
fi

# 3. Non-developer roles must write inside .hats/
if [ "$ROLE" != "developer" ]; then
  if ! (echo "$FILE_PATH" | grep -q "/.hats/" || echo "$FILE_PATH" | grep -q "^.hats/"); then
    guard_block "${ROLE} can only write inside .hats/"
  fi
fi

# 4a. shared/threads/*.md is open to all roles — any role can append to any thread.
# Filename must end .md. Subdirectories allowed (e.g. shared/threads/auth/login.md).
if echo "$FILE_PATH" | grep -q "\.hats/shared/threads/"; then
  if echo "$FILE_PATH" | grep -qE '\.md$'; then
    exit 0
  else
    guard_block "Files in .hats/shared/threads/ must end .md"
  fi
fi

# 4a-ante. TASKS — the three gates, enforced here rather than requested in a
# prompt. `scripts/task.sh` applies the same rules, but a role can Edit
# `task.md` directly and would sail straight past them; a gate that only the
# helper enforces is a convention wearing a mechanism's coat.
#
# Write carries the whole file in `content`, Edit carries a fragment in
# `new_string`. Either way, if the text sets a status, that is the transition
# being attempted.
case "$FILE_PATH" in
  */.hats/tasks/*/task.md)
    TASK_DIR=$(dirname "$FILE_PATH")
    WANT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' \
           | sed -nE 's/^status:[[:space:]]*([a-z_]+).*/\1/p' | head -1)
    if [ -n "$WANT" ]; then
      NOW=""
      [ -f "$FILE_PATH" ] && NOW=$(sed -nE 's/^status:[[:space:]]*(.*)$/\1/p' "$FILE_PATH" | head -1)
      # A task that was never in work was never understood, and «done» about it
      # says nothing anyone can rely on.
      if [ "$NOW" = "open" ] && [ "$WANT" = "done" ]; then
        guard_block "open -> done is refused: a task closes only after being in work. Set status: in_progress, write ${TASK_DIR}/understanding.md, then close with ${TASK_DIR}/resolution.md"
      fi
      # Say what you think the job is BEFORE doing it — afterwards the sentence
      # is a summary of what happened, which is a different and easier thing.
      if [ "$WANT" = "in_progress" ] && [ "$NOW" != "in_progress" ] && [ ! -s "$TASK_DIR/understanding.md" ]; then
        guard_block "in_progress needs ${TASK_DIR}/understanding.md — the file must exist and not be empty. Write what you think the job is, in your own words, then set the status"
      fi
      if [ "$WANT" = "done" ] && [ "$NOW" != "done" ] && [ ! -s "$TASK_DIR/resolution.md" ]; then
        guard_block "done needs ${TASK_DIR}/resolution.md — the file must exist and not be empty. Write what you checked and what you concluded, then close it"
      fi
    fi
    ;;
esac

# 4a-bis. Channels are DIRECTORIES now (scripts/channel.sh). `shared/qa2dev.md`
# became `shared/qa2dev/0143-....md`, so the basename check below — which knows
# only `qa2dev.md` — would refuse every write to the new shape and quietly
# strand the migration. Ownership is unchanged: the channel's name still says
# who may write it. Only the shape moved.
#
# Reduce `shared/<channel>/<entry>.md` to `shared/<channel>.md` and let the
# existing per-role rules decide, so there is exactly one place that knows who
# owns which channel.
CHANNEL_DIR=$(echo "$FILE_PATH" | sed -nE 's#.*\.hats/shared/([a-z0-9]+2[a-z0-9]+)/.*#\1#p')
if [ -n "$CHANNEL_DIR" ]; then
  if ! echo "$FILE_PATH" | grep -qE '\.md$'; then
    guard_block "entries in shared/${CHANNEL_DIR}/ must end .md"
  fi
  FILE_PATH="$(dirname "$(dirname "$FILE_PATH")")/${CHANNEL_DIR}.md"
fi

# 4b. Per-role blocked dirs and shared/ file restrictions
# Shared subdirectories: specs/ is owned by manager, designs/ is owned by designer
case "$ROLE" in
  manager)   BLOCKED=".hats/designer/ .hats/cto/ .hats/qa/ .hats/developer/"
             if echo "$FILE_PATH" | grep -q "\.hats/shared/"; then
               if echo "$FILE_PATH" | grep -q "\.hats/shared/specs/"; then
                 :  # manager owns shared/specs/
               elif echo "$FILE_PATH" | grep -q "\.hats/shared/designs/"; then
                 guard_block "Manager cannot write to shared/designs/ (owned by Designer)"
               else
                 BASENAME=$(basename "$FILE_PATH")
                 case "$BASENAME" in
                   manager2team.md) ;;  # allowed
                   *) guard_block "Manager can only write to shared/specs/ and shared/manager2team.md" ;;
                 esac
               fi
             fi ;;
  designer)  BLOCKED=".hats/manager/ .hats/cto/ .hats/qa/ .hats/developer/"
             if echo "$FILE_PATH" | grep -q "\.hats/shared/"; then
               if echo "$FILE_PATH" | grep -q "\.hats/shared/designs/"; then
                 :  # designer owns shared/designs/
               elif echo "$FILE_PATH" | grep -q "\.hats/shared/specs/"; then
                 guard_block "Designer cannot write to shared/specs/ (owned by Manager)"
               else
                 BASENAME=$(basename "$FILE_PATH")
                 case "$BASENAME" in
                   designer2team.md) ;;  # allowed
                   *) guard_block "Designer can only write to shared/designs/ and shared/designer2team.md" ;;
                 esac
               fi
             fi ;;
  cto)       BLOCKED=".hats/manager/ .hats/designer/ .hats/qa/ .hats/developer/"
             if echo "$FILE_PATH" | grep -q "\.hats/shared/"; then
               if echo "$FILE_PATH" | grep -q "\.hats/shared/specs/\|\.hats/shared/designs/"; then
                 guard_block "CTO cannot write to shared/specs/ or shared/designs/"
               else
                 BASENAME=$(basename "$FILE_PATH")
                 case "$BASENAME" in
                   stack.md|setup.md|api.md|cto2team.md) ;;  # allowed
                   *) guard_block "CTO can only write stack.md, setup.md, api.md, cto2team.md in .hats/shared/" ;;
                 esac
               fi
             fi ;;
  qa)        BLOCKED=".hats/manager/ .hats/designer/ .hats/cto/ .hats/developer/"
             if echo "$FILE_PATH" | grep -q "\.hats/shared/"; then
               if echo "$FILE_PATH" | grep -q "\.hats/shared/specs/\|\.hats/shared/designs/"; then
                 guard_block "QA cannot write to shared/specs/ or shared/designs/"
               else
                 BASENAME=$(basename "$FILE_PATH")
                 case "$BASENAME" in
                   qa-report.md|qa2dev.md|qa2designer.md|test-contract.md) ;;  # allowed
                   *) guard_block "QA can only write qa-report.md, qa2dev.md, qa2designer.md, test-contract.md in .hats/shared/" ;;
                 esac
               fi
             fi ;;
  developer) BLOCKED=".hats/manager/ .hats/designer/ .hats/cto/ .hats/qa/"
             if echo "$FILE_PATH" | grep -q "\.hats/shared/"; then
               if echo "$FILE_PATH" | grep -q "\.hats/shared/specs/\|\.hats/shared/designs/"; then
                 guard_block "Developer cannot write to shared/specs/ or shared/designs/"
               else
                 BASENAME=$(basename "$FILE_PATH")
                 case "$BASENAME" in
                   setup.md|api.md|dev2qa.md|dev2designer.md) ;;  # allowed
                   *) guard_block "Developer can only write setup.md, api.md, dev2qa.md, dev2designer.md in .hats/shared/" ;;
                 esac
               fi
             fi ;;
  *) exit 0 ;;
esac

# The directory ITSELF must match, not only paths inside it. `$BLOCKED` entries
# carry a trailing slash, so the old `grep "/${blocked}"` missed a path that
# ends at the directory — and Grep/Glob are handed exactly that shape. The
# fence looked closed and had a gap the width of one character.
for blocked in $BLOCKED; do
  b=$(echo "${blocked%/}" | sed 's/\./\\./g')
  if echo "$FILE_PATH" | grep -qE "(^|/)${b}(/|$)"; then
    guard_block "${ROLE} cannot write to ${blocked}"
  fi
done

exit 0
