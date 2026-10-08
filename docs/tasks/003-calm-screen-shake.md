# 003: Calm the screen shake

status: todo
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
- A short, small, smooth bump on a crash, a shield save, a power gem or the start of Overdrive.
- At its strongest (a crash), the view moves at most about 0.15 m and settles within about a third of a second of real time, slow-motion included.
- No shake while smashing through rows in Overdrive.
- The same feel on 60 Hz and 144 Hz screens.
- "Reduce motion" in Settings still turns the shake off completely.

## Decisions

<!-- /refine fills this -->

## Files

<!-- /refine lists paths; /implement reads only these + this ticket -->

## Verify

<!-- /refine: ≤5 manual bullets for the human; no agent Godot runs -->

## Outcome

<!-- /implement fills this -->
