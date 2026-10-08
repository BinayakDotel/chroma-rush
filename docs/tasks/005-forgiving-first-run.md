# 005: Make the first minute hard to lose

status: todo
base: main
depends: [004]
pr:

## Goal

CrazyGames counts a player as converted only if they play for at least one minute. A new player who misreads a gate at 30 seconds, crashes and closes the tab counts against the game.

What players should get:
- The very first run starts with a Shield, the existing power that absorbs one crash. It shows on the kart and in the HUD, with a short hint such as "SHIELD: ONE FREE CRASH!".
- The first run stays at warm-up pace, with wide row spacing, for about 60 seconds. The normal warm-up is 250 m, about 16 seconds.
- Fuel stays fair through the longer warm-up, so the tank never runs low before it ends.
- Every run after the first is unchanged.

## Decisions

<!-- /refine fills this -->

## Files

<!-- /refine lists paths; /implement reads only these + this ticket -->

## Verify

<!-- /refine: ≤5 manual bullets for the human; no agent Godot runs -->

## Outcome

<!-- /implement fills this -->
