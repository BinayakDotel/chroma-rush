#!/usr/bin/env bash
# Records the store preview videos: the cover, then a few seconds of each world.
#   tools/record_previews.sh
# Writes:
#   publish/previews/preview_landscape_1920x1080.mp4
#   publish/previews/preview_portrait_1080x1620.mp4
# The game plays itself (autopilot, no crashes) on the renderer the web build uses, so the
# videos show what players get in a browser. It opens a game window for each clip and takes
# about ten minutes. Every run drives a different road, so watch the result; to pick other
# moments, change START below (seconds into each world's clip) and run again with KEEP=1.
# Requires Godot 4.7 and ffmpeg (set GODOT if Godot is not on PATH).
#   OUT=<dir>   write the videos somewhere else
#   KEEP=1      keep the raw clips in build/previews and reuse the ones already there
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$ROOT/publish/previews}"
CLIPS="$ROOT/build/previews"

WORLDS=(meadow glacier canyon volcano space)
CLIP_SECONDS=30   # recorded per world
START=14          # where the part used in the video starts
PART_SECONDS=3.6  # used per world; cover (1 s) + 5 worlds stays under the 20 s portals allow

mkdir -p "$OUT" "$CLIPS"
touch "$ROOT/build/.gdignore"
# Godot's movie writer records at the window size, which only override.cfg can set.
trap 'rm -f "$ROOT/override.cfg"' EXIT

record() { # name width height [harness options]
	local name=$1 width=$2 height=$3
	shift 3
	if [[ -n "${KEEP:-}" && -f "$CLIPS/$name.avi" ]]; then
		return
	fi
	printf '[display]\n\nwindow/size/window_width_override=%s\nwindow/size/window_height_override=%s\n\n[editor]\n\nmovie_writer/mjpeg_quality=0.95\n' \
		"$width" "$height" > "$ROOT/override.cfg"
	echo "Recording $name..."
	"$GODOT" --path "$ROOT" --rendering-method gl_compatibility --fixed-fps 60 \
		--write-movie "$CLIPS/$name.avi" res://scripts/dev/dev.tscn -- \
		--autoplay --god --tutorial-done --keep-running --quit-at="$CLIP_SECONDS" "$@" > /dev/null 2>&1
	rm -f "$ROOT/override.cfg"
}

assemble() { # output cover prefix
	local output=$1 cover=$2 prefix=$3
	local inputs=(-loop 1 -framerate 60 -t 1.0 -i "$cover")
	local filter="" joined="" n=1
	for world in "${WORLDS[@]}"; do
		inputs+=(-ss "$START" -t "$PART_SECONDS" -i "$CLIPS/${prefix}_$world.avi")
		filter+="[$n:v]fps=60,format=yuv420p,setpts=PTS-STARTPTS[v$n];"
		joined+="[v$n]"
		n=$((n + 1))
	done
	filter+="${joined}concat=n=${#WORLDS[@]}:v=1:a=0,fps=60,settb=AVTB[game];"
	filter+="[0:v]fps=60,format=yuv420p,settb=AVTB[cover];"
	filter+="[cover][game]xfade=transition=fade:duration=0.3:offset=0.7[out]"
	ffmpeg -v error -y "${inputs[@]}" -filter_complex "$filter" -map "[out]" -an \
		-c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -movflags +faststart "$output"
	echo "Wrote $output ($(du -h "$output" | cut -f1 | tr -d " "))"
}

for world in "${WORLDS[@]}"; do
	record "landscape_$world" 1920 1080 --world="$world"
	record "portrait_$world" 1080 1620 --world="$world" --touch
done

# The videos open on the cover art; the portrait one needs it at the video's size.
"$GODOT" --path "$ROOT" -s res://scripts/dev/render_covers.gd -- --out="$CLIPS" --video-intro > /dev/null 2>&1

assemble "$OUT/preview_landscape_1920x1080.mp4" "$CLIPS/cover_landscape_1920x1080.png" landscape
assemble "$OUT/preview_portrait_1080x1620.mp4" "$CLIPS/intro_portrait_1080x1620.png" portrait

if [[ -z "${KEEP:-}" ]]; then
	rm -rf "$CLIPS"
fi
