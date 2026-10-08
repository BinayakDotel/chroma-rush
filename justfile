# Release builds. `just build` with no name, or an unknown name, lists the targets and exits 1.
# Godot is the same binary the web script uses: $GODOT, or `godot` on PATH.

build target="":
    #!/usr/bin/env bash
    set -euo pipefail
    godot="${GODOT:-godot}"
    case "{{target}}" in
    web | crazygames)
        tools/build_web.sh "{{target}}"
        ;;
    android)
        mkdir -p build/android
        touch build/.gdignore
        "$godot" --headless --path . --export-release Android build/android/ChromaRush.aab
        ;;
    ios)
        mkdir -p build/ios
        touch build/.gdignore
        "$godot" --headless --path . --export-release iOS build/ios/ChromaRush.ipa
        ;;
    macos)
        mkdir -p build/macos
        touch build/.gdignore
        "$godot" --headless --path . --export-release macOS "build/macos/Chroma Rush.zip"
        ;;
    listing-description)
        "$godot" --headless --path . -s res://scripts/dev/write_listing.gd
        ;;
    *)
        printf '%s\n' web crazygames android ios macos listing-description >&2
        exit 1
        ;;
    esac
