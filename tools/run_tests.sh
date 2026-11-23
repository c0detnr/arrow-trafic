#!/usr/bin/env bash
# Runs every Godot and Python test suite. Fails on a non-zero exit, a missing
# "<suite>: OK" line or any SCRIPT ERROR (failed asserts don't set the exit code).
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
for t in tests/test_*.gd; do
  name=$(basename "$t" .gd)
  log=$(XDG_DATA_HOME=$(mktemp -d) godot --headless --script "$t" 2>&1); code=$?
  if [ $code -ne 0 ] || ! grep -q "^$name: OK" <<<"$log" || grep -q "SCRIPT ERROR" <<<"$log"; then
    echo "FAIL $name (exit $code)"; grep -E "SCRIPT ERROR|FAIL|at:" <<<"$log" | head -20; fail=1
  else
    echo "ok   $name"
  fi
done
python3 -m unittest discover -s tools -p 'test_*.py' >/dev/null 2>&1 && echo "ok   tools (python)" || { echo "FAIL tools (python)"; fail=1; }
exit $fail
