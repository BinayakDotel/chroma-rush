#!/usr/bin/env bash
# Exports the web build and zips it for upload to a game portal.
#   tools/build_web.sh
# Writes:
#   build/web/                         the exported game (index.html and 8 more files)
#   build/upload/chroma-rush-web.zip   the same files, zipped, with index.html at the top level
# Requires Godot 4.7 with the web export templates (set GODOT if it is not on PATH).
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/web"
ZIP="$ROOT/build/upload/chroma-rush-web.zip"

rm -rf "$OUT"
mkdir -p "$OUT" "$(dirname "$ZIP")"
touch "$ROOT/build/.gdignore" # keeps Godot from importing build output
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$OUT/index.html"

rm -f "$ZIP"
(cd "$OUT" && zip -q -9 -r "$ZIP" . -x ".*")

echo "Build:  $OUT ($(find "$OUT" -type f | wc -l | tr -d ' ') files)"
echo "Upload: $ZIP ($(du -h "$ZIP" | cut -f1 | tr -d " "))"
