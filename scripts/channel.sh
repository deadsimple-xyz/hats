#!/bin/bash
# Channels as directories of entries, instead of one file that grows forever.
#
# ── WHY ──────────────────────────────────────────────────────────────────────
# Measured across six live projects. A channel is append-at-the-bottom, the
# role prompts say «NEVER use cat/head/tail», and `Read` returns the FIRST 2000
# lines. On design-gpt — a middling project, not a monster — `qa2dev.md` holds
# 15 entries spanning [40]..[51]; a role following the instruction sees 6 and
# stops at [42]. Nine entries out of fifteen are read by nobody, ever. It
# breaks at 138 KB, so it breaks for everyone past their second month.
#
# One entry, one file. Then the newest is reachable by Glob and readable whole,
# and the rule «do not tail» stops being harmful because there is nothing left
# to tail.
#
# ── SUBCOMMANDS ──────────────────────────────────────────────────────────────
#   split <channel.md>     one-time migration; lossless, verified
#   index <channel-dir>    regenerate INDEX.md
#   append <channel-dir> <role> [< body on stdin]
#
# No dependencies beyond coreutils. Everything is plain text on purpose: the
# whole point is that a human can read the directory without a tool.
set -eu
# A channel with no entries yet is an ordinary state — a fresh project, a
# channel nobody has used. Without this the `[0-9]*.md` globs stay literal and
# the migration dies on exactly the projects that have the least to lose.
shopt -s nullglob

# An entry header, as the channels actually write it across every project
# inspected: `## [131] 2026-07-15T12:05 -- QA`, and the older `## [139]
# 2026-07-16 -- QA` without a time, and design-gpt's `## 49 2026-07-10T14:00`
# without brackets. Deliberately requires a NUMBER AND A DATE, so ordinary
# prose headings inside an entry (`## Findings`) stay part of their entry —
# on number_one that distinction is 36 headings wide.
ENTRY_RE='^## \[?[0-9]+\]?[[:space:]]+[0-9]{4}-[0-9]{2}-[0-9]{2}'

die() { echo "channel: $1" >&2; exit 1; }

# ── split ────────────────────────────────────────────────────────────────────
# `shared/qa2dev.md` -> `shared/qa2dev/{0001-....md, INDEX.md, ARCHIVE.md}`
#
# Lossless by construction and then CHECKED: the entries are concatenated back
# and compared with the original. A migration that silently drops the tail of a
# channel would be worse than the problem it fixes.
cmd_split() {
  local src="$1"
  [ -f "$src" ] || die "no such file: $src"
  local dir="${src%.md}"
  [ -e "$dir" ] && die "$dir already exists — already migrated?"

  mkdir -p "$dir"
  local work; work=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$work'" RETURN

  # Everything before the first entry is the channel's own title block.
  awk -v re="$ENTRY_RE" '$0 ~ re {exit} {print}' "$src" > "$work/head.txt"

  # csplit would be shorter and is not portable enough; awk writing numbered
  # parts is boring and works the same everywhere.
  awk -v re="$ENTRY_RE" -v out="$work" '
    BEGIN { n = 0 }
    $0 ~ re { n++; f = sprintf("%s/%04d.part", out, n) }
    n > 0 { print > f }
  ' "$src"

  local count=0 name date role num
  for part in "$work"/*.part; do
    [ -f "$part" ] || continue
    count=$((count + 1))
    num=$(head -1 "$part" | sed -E 's/^## \[?([0-9]+)\]?.*/\1/')
    date=$(head -1 "$part" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
    role=$(head -1 "$part" | sed -E 's/.*-- *//' | tr '[:upper:] ' '[:lower:]-' \
           | tr -cd 'a-z0-9-' | cut -c1-16)
    [ -n "$role" ] || role="entry"
    # The POSITION, zero-padded, is the filename's spine — not the entry's own
    # number. Those numbers are not identities: on number_one's qa2dev, 246
    # entries carry 238 distinct numbers and the sequence goes DOWN 19 times.
    # Sorting by filename must reproduce the file's order, and only position
    # can promise that.
    name=$(printf '%04d-%s-%s.md' "$count" "${date:-nodate}" "$role")
    cp "$part" "$dir/$name"
  done

  cp "$work/head.txt" "$dir/HEAD.md"

  # THE CHECK. Rebuild and compare with the original, byte for byte.
  { cat "$dir/HEAD.md"; for f in "$dir"/[0-9]*.md; do cat "$f"; done; } > "$work/rebuilt.txt"
  # (with no entries this is HEAD.md alone, which is exactly the whole file)
  if ! cmp -s "$work/rebuilt.txt" "$src"; then
    rm -rf "$dir"
    die "split would have lost or changed bytes in $src — nothing was written"
  fi

  mv "$src" "$dir/ARCHIVE.md"
  cmd_index "$dir"
  echo "channel: $src -> $dir/ ($count entries, original kept as ARCHIVE.md)"
}

# ── index ────────────────────────────────────────────────────────────────────
# NEWEST FIRST, because the reason this exists is that the newest was the part
# nobody could reach.
cmd_index() {
  local dir="$1"
  [ -d "$dir" ] || die "no such directory: $dir"
  local out="$dir/INDEX.md" tmp; tmp=$(mktemp)
  {
    echo "# $(basename "$dir") — newest first"
    echo
    echo "One entry per file. Read this index, then only the entries you need."
    echo
    local f entries=()
    for f in "$dir"/[0-9]*.md; do entries=("$f" "${entries[@]+${entries[@]}}"); done
    if [ "${#entries[@]}" -eq 0 ]; then
      echo "_(no entries yet)_"
    fi
    for f in ${entries[@]+"${entries[@]}"}; do
      local hdr first
      hdr=$(head -1 "$f")
      # The first line of the body that says something — the index is useless
      # if every line reads «## [143] 2026-07-30 -- QA».
      first=$(sed -n '2,$p' "$f" | grep -m1 -vE '^[[:space:]]*$' | cut -c1-90)
      printf -- '- `%s` %s\n  %s\n' "$(basename "$f")" "${hdr#\#\# }" "$first"
    done
  } > "$tmp"
  mv "$tmp" "$out"
}

# ── append ───────────────────────────────────────────────────────────────────
cmd_append() {
  local dir="$1" role="${2:-entry}"
  mkdir -p "$dir"
  local last="" count num all=()
  for f in "$dir"/[0-9]*.md; do all+=("$f"); done
  count=$(( ${#all[@]} + 1 ))
  # bash 3.2 (the one macOS ships) errors on `all[-1]` for an empty array
  # rather than yielding nothing, so the emptiness is checked, not indexed.
  [ "${#all[@]}" -gt 0 ] && last="${all[${#all[@]}-1]}"
  if [ -n "$last" ]; then
    num=$(head -1 "$last" | sed -E 's/^## \[?([0-9]+)\]?.*/\1/')
    num=$((num + 1))
  else
    num=1
  fi
  local date name
  date=$(date -u +%Y-%m-%dT%H:%M)
  name=$(printf '%04d-%s-%s.md' "$count" "${date%%T*}" \
         "$(echo "$role" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')")
  {
    printf '## [%s] %s -- %s\n\n' "$num" "$date" "$role"
    cat
  } > "$dir/$name"
  cmd_index "$dir"
  echo "$dir/$name"
}

case "${1:-}" in
  split)  shift; cmd_split "$@" ;;
  index)  shift; cmd_index "$@" ;;
  append) shift; cmd_append "$@" ;;
  *) die "usage: channel.sh split <file.md> | index <dir> | append <dir> <role>" ;;
esac
