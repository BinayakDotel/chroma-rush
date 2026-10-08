# 009: Load in under 10 seconds

status: todo
base: main
depends: []
pr:

## Goal

CrazyGames says slow loading pulls conversion down, and its top games load in under 10 seconds. Only 31% of mobile players play for a full minute, and some of them may leave while the game is still loading. The web build downloads about 12 MB compressed: the 18.6 MB engine, the 3.5 MB game pack and a 0.5 MB splash.

What players should get:
- The game on screen within 10 seconds on an average desktop connection, and within about 15 seconds on a mid-range Android phone. If a gap remains, the reason is written down.
- A loading screen that shows progress, so they can see the game is coming.
- Load times measured from opening the page to the game's first frame, on desktop Chrome with "Fast 4G" throttling and on a real phone. They are recorded in `publish/crazygames/submission.md` so later builds can be compared.

## Decisions

<!-- /refine fills this -->

## Files

<!-- /refine lists paths; /implement reads only these + this ticket -->

## Verify

<!-- /refine: ≤5 manual bullets for the human; no agent Godot runs -->

## Outcome

<!-- /implement fills this -->
