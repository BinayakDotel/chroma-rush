# 001: Just Recipe for making game build

status: in review
base: main
depends: []
pr: https://github.com/BinayakDotel/chroma-rush/pull/42

## Goal

We will have simple "Just" recipe setup for building to each device.
Example: 
"just build web" - will build a web build for the game and save it into "build" directory. 
"just build listing-description" - It create a documentation with the valid details that can be added while uploading the game like: Controls, Descriptions, Orientation etc.
Similarly, "just build ios", "just build android", 

## Decisions

- One root `justfile`. `just build <target>` accepts `web`, `crazygames`, `android`, `ios`, `macos`, and `listing-description`. No argument, or any other name, prints those six names and exits 1.
- `web` and `crazygames` call `tools/build_web.sh` with that same argument. CrazyGames stays its own recipe: that preset embeds their SDK, and the plain web build does not. Do not add presets. Do not edit `tools/build_web.sh`.
- `android`, `ios`, and `macos` run `godot --headless --export-release` for the preset of that name, to the path already in `export_presets.cfg` (`build/android/ChromaRush.aab`, `build/ios/ChromaRush.ipa`, `build/macos/Chroma Rush.zip`). Create the destination directory and `build/.gdignore` if missing. A missing export template or signing setup fails the recipe with Godot's own error. No APK, no unsigned or debug preset.
- Godot is `"${GODOT:-godot}"`, same as the web script.
- `listing-description` overwrites `publish/listing.md` from `publish/listing.template.md`. The template is the current listing with two placeholders, `{{controls}}` and `{{orientation}}`. Name, tagline, descriptions, tags, and the facts table stay in the template and are copied through unchanged.
- `{{orientation}}` is the fixed sentence: "Portrait on a phone; the layout also adapts when the window is landscape."
- `{{controls}}` is generated, not hand-copied. Keyboard lines for lane, jump, slam, colour, and Prism come from the input map (`move_left`, `move_right`, `jump`, `slam`, `color_1`, `color_2`, `color_3`, `color_next`, `prism`). Omit `start` and `theme_next`. Pause is `P` only, from the `KEY_P` check in `scripts/game.gd` (the old listing's Esc line is wrong). Touch lines for lane, jump, colour, and Prism come from one const on `howto_screen.gd` that `build()` also uses. Skip the fuel and gem "steer into the lane" lines; they repeat the lane swipe.
- The generator is `scripts/dev/write_listing.gd`, run headless with `-s`. It loads the how-to const and `InputMap`. It does not parse `project.godot` as text.
- README "Building for release" names `just` (install from https://just.systems) and these recipes, and keeps the existing `tools/build_web.sh` commands.

## Files

- `justfile`
- `README.md`
- `publish/listing.template.md`
- `publish/listing.md` (recipe output only)
- `scripts/dev/write_listing.gd`
- `scripts/ui/screens/howto_screen.gd`

## Verify

- `just build` with no name prints the six names and exits non-zero. `just build nope` does the same.
- `just build listing-description` rewrites `publish/listing.md`: controls match the input map, the how-to touch lines, and pause on P; orientation is the portrait sentence; the description paragraphs match the template.
- Change one input-map key, run `just build listing-description` again, and that key appears in the controls section.
- `just build web` writes `build/web` and `build/upload/chroma-rush-web.zip`. `just build crazygames` writes `build/crazygames` and `build/upload/chroma-rush-crazygames.zip`.
- `just build android` writes `build/android/ChromaRush.aab`, or fails with Godot's missing-template or signing error. Same check for `ios` and `macos` if those templates are installed.

## Outcome

`just build <target>` covers web, crazygames, android, ios, macos, and listing-description. Web targets still call `tools/build_web.sh`. Native targets export the existing release presets into `build/`. The listing recipe fills `{{controls}}` from the input map and `HowToScreen.TOUCH_CONTROLS`, and `{{orientation}}` with the portrait sentence. Pause is P.

Risk: `publish/listing.md` still has the old Esc and landscape lines until someone runs `just build listing-description` (that step starts Godot). Android, iOS, and macOS were not exported here.
