#!/bin/bash
# Shared helpers for Hats hook scripts.
# Sourced by debug-log.sh, guard.sh, read-guard.sh.

# Hats plugin version (from plugin.json relative to this script).
hats_version() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  jq -r .version "$script_dir/../.claude-plugin/plugin.json" 2>/dev/null || echo "unknown"
}

# Active Claude model — best effort.
# Resolution order:
#   1. .hats/model file (manual override)
#   2. transcript_path's most recent "model" field
#   3. CLAUDE_MODEL / ANTHROPIC_MODEL env vars
#   4. "unknown"
# Args: the hook's stdin JSON (so we can read transcript_path).
hats_model() {
  local input="$1"
  if [ -f ".hats/model" ]; then
    cat .hats/model
    return
  fi
  local transcript
  transcript=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
  if [ -n "$transcript" ] && [ -f "$transcript" ]; then
    local model
    model=$(tail -n 200 "$transcript" 2>/dev/null | grep -oE '"model":"[^"]+"' | tail -1 | cut -d'"' -f4)
    if [ -n "$model" ]; then
      echo "$model"
      return
    fi
  fi
  echo "${CLAUDE_MODEL:-${ANTHROPIC_MODEL:-unknown}}"
}
