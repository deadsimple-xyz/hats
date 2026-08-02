#!/bin/bash
# scripts/channel.sh — a channel becomes a directory of entries.
#
# The migration touches every project's history at once, so the row that
# matters most is not «does it produce nice files» but «did it lose a byte».
# Everything else here is downstream of that.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
CH="bash $HATS_ROOT/scripts/channel.sh"

echo "channel.sh — one entry, one file"

# A channel in the shape the projects actually write, including the three
# variants seen in the wild and a prose heading that must NOT split an entry.
mk_channel() {
  cat > "$1" <<'EOF'
# QA → Dev

## [1] 2026-07-15T12:05 -- QA
First entry.

## Findings
This heading is prose. It belongs to entry 1.

## [2] 2026-07-16 -- QA
Second entry, dated without a time.

## 3 2026-07-17T09:00 -- Developer
Third entry, no brackets.
EOF
}

# ── losslessness, the row the whole migration rests on ────────────────────────
SRC="$WORK/qa2dev.md"; mk_channel "$SRC"
cp "$SRC" "$WORK/original.md"
$CH split "$SRC" >/dev/null
assert_true "the original is kept as ARCHIVE.md" test -f "$WORK/qa2dev/ARCHIVE.md"
assert_true "ARCHIVE.md is byte-identical to what was there" \
  cmp -s "$WORK/qa2dev/ARCHIVE.md" "$WORK/original.md"
cat "$WORK/qa2dev/HEAD.md" "$WORK"/qa2dev/[0-9]*.md > "$WORK/rebuilt.md"
assert_true "entries concatenate back to the original, byte for byte" \
  cmp -s "$WORK/rebuilt.md" "$WORK/original.md"

# ── it splits on entries, not on every heading ────────────────────────────────
assert_eq "three entries, not four" "$(ls "$WORK"/qa2dev/[0-9]*.md | wc -l | tr -d ' ')" "3"
assert_true "a prose heading stays inside its entry" \
  grep -q "This heading is prose" "$WORK/qa2dev/0001-2026-07-15-qa.md"
assert_true "the dateless-time variant is an entry" test -f "$WORK/qa2dev/0002-2026-07-16-qa.md"
assert_true "the bracketless variant is an entry" test -f "$WORK/qa2dev/0003-2026-07-17-developer.md"

# ── the index is the thing a role reads ───────────────────────────────────────
IDX="$WORK/qa2dev/INDEX.md"
assert_true "an index is written" test -f "$IDX"
assert_true "newest is first — that was the whole problem" \
  grep -q -m1 "0003-2026-07-17-developer.md" <(head -6 "$IDX")
assert_true "each line carries something from the body" grep -q "Third entry" "$IDX"
# ── the guard against a half-done migration ───────────────────────────────────
mk_channel "$WORK/again.md"; mkdir -p "$WORK/again"
out=$($CH split "$WORK/again.md" 2>&1) && code=0 || code=$?
assert_eq "splitting onto an existing directory refuses" "$code" "1"
assert_true "and says why" grep -q "already exists" <<<"$out"

# ── an empty channel is an ordinary state, not a crash ────────────────────────
# Found on four projects at once: `grand-cto/qa2dev.md` is 0 bytes. The first
# version of this script died on exactly the projects with least to lose.
: > "$WORK/empty.md"
$CH split "$WORK/empty.md" >/dev/null 2>&1
assert_true "a zero-byte channel migrates" test -d "$WORK/empty"
assert_true "and its index says so plainly" grep -q "no entries yet" "$WORK/empty/INDEX.md"

# ── append: the write path roles will use ─────────────────────────────────────
NEW=$(echo "Runner is green." | $CH append "$WORK/qa2dev" QA)
assert_true "append writes a new file" test -f "$NEW"
assert_eq "numbered after the last one" "$(basename "$NEW" | cut -c1-4)" "0004"
assert_true "the entry carries a well-formed header" \
  grep -qE '^## \[4\] [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2} -- QA$' "$NEW"
assert_true "the body is the entry" grep -q "Runner is green." "$NEW"
assert_true "the index picks it up without being asked" grep -q "$(basename "$NEW")" "$IDX"

# ── appending to a channel that has never been used ───────────────────────────
NEW2=$(echo "First ever." | $CH append "$WORK/fresh" CTO)
assert_eq "the first entry of a fresh channel is 0001" "$(basename "$NEW2" | cut -c1-4)" "0001"
assert_true "and it is numbered [1]" grep -q '^## \[1\]' "$NEW2"

# THE property, stated correctly. My first attempt asserted «the index is
# smaller than the channel», which is false for a three-entry toy and told me
# nothing about the case that matters. What actually holds — and what makes the
# whole design work — is that the index grows with the NUMBER of entries and
# not with their SIZE. A megabyte entry must cost the index one line.
IDX_BEFORE=$(wc -c < "$IDX")
head -c 50000 /dev/zero | tr '\0' 'x' | $CH append "$WORK/qa2dev" QA >/dev/null
IDX_AFTER=$(wc -c < "$IDX")
assert_true "a 50 KB entry costs the index under 300 bytes" \
  test "$((IDX_AFTER - IDX_BEFORE))" -lt 300

# ── the real corpus, not a fixture ────────────────────────────────────────────
# The fixture above proves the shapes. This proves the shapes are the ones the
# projects actually contain — six of them, every channel, every age.
REAL=0; MIGRATED=0
for p in number_one design-gpt crust dead_tablet grand-cto pan-on-pen; do
  for c in qa2dev dev2qa manager2team cto2team designer2team qa2designer dev2designer; do
    src="$HOME/Code/$p/.hats/shared/$c.md"
    [ -f "$src" ] || continue
    REAL=$((REAL + 1))
    rm -rf "$WORK/real"; mkdir -p "$WORK/real"; cp "$src" "$WORK/real/$c.md"
    $CH split "$WORK/real/$c.md" >/dev/null 2>&1 || continue
    cat "$WORK/real/$c/HEAD.md" "$WORK/real/$c"/[0-9]*.md > "$WORK/real/rebuilt" 2>/dev/null
    cmp -s "$WORK/real/rebuilt" "$src" && MIGRATED=$((MIGRATED + 1))
  done
done
if [ "$REAL" -gt 0 ]; then
  assert_eq "every live channel migrates byte-for-byte ($REAL found)" "$MIGRATED" "$REAL"
else
  echo "  --   no live projects on this machine; corpus row skipped"
fi

summary
