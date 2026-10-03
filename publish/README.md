# Publishing

Everything a marketplace asks for besides the game itself. Shared material sits at the top; each marketplace gets a folder for what only it needs.

```
publish/
  listing.md            Name, description, controls, tags and facts: the text for any store page
  covers/               Cover art in the three shapes portals ask for
  previews/             Preview videos (not in git: large, and made by a script)
  crazygames/
    submission.md       Form answers, upload checklist, limits and review history
```

The game builds are not here. They go to `build/` (not in git):

```
build/
  web/                  Web export (index.html and 8 more files)
  upload/               Archives ready to upload: chroma-rush-web.zip
  android/, ios/, macos/   Native exports, at the paths set in export_presets.cfg
```

## Making each piece

Set `GODOT` to the Godot 4.7 binary if it is not on your PATH. The cover and preview commands open a window.

| Piece | Command |
| --- | --- |
| Web build and upload zip | `tools/build_web.sh` |
| Covers | `godot --path . -s res://scripts/dev/render_covers.gd` |
| Preview videos | `tools/record_previews.sh` (about ten minutes, needs ffmpeg) |
| App icon, splash, logo kart | `godot --path . -s res://scripts/dev/render_icons.gd`, then `godot --headless --path . --import` |

Re-render the covers and previews after changing the kart, the logo or the look of the game, so the store art matches what players get.

## Adding a marketplace

1. Make a folder named after it, with a `submission.md` holding its form answers, size limits and review history.
2. Take the text from `listing.md` and the art from `covers/` and `previews/`. If it needs art in another size, add the layout to `scripts/dev/render_covers.gd` so it can be re-rendered.
3. If it needs its own build (an SDK, a different preset), add the preset to `export_presets.cfg` and a target to `tools/build_web.sh`, and send the archive to `build/upload/`.
