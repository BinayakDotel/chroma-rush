#!/usr/bin/env bash
# Compiles a small Godot web export template for Chroma Rush: the engine without the parts the
# game does not use (physics, navigation, XR, video, networking extras, texture compressors,
# importers, and the advanced GUI nodes), optimized for size. 3D stays, and so do noise (the
# scenery uses FastNoiseLite) and bcdec (phones without S3TC decode the desktop textures).
# The stock template's wasm is about 39 MB; portals count that against their limits
# (CrazyGames: 20 MB to be shown on its mobile homepage). Worm Slip has its own, smaller one.
#
#   tools/build_web_template.sh [work_dir]
#
# work_dir (default ~/godot-build-chroma) holds the Godot source and emsdk; both are fetched on
# the first run. Keep it apart from another game's work_dir: scons writes its objects into the
# source tree, so two different module lists in one tree rebuild each other every time. The
# template is written to build/templates/web_nothreads_release.zip, which the web export
# presets use as their custom release template. The first build takes about 15-30 minutes.
# Needs git, python3 with scons (pip3 install scons) and about 5 GB of disk.
set -euo pipefail

GODOT_TAG="4.7.2-stable" # must match the editor version
EM_VERSION="4.0.11"      # what Godot's own CI uses for this tag (.github/workflows/web_builds.yml)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${1:-$HOME/godot-build-chroma}"
OUT="$ROOT/build/templates"

mkdir -p "$WORK" "$OUT"
touch "$ROOT/build/.gdignore"
[ -d "$WORK/godot" ] || git clone --depth 1 --branch "$GODOT_TAG" https://github.com/godotengine/godot.git "$WORK/godot"
[ -d "$WORK/emsdk" ] || git clone --depth 1 https://github.com/emscripten-core/emsdk.git "$WORK/emsdk"
"$WORK/emsdk/emsdk" install "$EM_VERSION" >/dev/null
"$WORK/emsdk/emsdk" activate "$EM_VERSION" >/dev/null
# shellcheck disable=SC1091
source "$WORK/emsdk/emsdk_env.sh" >/dev/null 2>&1

# Modules the game does not use. Kept on purpose: gdscript, freetype and text_server_fb
# (fonts), noise, bcdec, ogg and vorbis (music), webp, regex and mbedtls.
OFF=(
	astcenc basis_universal betsy bmp camera csg cvtt dds enet etcpak fbx gltf
	godot_physics_2d godot_physics_3d gridmap hdr interactive_music jolt_physics jpg jsonrpc
	ktx lightmapper_rd meshoptimizer mobile_vr mp3 msdfgen multiplayer navigation_2d
	navigation_3d objectdb_profiler openxr raycast svg text_server_adv tga theora
	tinyexr upnp vhacd visual_shader webrtc websocket webxr xatlas_unwrap zip
)
ARGS=()
for module in "${OFF[@]}"; do
	ARGS+=("module_${module}_enabled=no")
done

cd "$WORK/godot"
scons platform=web target=template_release threads=no \
	disable_advanced_gui=yes disable_physics_2d=yes disable_physics_3d=yes \
	disable_navigation_2d=yes disable_navigation_3d=yes disable_xr=yes \
	optimize=size_extra lto=full \
	module_text_server_fb_enabled=yes "${ARGS[@]}" \
	-j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"

cp bin/godot.web.template_release.wasm32.nothreads.zip "$OUT/web_nothreads_release.zip"
echo "Template: $OUT/web_nothreads_release.zip"
unzip -l "$OUT/web_nothreads_release.zip" | grep -E "wasm|js$"
