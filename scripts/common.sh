#!/bin/bash
# Shared helpers for Hats hook scripts.
# Sourced by debug-log.sh, guard.sh, read-guard.sh.

# Hats plugin version (from plugin.json relative to this script).
hats_version() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  jq -r .version "$script_dir/../.claude-plugin/plugin.json" 2>/dev/null || echo "unknown"
}

# Active host model — best effort.
# Resolution order:
#   1. .hats/model file (manual override)
#   2. hook input's model field (Codex supplies this directly)
#   3. transcript_path's most recent "model" field
#   4. CLAUDE_MODEL / ANTHROPIC_MODEL env vars
#   5. "unknown"
# Args: the hook's stdin JSON (so we can read transcript_path).
hats_model() {
  local input="$1"
  if [ -f ".hats/model" ]; then
    cat .hats/model
    return
  fi
  local hook_model
  hook_model=$(echo "$input" | jq -r '.model // empty' 2>/dev/null)
  if [ -n "$hook_model" ]; then
    echo "$hook_model"
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

# ── the role, and where it is allowed to come from ───────────────────────────
#
# G2/G3 (tests/KNOWN-GAPS.md). `.hats/role` is a plain file, per-DIRECTORY and
# writable by the very agent it fences. Two consequences, both demonstrated by
# rows in tests/role-store.test.sh: two sessions in one repo shared one fence,
# and any role could take its own fence off in a single write.
#
# Resolution order, strongest first:
#
#   1. HATS_ROLE in the environment — a process cannot rewrite the env its
#      parent handed it, so this is the only rung genuinely out of reach of the
#      thing being fenced. Use it wherever the fence must be real: autopilot,
#      spawned per-role sessions, CI.
#   2. .hats/sessions/<session_id> — this session's own position, recorded by
#      the guard when it sees the role file being written. Two sessions in one
#      repo no longer share a fence.
#   3. .hats/role — the legacy file, still the thing skills write and the thing
#      a human edits by hand.
#
# Between 2 and 3 the question is NOT «which file is newer». That was the first
# answer and it was wrong twice over: every switch by any session also rewrites
# `.hats/role` (Claude Code performs the write, the guard only permits it), so
# newest-wins handed the fence back to whoever switched last — the exact bug it
# was meant to fix. And it turned the rule into a race against filesystem
# timestamp granularity, which a falsification caught: the row meant to exercise
# the tie-breaker never reached it, because both writes landed in the same
# second.
#
# CONTENT decides, and it decides deterministically:
#
#   * `.hats/role` holds what WE hold        -> nothing happened; ours.
#   * it holds what ANOTHER session holds    -> that session switched itself.
#                                               Ours stands. This is G3.
#   * it holds a value no session claims     -> a human wrote it by hand
#                                               (`echo cto > .hats/role` in a
#                                               Bash call never reaches the
#                                               Write/Edit hook). Theirs wins,
#                                               or hand-editing silently dies.
#
# The one ambiguity left is a human hand-writing exactly the value some other
# session already holds; we keep ours. No rule can tell those apart, and
# timestamps could not either.
hats_session_id() {
  echo "$1" | jq -r '.session_id // empty' 2>/dev/null
}

hats_role() {
  local input="$1"
  if [ -n "${HATS_ROLE:-}" ]; then
    echo "$HATS_ROLE"
    return
  fi
  local sid sess mine shared other
  sid=$(hats_session_id "$input")
  sess=".hats/sessions/$sid"
  if [ -n "$sid" ] && [ -f "$sess" ]; then
    mine=$(cat "$sess")
    if [ ! -f ".hats/role" ]; then
      echo "$mine"; return
    fi
    shared=$(cat .hats/role)
    if [ "$shared" = "$mine" ]; then
      echo "$mine"; return
    fi
    for other in .hats/sessions/*; do
      [ -f "$other" ] || continue
      [ "$other" = "$sess" ] && continue
      if [ "$(cat "$other")" = "$shared" ]; then
        echo "$mine"; return           # another session switched — ours stands
      fi
    done
    # nobody claims that value: a hand edit, and it wins.
  fi
  [ -f ".hats/role" ] && cat ".hats/role"
}

# Record a switch: this session's own position, plus one audit line.
#
# The audit is NOT behind the debug flag. A record of who took which fence off
# and when is the thing you want precisely on the day nobody thought to turn
# logging on, and one line per switch costs nothing.
hats_record_role() {
  local input="$1" new_role="$2" from="$3"
  local sid; sid=$(hats_session_id "$input")
  [ -n "$sid" ] || return 0
  mkdir -p ".hats/sessions"
  printf '%s' "$new_role" > ".hats/sessions/$sid"
  printf '%s %s %s -> %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${sid:0:8}" \
    "${from:-none}" "$new_role" >> ".hats/role-history"
}
