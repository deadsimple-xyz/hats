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

# Redact common secret shapes from a string before it lands in the JSONL.
# Reads stdin, writes stdout. Conservative — only patterns with a stable prefix.
redact_secrets() {
  sed -E \
    -e 's/figd_[A-Za-z0-9_-]{20,}/<REDACTED:figma>/g' \
    -e 's/sk-(ant-)?[A-Za-z0-9_-]{20,}/<REDACTED:sk>/g' \
    -e 's/gh[posur]_[A-Za-z0-9]{20,}/<REDACTED:github>/g' \
    -e 's/xox[pbasr]-[A-Za-z0-9-]{10,}/<REDACTED:slack>/g' \
    -e 's/AKIA[0-9A-Z]{16}/<REDACTED:aws-access-key>/g' \
    -e 's/(eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,})/<REDACTED:jwt>/g' \
    -e 's/[Bb]earer[[:space:]]+[A-Za-z0-9._\-]{20,}/Bearer <REDACTED>/g' \
    -e 's/(([Aa][Pp][Ii]_?[Kk][Ee][Yy]|[Tt][Oo][Kk][Ee][Nn]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd])[[:space:]]*[=:][[:space:]]*)([^[:space:]"'\'']{8,})/\1<REDACTED>/g'
}

case "$TOOL" in
  Bash)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' | redact_secrets)
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
    DESC=$(echo "$INPUT" | jq -r '.tool_input.description // empty' | redact_secrets)
    echo "{\"ts\":\"$TS\",\"role\":\"$ROLE\",\"tool\":\"Agent\",\"description\":$(echo "$DESC" | jq -Rs .)}" >> "$LOG_FILE"
    ;;
  *)
    echo "{\"ts\":\"$TS\",\"role\":\"$ROLE\",\"tool\":\"$TOOL\"}" >> "$LOG_FILE"
    ;;
esac

exit 0
