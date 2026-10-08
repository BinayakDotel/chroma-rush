# 003: Calm the screen shake

status: in progress
base: main
depends: []
pr:

## Goal

A desktop player reported "Screen shakes are absurd" during Basic Launch, and they're right. Right now:
- The camera jumps to a new random spot every frame.
- A crash throws the view up to 0.6 m.
- In Prism Overdrive, every smash restarts the shake, so the screen shakes for the whole 5 seconds.
- The crash slow-motion makes the crash shake last about 3 times longer.

What players should get:
- A short, small, smooth bump on a crash, a shield save, or the start of Overdrive. A power gem does not shake.
- At its strongest (a crash), the view moves at most about 0.15 m and settles within about a third of a second of real time, slow-motion included.
- No shake while smashing through rows in Overdrive.
- The same feel on 60 Hz and 144 Hz screens.
- "Reduce motion" in Settings still turns the shake off completely.

## Decisions

- One bump is one lens offset on `ChaseCamera`. `shake(peak)` jumps to that peak on the frame it starts, then eases back. It does not pick a new random spot each frame. `h_offset` and `v_offset` are `frame_offset` plus the bump, so the home screen keeps its off-centre framing.
- Direction is one angle `a` in `[0, π]`, held for the whole bump: `h = cos(a) * peak`, `v = sin(a) * peak`. The offset length is exactly `peak`. `v > 0` moves the camera up (the picture drops). These are lens shifts, so sideways and up stay true to the screen as the road twists.
- Duration is the same for every bump. `T = 1/3` s. While `t < T`, the offset still on screen is `peak * (1 - t / T)²`. `t` advances by `delta / maxf(Engine.time_scale, 0.01)`. At `t >= T`, clear the bump and write `frame_offset` only.
- A later `shake(peak)` replaces the current bump only when its peak is greater than the offset still on screen. A replacement picks a new angle, jumps to its own peak, and sets `t` back to 0.
- `game.gd` is the only caller. Crash (`_end_run` when it explodes) passes `0.15`. Shield save (`_crash`) passes `0.10`. Overdrive start (`_activate_prism`) passes `0.08`. Remove the smash call in `_resolve_row` and the power-gem call in `_apply_power`. Out of fuel (`_end_run` with no explosion) never calls `shake()`.
- Reduce motion still makes `shake()` return immediately. `_process` also checks `Settings.reduce_motion`: if it is on, drop the bump already playing and set the lens back to `frame_offset`. Turning it off does not resume that bump.

## Files

- `scripts/chase_camera.gd`
- `scripts/game.gd`

## Verify

- Crash: one bump, camera moves up, back to rest in about a third of a second while the slow-motion plays. The view does not buzz, and it stays within about 0.15 m.
- Shield save and the start of Overdrive: smaller bumps, same length. Smashing rows during Overdrive does not shake. A power gem does not shake. Out of fuel does not shake.
- A smaller bump during a larger one that is still strong does not stack. A stronger bump during a weaker leftover does play.
- Pause during a bump and turn on Reduce motion: the bump disappears and stays gone if you turn it off again. On the home screen the kart stays framed off-centre.

## Outcome

<!-- /implement fills this -->
