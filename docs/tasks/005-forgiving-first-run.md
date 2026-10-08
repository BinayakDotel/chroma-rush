# 005: Make the first minute hard to lose

status: done
base: main
depends: []
pr: https://github.com/BinayakDotel/chroma-rush/pull/45

## Goal

CrazyGames counts a player as converted only if they play for at least one minute. A new player who misreads a gate at 30 seconds, crashes and closes the tab counts against the game.

What players should get:
- The very first run starts with a Shield, the existing power that absorbs one crash. It shows on the kart and in the HUD, with a short hint such as "SHIELD: ONE FREE CRASH!".
- The first run stays at warm-up pace, with wide row spacing, for about 60 seconds. The normal warm-up is 250 m, about 16 seconds.
- Fuel stays fair through the longer warm-up, so the tank never runs low before it ends.
- Every run after the first is unchanged.

## Decisions

- `depends: []`. This ticket does not change how a new player enters the run. 006 still lists 004.
- First run means `Profile.lifetime_runs == 0` when `_start()` runs. That includes a new profile, Reset Progress, and a run quit before results. A revive inside that run stays the first run: warm-up continues by distance, and revive does not grant another free shield. A retry after the results screen is a normal run.
- Shield: in `_start()`, after `_first_run` is set, set `shield = true` and `player.shield = true`. Not in `_new_run()` (`_new_run()` sets `shield = false`, and it also runs when the home screen loads). One charge, spent the same way as a shield gem. A shield gem picked up while it is held does not stack.
- Hint: on the first run, `hud.hint("SHIELD: ONE FREE CRASH!", Powers.info(Powers.Kind.SHIELD).color, 1.6)` replaces "GO!". The colour tip still fires when the first row (90 m) is close, about 2.7 s in, after this hint has faded (0.1 s in, 1.6 s hold, 0.3 s out).
- Calm distance: pacing checks take a distance, default `Pacing.WARM_UP` (250 m), and 1,100 m on the first run. The speed curve is unchanged. 1,100 m is the end of the 1,000 m breather, so the next metres are the start of a normal wave. `is_calm()` is true for the whole stretch below that distance. `wave_spacing()` keeps a milestone breather at `BREATHER_SPACING` (1.8) inside the longer warm-up (500–600 m and 1,000–1,100 m). Every other metre below the calm distance stays at `WARM_UP_SPACING` (1.35), including 0–100 m. A normal run is unchanged. Set the distance before `track.reset()` inside `_new_run()` (from `lifetime_runs == 0`). `reset()` already builds the opening rows; setting it only in `_start()` would leave those rows on the 250 m warm-up.
- Fuel: on the first run, while `distance < 1100`, burn at ×0.4. One effective tank time, `Pacing.tank_time(distance) * _tank_bonus / 0.4`, is used both where fuel burns (`_burn_fuel`) and in the range estimate for fuel drops (`_maybe_drop_fuel`). That is a longer tank, not a shorter one: about 60 s with no pickups uses about 63% and stays above the 25% warning. After 1,100 m, normal drain from the fuel left. Pickups, drops, and the fuel tip stay as they are.

## Files

- `scripts/pacing.gd` — calm distance on `is_calm`, `wave_spacing`, and the row-gap path that calls them
- `scripts/track.gd` — hold that distance for the run and pass it into those checks
- `scripts/game.gd` — set it before `track.reset()`, grant the shield and hint in `_start()`, share the effective tank time
- `scripts/dev/flow_test.gd` — fresh profile starts shielded; the run after results does not

## Verify

- Fresh profile, and again after Reset Progress: the kart bubble and the HUD shield badge are up, and the hint is "SHIELD: ONE FREE CRASH!" with no "GO!". The first crash is saved. The next crash ends the run.
- Rows stay easy, at warm-up spacing, until 1,100 m. The stretches at 500–600 m and 1,000–1,100 m are wider than the rest of that opening, not tighter. Past 1,100 m the run builds like a normal wave.
- Catch nothing: the low-fuel warning does not appear before 1,100 m. After that, the tank drains as on any other run.
- Finish so the results screen shows, then retry: no free shield, the short warm-up, and normal fuel drain. A revive during the first run does not add a second shield, and the long warm-up continues from the distance you had reached.
- Picking up a Shield gem while the free one is still held does not give a second charge.

## Outcome

The first run (`lifetime_runs == 0` at start) begins with one shield and the shield hint, stays calm to 1,100 m (wide spacing, with the 500 m and 1,000 m breathers still wider), and burns fuel at ×0.4 until that distance. Later runs, including a retry after results, use the 250 m warm-up and normal drain. A revive does not grant another shield.

Risk: opening rows are built in `reset()` from `calm_distance` set in `_new_run()`. Anything that resets the track without setting that distance first still gets the 250 m warm-up.
