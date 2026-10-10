# 006: Release 1.0.1 to CrazyGames

status: done
base: main
depends: [002, 003, 005]
pr: https://github.com/BinayakDotel/chroma-rush/pull/47

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

- Paperwork only: `config/version` in `project.godot` 1.0.0 → 1.0.1. No rebuild, no upload; the next build is 010 (1.0.2). Android, iOS and macOS export versions unchanged.
- Append these rows to the status table in `publish/crazygames/submission.md`:

  | Date | Event |
  | --- | --- |
  | 2026-10-03 | Resubmitted for Basic Launch (web build 1.0.0). |
  | 2026-10-05 | Basic Launch started. Ends after 7 full days and 500 plays; expires 26 Oct. |
  | 2026-10-07 | First scores (5–7 Oct, 289 plays): desktop 4/15, mobile 3/15. Player bug report: "Screen shakes are absurd". |
  | 2026-10-08 | Update live: new players start on the road (002), calm screen shake (003), forgiving first run (005). The build still shows version 1.0.0 in settings. |
  | 2026-10-09 | Scores (5–8 Oct, 388 plays, almost all old build): desktop 4/15, mobile 4/15. Avg loading 1.3 s; thumbnail CTR 1.0% (bottom 20%). |
  | 2026-10-10 | Stats 5–9 Oct (496 plays; 9 Oct is the first full day of the new build): all devices playtime 3m04s, conversion 35.8%, D1 1.40%. No clear change yet. 500 plays reached; the test ends after 12 Oct. |
  | 2026-10-10 | Emailed Developer Support (topic "My game listing") asking to weigh the days after 8 Oct or grant another Basic Launch period. |
- Leave the rest of the file as it is, except one line above the old checklist: "(Written 2 Oct, before the resubmission.)"
- Verify: Binayak sends the support email. If it goes out on a different day, change the date in the last row before marking this done.

## Files

- `project.godot` — `config/version`
- `publish/crazygames/submission.md` — status rows, and one line above the old checklist

## Verify

- `project.godot` `config/version` is `1.0.1`. Android, iOS, and macOS versions in `export_presets.cfg` are unchanged.
- The status table has the new rows from Decisions. The 8 Oct row says the live build still shows 1.0.0 in settings.
- `(Written 2 Oct, before the resubmission.)` sits above the old checklist. The rest of `publish/crazygames/submission.md` is unchanged.
- Send the Developer Support email tonight (topic "My game listing"), using the message in the Goal. If it goes out on another day, change the date on the last row before marking this done.

## Outcome

`config/version` is 1.0.1 so the next export is labeled correctly; the live CrazyGames build is still 1.0.0. Status rows record Basic Launch through 10 Oct and the support email. Risk: the last row says the email went out on 10 Oct; if it goes out later, change that date before marking this done.
