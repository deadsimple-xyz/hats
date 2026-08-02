#!/bin/bash
# Run every hats test. One command, no framework to install.
#
#   bash tests/run.sh
#
# Exit 0 only if every file passed. Known gaps (tests/KNOWN-GAPS.md) are shown
# on every run but do not fail it; a gap that starts passing DOES fail it.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v jq >/dev/null; then
  echo "jq is required (the guards themselves use it)"; exit 1
fi

FAILED=0
for t in tests/*.test.sh; do
  echo
  bash "$t" || FAILED=1
done

echo
if [ "$FAILED" -eq 0 ]; then
  echo "ALL GREEN"
else
  echo "SOMETHING IS RED"
fi
exit "$FAILED"
