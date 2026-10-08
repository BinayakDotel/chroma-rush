# 006: Release 1.0.1 to CrazyGames

status: todo
base: main
depends: [003, 004, 005]
pr:

## Goal

Basic Launch is scored on its last 7 days, about 6 to 12 Oct 2026, and an update goes live as soon as it is uploaded. Getting 003–005 to players by 9 Oct means most of the scoring window measures the new build. CrazyGames support should also know what changed and when.

What this covers:
- Set the version to 1.0.1 in `project.godot`.
- Add a 1.0.1 row to the status table in `publish/crazygames/submission.md`, saying what changed.
- Make the CrazyGames web build (`tools/build_web.sh crazygames`, or the Just recipe from 001 if it has landed). Play it on a laptop and a real phone, then upload all 9 files with "Submit new version". Binayak does this part.
- Send Developer Support a message through the portal. Binayak does this part. Draft:

> Hi, Chroma Rush has been in Basic Launch since 5 Oct. On <date> I uploaded version 1.0.1: calmer screen shake (from a player report), new players now start straight in a run, and the first run is more forgiving. Could the review take the days after this update into account, or could I get another Basic Launch period if the score is close? Thanks, Binayak

## Decisions

<!-- /refine fills this -->

## Files

<!-- /refine lists paths; /implement reads only these + this ticket -->

## Verify

<!-- /refine: ≤5 manual bullets for the human; no agent Godot runs -->

## Outcome

<!-- /implement fills this -->
