#!/usr/bin/env bash
# Exports a web build and zips it for upload to a game portal.
#   tools/build_web.sh              plain web build (no portal SDK)   -> build/web
#   tools/build_web.sh crazygames   CrazyGames build, with their SDK  -> build/crazygames
# Each also writes build/upload/chroma-rush-<target>.zip: the same files, zipped, with
# index.html at the top level.
# Requires Godot 4.7 (set GODOT if it is not on PATH) and the slim engine that
# tools/build_web_template.sh compiles.
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-web}"

case "$TARGET" in
	web) PRESET="Web" ;;
	crazygames) PRESET="CrazyGames" ;;
	*) echo "Unknown target '$TARGET' (expected: web, crazygames)" >&2; exit 1 ;;
esac

# The web presets use the slim engine from tools/build_web_template.sh, not the stock one.
if [ ! -f "$ROOT/build/templates/web_nothreads_release.zip" ]; then
	echo "Missing build/templates/web_nothreads_release.zip: run tools/build_web_template.sh first" >&2
	exit 1
fi

OUT="$ROOT/build/$TARGET"
ZIP="$ROOT/build/upload/chroma-rush-$TARGET.zip"

rm -rf "$OUT"
mkdir -p "$OUT" "$(dirname "$ZIP")"
touch "$ROOT/build/.gdignore" # keeps Godot from importing build output
"$GODOT" --headless --path "$ROOT" --export-release "$PRESET" "$OUT/index.html"

rm -f "$ZIP"
(cd "$OUT" && zip -q -9 -r "$ZIP" . -x ".*")

echo "Build:  $OUT ($(find "$OUT" -type f | wc -l | tr -d ' ') files)"
echo "Upload: $ZIP ($(du -h "$ZIP" | cut -f1 | tr -d " "))"
