#!/usr/bin/env bash
# Runs every headless test suite. Usage: tests/run.sh  (from anywhere)
# Prints each suite's time as it finishes, and the slowest ones at the end.
set -u
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fail=0
times=""
start_all=$(date +%s)
for t in tests/test_*.gd; do
  n=$(basename "$t" .gd)
  echo "=== $n"
  s=$(date +%s.%N)
  "$GODOT" --headless --path . res://tests/runner.tscn -- "$n" 2>&1 | grep --line-buffered -vE '^(Godot Engine|\s*$)'
  [ "${PIPESTATUS[0]}" -eq 0 ] || { echo "FAILED: $n"; fail=1; }
  d=$(awk "BEGIN {printf \"%.1f\", $(date +%s.%N) - $s}")
  echo "--- $n: ${d}s"
  times+="$d $n"$'\n'
done
echo "=== all suites: $(( $(date +%s) - start_all ))s; slowest:"
printf "%s" "$times" | sort -rn | head -5 | sed 's/^/    /'
exit $fail
