#!/bin/bash
# scripts/read-guard.sh — the half of the fence the README sells hardest.
#
# README, verbatim: «Permissions are enforced by hooks -- the Developer
# literally *can't* read tests, and the QA *can't* read source code.»
# That sentence is the product. These rows check both halves of it.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PROJECT=$(make_project)
trap 'rm -rf "$PROJECT"' EXIT

echo "read-guard.sh — the fence around reads"

# ── no role: stand aside ──────────────────────────────────────────────────────
rm -f "$PROJECT/.hats/role"
out=$(cd "$PROJECT" && echo '{"tool_name":"Read","tool_input":{"file_path":"src/x.ts"}}' \
      | bash "$HATS_ROOT/scripts/read-guard.sh" 2>&1); code=$?
assert_eq "no .hats/role -> permissive" "$code" "0"

# ── the developer cannot see the tests. This half works. ──────────────────────
assert_read_block "developer cannot Read a test file"  developer \
  "{\"file_path\":\"$PROJECT/.hats/qa/steps/login.ts\"}" Read "cannot read .hats/qa/"
assert_read_block "developer cannot Grep the qa dir"   developer \
  "{\"path\":\"$PROJECT/.hats/qa\"}" Grep "cannot read .hats/qa/"
assert_read_block "developer cannot Glob the qa dir"   developer \
  "{\"pattern\":\"$PROJECT/.hats/qa/**\"}" Glob "cannot read .hats/qa/"
assert_read_allow "developer reads the qa REPORT (its only window)" developer \
  "{\"file_path\":\"$PROJECT/.hats/shared/qa-report.md\"}" Read
assert_read_allow "developer reads its own source" developer \
  "{\"file_path\":\"$PROJECT/src/index.ts\"}" Read

assert_read_block "manager cannot read the qa dir"     manager \
  "{\"file_path\":\"$PROJECT/.hats/qa/steps/login.ts\"}" Read "cannot read .hats/qa/"
assert_read_block "designer cannot read the qa dir"    designer \
  "{\"file_path\":\"$PROJECT/.hats/qa/steps/login.ts\"}" Read "cannot read .hats/qa/"

# ── the other half. THIS IS THE ROW THAT MATTERS. ─────────────────────────────
#
# «the QA *can't* read source code» is the sentence the whole design rests on:
# QA writes tests from the SPEC, so it cannot inherit the implementation's
# blind spots. In 4.4.0 the qa branch of read-guard.sh is `BLOCKED=""` — an
# empty list. QA can read every line of `src/`.
#
# So the guarantee is prose, not a mechanism. This row states what the README
# promises and is registered as KNOWN GAP G1: it does not fail the suite, it
# shows up in every run as an unpaid debt — and it WILL fail the suite the day
# it starts passing, so nobody can close it and forget to say so.
gap G1 assert_read_block "qa cannot read source (README's central claim)" qa \
  "{\"file_path\":\"$PROJECT/src/index.ts\"}" Read "cannot read"

# What QA legitimately reads, so the fix above cannot be «block everything».
assert_read_allow "qa reads the specs it tests against" qa \
  "{\"file_path\":\"$PROJECT/.hats/shared/specs/auth.feature\"}" Read
assert_read_allow "qa reads the stack it must target" qa \
  "{\"file_path\":\"$PROJECT/.hats/shared/stack.md\"}" Read
assert_read_allow "qa reads its own tests" qa \
  "{\"file_path\":\"$PROJECT/.hats/qa/steps/login.ts\"}" Read

summary
