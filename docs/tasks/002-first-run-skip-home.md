# 002: First-run skip home — straight onto the road

status: in review
base: main
depends: []
pr: https://github.com/BinayakDotel/chroma-rush/pull/43

## Goal

Put new players straight on the road.

Today a first-time player lands on the home screen and has to press Play. For a player with no runs yet, skip the home screen: show the road with "Press any key or tap to start", and let that first key or tap start the run. The tap also gives the game keyboard focus and turns on the sound, which a run that starts by itself would not have.

## Decisions

- Cold start only. `_ready` checks `Profile.lifetime_runs == 0`. That includes a new profile, Reset Progress (it zeroes the counter; no second flag), and a run closed before results (`_record_run()` counts a run only from the results screen). Home, world browse, and results still call `_enter_menu()` and show the home screen, including Home during an unfinished first run.
- Waiting uses the menu road and orbit. No home UI, no world picker. The world is `Profile.selected_world` (Meadow for these players); do not force it. State stays `MENU`. `theme_next` does not browse while waiting.
- The prompt is one centred label on `UiRoot`, not the fading HUD hint. Touch (`Defs.touch_device()`): "Tap to start". Everywhere else: "Click or press any key to start".
- The splash still holds 0.35 s, then swells and fades over 0.45 s. Its cover blocks clicks, not keys. `UiRoot` reports when that tween finishes. The game shows the prompt and opens input in that same moment. If `icons/splash.png` is missing, `_play_intro()` returns immediately and input opens straight away. Keys before that moment do nothing.
- The gesture is a key press (not echo, not a gamepad button), a mouse click, or a touch. No gamepad: the input map has no gamepad bindings. No focus call and no audio change. A click or tap is the same gesture as Play, and web sound already follows it. Keys do not focus the CrazyGames frame.
- Start the run once, through the existing `_start()`. `emulate_touch_from_mouse` turns a click into a touch as well, and `_handle_touch()` would otherwise cycle colour on release or steer on a drag. Swallow that pointer gesture from press through release, including after the state is already `PLAYING`, so the click and its touch copy cannot start a second run or change lanes, colour, jump, or slam.

## Files

- `scripts/game.gd`
- `scripts/ui/ui_root.gd`
- `scripts/dev/flow_test.gd` — fresh profile: after the intro, waiting (prompt up, home hidden), then one key starts the run. Move "starts on the home screen" to after a finished run (`lifetime_runs >= 1`), at the pause → home check.

## Verify

- Fresh profile, and again after Reset Progress: the splash plays, then the road and the prompt, with no home UI. A phone says "Tap to start"; desktop says "Click or press any key to start".
- A key during the splash does nothing. After the prompt appears, one key starts the run and does not also steer.
- One click or tap starts the run once. Holding, dragging, and releasing does not change colour, lane, jump, or slam.
- Quit mid-run and launch again: the prompt is back. Finish a run and launch again: the home screen.
- During that first run, Home from pause opens the home screen.

## Outcome

A profile with no recorded runs stays on the menu road through the splash. When the splash tween ends (or there is no splash), a centred prompt appears and the next key, left click, or tap calls `_start()` once. That pointer is ignored until release so it cannot steer or change colour. Home, including Home from pause, still shows the home screen. Risk: a key during the splash is dropped only while the prompt is hidden; a click in that window is still eaten by the splash cover.
