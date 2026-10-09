# 006: Release 1.0.1 to CrazyGames

status: todo
base: main
depends: [002, 003, 005]
pr:

## Goal

The build with 002 (new players start on the road), 003 (calm shake) and 005 (forgiving first run) was uploaded and went live on the evening of 8 Oct 2026. The dashboard marks it as the release on 8 Oct. What's left is the paperwork, plus telling CrazyGames.

Basic Launch is scored on its last 7 days, about 6 to 12 Oct. Only about 4 of those 7 days run the new build, so the old build will drag the score down. The best realistic result is a second Basic Launch period measured on the new build. The support message asks for exactly that, and it should go out today.

What this covers:
- Set the version to 1.0.1 in `project.godot`.
- Add rows to the status table in `publish/crazygames/submission.md`:
  - 5 Oct: Basic Launch started.
  - 7 Oct: first scores, desktop 4/15 and mobile 3/15.
  - 8 Oct: 1.0.1 live (002, 003, 005).
  - The date the support message was sent.
- Send Developer Support this message through the portal. Binayak does this part.

> Hi, Chroma Rush has been in Basic Launch since 5 Oct. On the evening of 8 Oct I released an update that targets the weak metrics: new players now start straight on the road instead of the home screen, the first run is more forgiving (a free shield and a gentler first minute), and the screen shake from a player report is fixed. Because the update arrived halfway through the scoring window, could the review look at the days after 8 Oct, or could I get another Basic Launch period with the new build? Thanks, Binayak

## Decisions

<!-- /refine fills this -->

## Files

<!-- /refine lists paths; /implement reads only these + this ticket -->

## Verify

<!-- /refine: ≤5 manual bullets for the human; no agent Godot runs -->

## Outcome

<!-- /implement fills this -->
