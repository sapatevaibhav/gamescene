#!/usr/bin/env bash
# Runs every headless test suite. Usage: tests/run.sh  (from the repo root)
set -u
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fail=0
for t in tests/test_*.gd; do
  echo "=== $t"
  if ! "$GODOT" --headless --path . --script "$t" 2>&1 | grep -v '^Godot Engine' ; then :; fi
  "$GODOT" --headless --path . --script "$t" >/dev/null 2>&1 || { echo "FAILED: $t"; fail=1; }
done
exit $fail
