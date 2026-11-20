#!/usr/bin/env bash
# Build + export the place for the Studio workbench.  usage: tools/studio_prepare.sh
# Produces out/studio/{manifest.json,chunk_*.json}. Copy that folder's files into
# ~/code/roblox-pipeline-builds/studio/ on the Mac, then run tools/studio/sync_snippet.luau
# in Studio (execute_luau, Edit). It installs the current loader and syncs.
set -euo pipefail
cd "$(dirname "$0")/.."
LUNE="${LUNE:-lune}"
"$LUNE" run build/main.luau
"$LUNE" run tools/studio_export.luau out/studio
cp tools/studio/PipelineSync.luau out/studio/PipelineSync.luau
cp tools/studio/ui_audit.luau out/studio/ui_audit.luau
ls -1 out/studio
