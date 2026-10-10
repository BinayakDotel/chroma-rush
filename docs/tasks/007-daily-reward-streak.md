# 007: Daily reward streak

status: in review
base: main
depends: []
pr: https://github.com/BinayakDotel/chroma-rush/pull/48

## Goal

Very few players come back the next day: 1.84% on desktop and 0.97% on mobile, which scores 2 on each. The next step is 3.23% on desktop and 3.44% on mobile, and CrazyGames says strong games get 10–15%. Nothing in the game gives a player a reason to come back tomorrow. This is idea 1 under "Ideas for next" in `docs/game-design.md`.

What players should get:
- Once each local day, the first of home or results grants that day's gift. A new player never sees home until after the first run, so day 1 appears on that run's results.
- Days 1–6 give 50, 75, 100, 125, 150 and 200 shards. Day 7 gives a Phoenix gem, or 200 shards if they already hold 3. The next day is day 1 again. A missed day pays day 1.
- The gift is a card: the day, the gift, and tomorrow's gift. Portrait results also shows tomorrow's gift. The card waits until the results count-up has finished.

## Decisions

- Gifts, not doubled by the Supporter Pack: days 1–6 are 50, 75, 100, 125, 150, 200 shards. Day 7 calls `Profile.add_revive_token()`. If that returns false (already 3), day 7 gives 200 shards. The day after 7 is day 1.
- A missed day is a local calendar date more than one day after the last claim. It still pays, and the gift is day 1.
- Save on the existing profile (`user://profile.cfg`), and clear it in `reset_progress`: `streak_day` (0 until the first claim, else 1–7), `last_claim_date` (`YYYY-MM-DD` from `Time.get_datetime_dict_from_system()`), `last_claim_unix`. Old saves have none of these, so the next session is day 1. No version bump.
- A gift is due only when the system unix time is at least `last_claim_unix` and today's local date is after `last_claim_date`. The same local date does not pay again. The next calendar day advances the streak with `(streak_day % 7) + 1`. A local date more than one day ahead pays day 1. A clock set back (`now < last_claim_unix`) pays nothing until both checks pass.
- Claim on the home screen as soon as it is shown, or on results about 1 s after `show_summary`, whichever comes first. The shard count-up is a 0.7 s tween delayed by 0.3 s, so it ends at 1 s. Grant when the card opens. If the player leaves results before that, nothing is granted and the next home or results that day still offers it. The first run uses `_enter_first_wait`, so a new player gets the card on results.
- The card is an overlay (`open_overlay`), modal, `closes_on_outside_tap = true`, dimmed like the shop. Copy, in that order: `DAY 3`, `+100 SHARDS` or `PHOENIX GEM`, `TOMORROW: +75 SHARDS` or `TOMORROW: PHOENIX GEM` or `TOMORROW: +200 SHARDS`, and a `NICE` button. Tomorrow is the gift for the day after this claim, using the gem bank after today's grant.
- `NICE`, a tap outside the card, and Esc all close it. Esc already goes through `ui_cancel` → `handle_back()`, and an overlay that returns false from `handle_back()` is closed. Enter and Space also press `NICE` and the event is marked handled. Both keys are bound to `start`, so an unhandled press would fall through to play.
- Portrait results shows the same tomorrow line under the run stats, including when the gift was already claimed on home. Landscape already hides the mission rows (`_mission_box.visible = portrait`), so it does not add this line.

## Files

- `scripts/services/profile.gd` — streak fields, due / claim / tomorrow text, save, load, reset
- `scripts/ui/screens/daily_reward_screen.gd` — the overlay card, built in code
- `scripts/ui/ui_root.gd` — open it from `show_home` and, after 1 s, from `show_results`
- `scripts/ui/screens/results_screen.gd` — portrait tomorrow line

## Verify

- New profile: finish the first run. The score and shards count up, and about 1 s in the card shows `DAY 1`, `+50 SHARDS`, `TOMORROW: +75 SHARDS`. Shards increase by 50. RETRY stays behind the card until it closes.
- Close it four ways: `NICE`, tap outside the card, Esc, and Enter or Space. Enter and Space do not start another run.
- Same day, open home and finish another run. No second gift. Portrait results still shows `TOMORROW: +75 SHARDS`. Landscape results does not add that line.
- Next local day the card shows `DAY 2` and `+75 SHARDS`. Skip a day and it shows `DAY 1` again. On day 7, fewer than 3 gems grants a Phoenix gem; 3 gems grants `+200 SHARDS`.
- Set the clock back: no extra gift. Set it forward more than one local day: day 1, and no second claim that day.

## Outcome

Players now get one local-day gift, claimed on home or one second after results, with a 7-day shard streak and a Phoenix gem (or 200 shards) on day 7. The card and the portrait results line say what tomorrow pays. A missed day or a clock set back does not skip ahead or pay twice. Risk: the calendar gap uses noon UTC, so a date line that is not `YYYY-MM-DD` is treated as a miss and pays day 1.
