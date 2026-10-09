# 007: Daily reward streak

status: todo
base: main
depends: []
pr:

## Goal

Very few players come back the next day: 1.84% on desktop and 0.97% on mobile, which scores 2 on each. The next step is 3.23% on desktop and 3.44% on mobile, and CrazyGames says strong games get 10–15%. Nothing in the game gives a player a reason to come back tomorrow. This is idea 1 under "Ideas for next" in `docs/game-design.md`.

What players should get:
- The first time they open the game on a new day (local time), they get that day's gift, once.
  - Days 1–6 give shards. Suggested: 50, 75, 100, 125, 150 and 200.
  - Day 7 gives a Phoenix gem, or shards if they already hold 3 gems.
- Missing a day starts the streak again at day 1.
- The gift shows as a short pop-up on the home screen. A brand-new player gets day 1 after their first run, so it doesn't get in the way of the road start from 002.
- The results screen shows tomorrow's gift, for example "Come back tomorrow: +75 shards".
- The streak is saved with the rest of the progress. Setting the device clock back doesn't give extra gifts.

## Decisions

<!-- /refine fills this -->

## Files

<!-- /refine lists paths; /implement reads only these + this ticket -->

## Verify

<!-- /refine: ≤5 manual bullets for the human; no agent Godot runs -->

## Outcome

<!-- /implement fills this -->
