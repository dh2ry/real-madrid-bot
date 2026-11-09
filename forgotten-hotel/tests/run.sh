#!/bin/bash
# Runs the headless integration tests with the stand-alone Luau CLI.
# Requires `luau` (https://github.com/luau-lang/luau/releases) on PATH or in $LUAU.
set -e
cd "$(dirname "$0")/.."
LUAU=${LUAU:-luau}
TMP=$(mktemp -d)
for scenario in tests/scenario_server.luau tests/scenario_client.luau; do
  echo "== $scenario"
  python3 tests/bundle.py "$scenario" > "$TMP/run.luau"
  (cd "$TMP" && "$LUAU" run.luau) | tee "$TMP/out.txt" | grep -E "FAIL|ERROR|RESULT"
  grep -q "RESULT: 0 failed checks, 0 runtime errors" "$TMP/out.txt"
done
rm -rf "$TMP"
