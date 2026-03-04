#!/bin/bash
# Debug logger — logs all tool uses when .hats/debug exists.
# Always exits 0. Never interferes with tool execution.

[ -f ".hats/debug" ] || exit 0

INPUT=$(cat)

ROLE_FILE=".hats/role"
ROLE="none"
[ -f "$ROLE_FILE" ] && ROLE=$(cat "$ROLE_FILE")

LOG_DIR=".hats/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date -u +%Y-%m-%d).jsonl"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

case "$TOOL" in
  Bash)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    echo "{\"ts\":\"$TS\",\"role\":\"$ROLE\",\"tool\":\"Bash\",\"command\":$(echo "$CMD" | jq -Rs .)}" >> "$LOG_FILE"
    ;;
  Write|Edit)
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    echo "{\"ts\":\"$TS\",\"role\":\"$ROLE\",\"tool\":\"$TOOL\",\"file\":\"$FILE\"}" >> "$LOG_FILE"
    ;;
  Read)
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    echo "{\"ts\":\"$TS\",\"role\":\"$ROLE\",\"tool\":\"Read\",\"file\":\"$FILE\"}" >> "$LOG_FILE"
    ;;
  Glob)
    PAT=$(echo "$INPUT" | jq -r '.tool_input.pattern // empty')
    echo "{\"ts\":\"$TS\",\"role\":\"$ROLE\",\"tool\":\"Glob\",\"pattern\":\"$PAT\"}" >> "$LOG_FILE"
    ;;
  Grep)
    PAT=$(echo "$INPUT" | jq -r '.tool_input.pattern // empty')
    P=$(echo "$INPUT" | jq -r '.tool_input.path // empty')
    echo "{\"ts\":\"$TS\",\"role\":\"$ROLE\",\"tool\":\"Grep\",\"pattern\":\"$PAT\",\"path\":\"$P\"}" >> "$LOG_FILE"
    ;;
  Agent)
    DESC=$(echo "$INPUT" | jq -r '.tool_input.description // empty')
    echo "{\"ts\":\"$TS\",\"role\":\"$ROLE\",\"tool\":\"Agent\",\"description\":\"$DESC\"}" >> "$LOG_FILE"
    ;;
  *)
    echo "{\"ts\":\"$TS\",\"role\":\"$ROLE\",\"tool\":\"$TOOL\"}" >> "$LOG_FILE"
    ;;
esac

exit 0
