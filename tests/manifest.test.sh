#!/bin/bash
# The manifest, the hooks, and the wiring between them.
#
# WHY THIS FILE EXISTS, from the plugin's own history:
#
#   v4.3.1  drop redundant hooks declaration from plugin.json
#   v4.3.2  declare skills field correctly + sync marketplace version
#   v4.3.3  restore hooks declaration in plugin.json      <- undid 4.3.1
#   v4.3.4  align with current Claude Code plugin spec
#   v4.3.5  restore commands->skills aliasing              <- undid another
#
# Five releases in a row repairing the previous one, twice by literally putting
# back what had just been removed. Not carelessness — nothing checked that the
# plugin still loads. These rows are that check.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$HATS_ROOT"
echo "manifest — does this thing still load"

# ── every JSON we ship must parse. A broken manifest is a silent no-op. ───────
for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json settings.json; do
  assert_true "$f parses" jq -e . "$f"
done

PLUGIN_V=$(jq -r '.version' .claude-plugin/plugin.json)
MARKET_V=$(jq -r '.plugins[] | select(.name=="hats") | .version' .claude-plugin/marketplace.json)
assert_eq "plugin.json and marketplace.json agree on the version" "$MARKET_V" "$PLUGIN_V"

assert_eq "plugin name matches the marketplace entry" \
  "$(jq -r '.name' .claude-plugin/plugin.json)" \
  "$(jq -r '.plugins[] | select(.name=="hats") | .name' .claude-plugin/marketplace.json)"

# ── every hook command must exist and be runnable ─────────────────────────────
# The failure this catches is the ugliest kind: the hook is declared, Claude
# Code calls it, the path is wrong, and the guard silently never fires. The
# fence looks present and is not there.
while read -r cmd; do
  rel="${cmd/\$\{CLAUDE_PLUGIN_ROOT\}\//}"
  assert_true "hook target exists: $rel" test -f "$rel"
  assert_true "hook target is executable: $rel" test -x "$rel"
  assert_true "hook target is valid bash: $rel" bash -n "$rel"
done < <(jq -r '.hooks.PreToolUse[].hooks[].command' hooks/hooks.json)

# ── the three guards are actually wired, each to its own tools ────────────────
MATCHERS=$(jq -r '.hooks.PreToolUse[] | "\(.matcher) \(.hooks[].command)"' hooks/hooks.json)
assert_true "Write|Edit is guarded"  grep -q "Write|Edit.*guard.sh"     <<<"$MATCHERS"
assert_true "Read|Glob|Grep is guarded" grep -q "Read|Glob|Grep.*read-guard.sh" <<<"$MATCHERS"

# ── every role named in the README has a prompt and a skill ──────────────────
for role in manager designer cto qa developer; do
  assert_true "agents/$role.md exists"      test -f "agents/$role.md"
  assert_true "skills/$role/SKILL.md exists" test -f "skills/$role/SKILL.md"
done

# ── every skill declares itself, or the slash command does not appear ────────
for s in skills/*/SKILL.md; do
  name=$(sed -n 's/^name: *//p' "$s" | head -1)
  assert_eq "$(dirname "$s") declares a matching name" "$name" "$(basename "$(dirname "$s")")"
done

# ── shell we ship must at least be syntactically sound ───────────────────────
for s in scripts/*.sh; do
  assert_true "$s is valid bash" bash -n "$s"
done

summary
