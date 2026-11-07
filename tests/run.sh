#!/usr/bin/env bash
# Runs every headless test suite. Usage: tests/run.sh  (from anywhere)
set -u
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fail=0
for t in tests/test_*.gd; do
  n=$(basename "$t" .gd)
  echo "=== $n"
  "$GODOT" --headless --path . res://tests/runner.tscn -- "$n" 2>&1 | grep -vE '^(Godot Engine|\s*$)'
  [ "${PIPESTATUS[0]}" -eq 0 ] || { echo "FAILED: $n"; fail=1; }
done
exit $fail
