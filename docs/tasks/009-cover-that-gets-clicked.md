# 009: A cover that gets clicked

status: in progress
base: main
depends: []
pr:

## Goal

CrazyGames showed the game's cover 64,000 times in its first four days, but only 1.0% of people clicked it. That is in CrazyGames' bottom 20%: the bottom-20% line is about 1.8% and the top 20% is about 4%. This isn't part of the Basic Launch score, but it decides how many people ever try the game, and after Full Launch, plays are what pay. At 2% instead of 1%, the same impressions would bring twice the players.

The current covers show the fox in its kart on a plain purple background, with the title taking up half the picture. Nothing in them shows what you do in the game: the road, the coloured gates, matching your colour, speed. CrazyGames already prints the game's name under every thumbnail.

What players should see:
- A cover that shows a moment of play. For example: the kart on the road, bursting through a gate of its own colour, the next gates ahead in the other two colours, and a world behind it.
- The kart large enough to read at thumbnail size, with little or no title text. The top-left corner stays clear for CrazyGames' labels, as today.
- All three shapes (landscape 1920×1080, portrait 800×1200, square 800×800), rendered by `scripts/dev/render_covers.gd` so they can be made again later.
- Uploaded through the Art tab. Art updates go live at once in Basic Launch. Add the upload date to `publish/crazygames/submission.md` so the CTR chart before and after can be compared.

(Replaces the old "Load in under 10 seconds" ticket: CrazyGames measures an average loading time of 1.3 s, so loading is not the problem.)

## Decisions

- Picture: Meadow, just after a pass. The red fox kart (`Vehicles.build("kart")`, paint `Defs.COLORS[0]`) is already through the red gate, with clear road between the kart and that gate so the two reds stay separate at thumbnail size. Ahead in the same lane: a short line of red orbs (`Obstacles.gem` slot 0) leading into the kart, then a yellow gate, then a blue gate. Side lanes of those rows stay empty. Meadow sky, a straight meadow road, and a few pines and a mountain (`Props.build`) behind. No wordmark, no logo, no trail graphic from the old cover.
- The shatter is the game's, not new debris. Freeze the red panel's `burst` on `shaders/gate.gdshader` mid-way (ring visible, panel breaking up). Red sparkles, the same dots as `Player` gate bursts, hang in the air at that gate, not on the kart. Capture after they have emitted. The panel stays unshaded, as in a run.
- Camera: one pose per cover, low and just off the kart's rear quarter, so the fox's face and the road ahead are both in frame. The kart and the red gate stay inside the inner 80% of each image (CrazyGames crops the outer ~10%). The top-left of that safe area is sky only.
- Shadows: the cover viewport runs on the desktop renderer, so turn the meadow sun's directional shadows on for the kart, road, arch, and props. Do not change the web Compatibility shadow path.
- Scope: the three cover PNGs only. Leave the icon, splash, and both preview videos. Keep `--video-intro` working, but do not pass it and do not re-record video. Do not run Godot. After the script is in, the human runs the render command below and those three PNGs go in the same PR before `gt create`. The Art-tab upload and the date in `submission.md` are Verify, after the pictures exist.

## Files

- `scripts/dev/render_covers.gd` — staged 3D shot replaces the flat sky, trail, and wordmark; three cameras
- `publish/covers/cover_landscape_1920x1080.png`
- `publish/covers/cover_portrait_800x1200.png`
- `publish/covers/cover_square_800x800.png`

## Verify

- Run `godot --path . -s res://scripts/dev/render_covers.gd` (it needs a window). It rewrites the three files in `publish/covers/`.
- View each at about 200 px wide next to live CrazyGames thumbnails. The kart reads first. The red burst sits behind it with road between them. Yellow, then blue, are ahead. No title. Top-left is empty. The kart and the red gate are not in the outer 10%.
- Icon, splash, and both preview videos are unchanged.
- Upload the three covers on the CrazyGames Art tab. They go live without a new build.
- Add that date to the status table in `publish/crazygames/submission.md`. After 2–3 days, compare the Gamepage CTR line before and after.

## Outcome

<!-- /implement fills this -->
