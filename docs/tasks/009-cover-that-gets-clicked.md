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

<!-- /refine fills this -->

## Files

<!-- /refine lists paths; /implement reads only these + this ticket -->

## Verify

<!-- /refine: ≤5 manual bullets for the human; no agent Godot runs -->

## Outcome

<!-- /implement fills this -->
