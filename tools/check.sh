#!/usr/bin/env bash
# Build the place and run every offline check.   usage: tools/check.sh
# Tools from env or PATH: LUNE, LUAU_LSP; ROBLOX_DEFS = path to luau-lsp's globalTypes.d.luau
set -euo pipefail
cd "$(dirname "$0")/.."

LUNE="${LUNE:-lune}"
LUAU_LSP="${LUAU_LSP:-luau-lsp}"
ROBLOX_DEFS="${ROBLOX_DEFS:-tools/.cache/globalTypes.d.luau}"
step() { printf "\n\033[1;33m▶ %s\033[0m\n" "$1"; CURRENT="$1"; }
mkdir -p out
exec > >(tee out/check.log) 2>&1
on_fail() {
  # In CI, surface the failure as an annotation (readable from the API, unlike raw logs)
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    msg="$(tail -n 25 out/check.log | sed 's/\x1b\[[0-9;]*m//g' | sed ':a;N;$!ba;s/%/%25/g;s/\r/%0D/g;s/\n/%0A/g')"
    echo "::error title=check failed at: ${CURRENT:-setup}::${msg}"
  fi
}
trap on_fail ERR

step "Build place"
"$LUNE" run build/main.luau

step "Type-check scripts against the Roblox API"
if [ ! -f "$ROBLOX_DEFS" ]; then
  mkdir -p "$(dirname "$ROBLOX_DEFS")"
  curl -fsSL https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau -o "$ROBLOX_DEFS"
fi
FILES=()  # (no mapfile: macOS ships bash 3.2)
while IFS= read -r f; do FILES+=("$f"); done < <(find kit game/src tests/cloud -name '*.luau' 2>/dev/null | sort)
set +e
"$LUAU_LSP" analyze --platform=roblox --sourcemap=out/sourcemap.json \
  --definitions=@roblox="$ROBLOX_DEFS" --no-strict-dm-types "${FILES[@]}" > out/typecheck.txt 2>&1
set -e
if grep -E "TypeError|SyntaxError" out/typecheck.txt; then
  echo "type check FAILED (full output: out/typecheck.txt)"; false
fi
echo "type check passed ($(grep -cE "^[^[]" out/typecheck.txt || true) lint notes in out/typecheck.txt)"

step "Syntax-check the crash-test script as it runs in Roblox"
python3 tools/roblox_cloud.py render-test --out out/cloud_test.luau
set +e
"$LUAU_LSP" analyze --platform=roblox --definitions=@roblox="$ROBLOX_DEFS" out/cloud_test.luau > out/cloud_test.txt 2>&1
set -e
if grep -E "SyntaxError" out/cloud_test.txt; then
  echo "crash-test script does not parse (out/cloud_test.luau)"; false
fi
echo "crash-test script parses"

step "Validate property names against Roblox's reflection database"
python3 tools/props.py
"$LUNE" run tools/props.luau

step "Validate place structure and performance budget"
"$LUNE" run tools/validate.luau

printf "\n\033[1;32m✔ all offline checks passed\033[0m  →  %s\n" "$(python3 -c 'import json;print(json.load(open("pipeline.json")).get("placeFile","out/Game.rbxlx"))')"
