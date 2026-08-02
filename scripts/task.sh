#!/bin/bash
# Tasks as folders in git.
#
# ── WHY ──────────────────────────────────────────────────────────────────────
# hats has specs — what must be TRUE — and nothing at all for what somebody is
# DOING. Six live projects, none of them can answer «what is in flight right
# now, and what was closed yesterday and why» from the repository. The one
# project that grew a task ledger kept it in session state, so it lived exactly
# as long as the session did.
#
# A task is a folder. It is in git. It survives everything.
#
#   .hats/tasks/0042-runner-flaky-login/
#     task.md            header + the ask
#     understanding.md   written when it goes into work
#     resolution.md      written when it closes
#   .hats/tasks/INDEX.md generated
#
# ── THE THREE GATES ──────────────────────────────────────────────────────────
# Enforced in the guard, not requested in a prompt:
#
#   open -> done            refused. A task that was never in work was never
#                           understood, and «done» about it means nothing.
#   -> in_progress          refused without understanding.md. Say what you
#                           think the job is BEFORE doing it; that is the only
#                           moment the sentence is worth anything.
#   -> done                 refused without resolution.md. What was checked,
#                           what the conclusion was.
#
# All three come from number_one, where they fire on real attempts — including
# three in one day where a role sent the wrong field.
set -eu
shopt -s nullglob

TASKS=".hats/tasks"
die() { echo "task: $1" >&2; exit 1; }

field() { sed -nE "s/^$2:[[:space:]]*(.*)$/\\1/p" "$1" | head -1; }

# A folder name a human can read at a glance.
#
# NOT ASCII-only. The first version stripped every non-Latin byte, so a Russian
# title produced an EMPTY slug and eleven tasks came out as `0001-`, `0002-`,
# `0003-100`. For anyone not writing in English that is not an edge case, it is
# every task they will ever file. git, macOS and Linux all carry UTF-8
# filenames without complaint.
#
# `tr` is byte-oriented and would cut a multi-byte letter in half, so the
# character classes are left to `sed` under a UTF-8 locale.
slug() {
  LC_ALL=${LC_ALL:-en_US.UTF-8} echo "$1" \
    | sed -E 's/[^[:alnum:]]+/-/g; s/^-+//; s/-+$//' \
    | sed -E 's/^(.{1,40}).*/\1/; s/-+$//' \
    | tr '[:upper:]' '[:lower:]'
}

cmd_new() {
  local title="$1" priority="${2:-3}" owner="${3:-unassigned}" spec="${4:-}"
  mkdir -p "$TASKS"
  local n=1 d
  for d in "$TASKS"/[0-9]*/; do n=$((n + 1)); done
  local id; id=$(printf '%04d-%s' "$n" "$(slug "$title")")
  local dir="$TASKS/$id"
  [ -e "$dir" ] && die "$dir already exists"
  mkdir -p "$dir"
  cat > "$dir/task.md" <<EOF
status: open
priority: $priority
owner: $owner
spec: $spec

# $title

_(what needs doing, in the words of whoever asked for it)_
EOF
  cmd_index
  echo "$dir"
}

# Status changes go through here so the three gates are in one place and the
# guard can check the same file the same way.
cmd_status() {
  local dir="$1" want="$2"
  [ -f "$dir/task.md" ] || die "no task at $dir"
  local now; now=$(field "$dir/task.md" status)
  case "$want" in open|in_progress|blocked|done) ;; *) die "unknown status: $want" ;; esac

  if [ "$now" = "open" ] && [ "$want" = "done" ]; then
    die "open -> done is refused: a task closes only after being in work. Set it to in_progress, write understanding.md, then close it with resolution.md."
  fi
  if [ "$want" = "in_progress" ] && [ ! -s "$dir/understanding.md" ]; then
    die "in_progress needs $dir/understanding.md: say what you think the job is, in your own words, BEFORE doing it."
  fi
  if [ "$want" = "done" ] && [ ! -s "$dir/resolution.md" ]; then
    die "done needs $dir/resolution.md: what you checked, and what you concluded."
  fi

  local tmp; tmp=$(mktemp)
  sed -E "1,10s/^status:.*/status: $want/" "$dir/task.md" > "$tmp"
  mv "$tmp" "$dir/task.md"
  cmd_index
  echo "$dir: $now -> $want"
}

# The queue: by priority, oldest first inside a priority. The rule the human
# asked for — when a session is running, take them one after another; when they
# asked for one specific thing, do that and then ASK about the rest.
cmd_next() {
  local best="" bp=99 d st pr
  for d in "$TASKS"/[0-9]*/; do
    [ -f "$d/task.md" ] || continue
    st=$(field "$d/task.md" status)
    [ "$st" = "open" ] || [ "$st" = "in_progress" ] || continue
    pr=$(field "$d/task.md" priority); pr=${pr:-3}
    if [ "$pr" -lt "$bp" ]; then bp=$pr; best="$d"; fi
  done
  [ -n "$best" ] || { echo "(nothing open)"; return 0; }
  echo "${best%/}"
}

cmd_index() {
  mkdir -p "$TASKS"
  local tmp; tmp=$(mktemp)
  {
    echo "# Tasks"
    echo
    echo "| # | status | pri | owner | title | spec |"
    echo "|---|---|---|---|---|---|"
    local d st pr ow ti sp
    for d in "$TASKS"/[0-9]*/; do
      [ -f "$d/task.md" ] || continue
      st=$(field "$d/task.md" status); pr=$(field "$d/task.md" priority)
      ow=$(field "$d/task.md" owner);  sp=$(field "$d/task.md" spec)
      ti=$(grep -m1 '^# ' "$d/task.md" | sed 's/^# //')
      printf '| `%s` | %s | %s | %s | %s | %s |\n' \
        "$(basename "${d%/}")" "$st" "$pr" "$ow" "$ti" "${sp:-—}"
    done
  } > "$tmp"
  mv "$tmp" "$TASKS/INDEX.md"
}

case "${1:-}" in
  new)    shift; cmd_new "$@" ;;
  status) shift; cmd_status "$@" ;;
  next)   shift; cmd_next "$@" ;;
  index)  shift; cmd_index "$@" ;;
  *) die "usage: task.sh new <title> [priority] [owner] [spec] | status <dir> <status> | next | index" ;;
esac
