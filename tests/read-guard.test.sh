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

# ── the other half — CLOSED (was gap G1) ──────────────────────────────────────
#
# «the QA *can't* read source code» is the sentence the whole design rests on:
# QA writes tests from the SPEC, so it cannot inherit the implementation's
# blind spots. Until v5 the qa branch was `BLOCKED=""` — an empty list — and
# the promise was prose.
#
# It is an ALLOW-list rather than a block-list because «the implementation»
# has no fixed name. So the project root is closed to QA and a short list is
# opened; the refusal names it and names the escape hatch.
assert_read_block "qa cannot read source (the README's central claim)" qa \
  "{\"file_path\":\"$PROJECT/src/index.ts\"}" Read "writes tests from the SPEC"
assert_read_block "nor a deeply nested source file" qa \
  "{\"file_path\":\"$PROJECT/app/lib/internal/auth.ts\"}" Read "writes tests from the SPEC"
assert_read_block "nor by Grep across the project" qa \
  "{\"path\":\"$PROJECT/src\"}" Grep "writes tests from the SPEC"
assert_true "and the refusal says where to put what it needs" \
  grep -q "stack.md or setup.md" <<<"$GUARD_ERR"
assert_true "and how to widen it for this project" \
  grep -q "read-allow" <<<"$GUARD_ERR"

# The half that keeps this from being «block everything»: QA cannot write a
# single test without knowing the runner.
for f in package.json Package.swift requirements.txt go.mod Makefile \
         playwright.config.ts jest.config.js pytest.ini tsconfig.json README.md \
         docker-compose.yml .env.example; do
  assert_read_allow "qa may read $f" qa "{\"file_path\":\"$PROJECT/$f\"}" Read
done

# The escape hatch, because a fence with no gate gets torn down.
assert_read_block "a project fixture is closed by default" qa \
  "{\"file_path\":\"$PROJECT/fixtures/users.json\"}" Read "writes tests from the SPEC"
mkdir -p "$PROJECT/.hats/qa"
printf '# what this project QA legitimately needs\n*/fixtures/*\n' > "$PROJECT/.hats/qa/read-allow"
assert_read_allow "read-allow opens it, one glob per line" qa \
  "{\"file_path\":\"$PROJECT/fixtures/users.json\"}" Read
assert_read_block "and opens only what it lists" qa \
  "{\"file_path\":\"$PROJECT/src/index.ts\"}" Read "writes tests from the SPEC"
rm -f "$PROJECT/.hats/qa/read-allow"

# ── nobody else lost anything ────────────────────────────────────────────────
assert_read_allow "the developer still reads its own source" developer \
  "{\"file_path\":\"$PROJECT/src/index.ts\"}" Read
assert_read_allow "the cto still reads everything" cto \
  "{\"file_path\":\"$PROJECT/src/index.ts\"}" Read
assert_read_allow "the manager still reads source" manager \
  "{\"file_path\":\"$PROJECT/src/index.ts\"}" Read

# What QA legitimately reads, so the fix above cannot be «block everything».
assert_read_allow "qa reads the specs it tests against" qa \
  "{\"file_path\":\"$PROJECT/.hats/shared/specs/auth.feature\"}" Read
assert_read_allow "qa reads the stack it must target" qa \
  "{\"file_path\":\"$PROJECT/.hats/shared/stack.md\"}" Read
assert_read_allow "qa reads its own tests" qa \
  "{\"file_path\":\"$PROJECT/.hats/qa/steps/login.ts\"}" Read

summary
