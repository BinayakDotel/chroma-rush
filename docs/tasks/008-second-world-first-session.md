# 008: Unlock the second world in the first session

status: done
base: main
depends: []
pr: https://github.com/BinayakDotel/chroma-rush/pull/46

## Goal

Average playtime is 3m25s on desktop, down from 3m39s, and 2m30s on mobile. Both score 1. The next steps are 3m42s on desktop and 3m16s on mobile, and CrazyGames' strong games reach 10 minutes or more. A new world is the most exciting thing a player can earn. But Glacier costs 500 shards and a run pays 1 shard per orb plus 1 per 50 m, so a new player rarely unlocks it on a first visit.

This is the quickest of the remaining fixes. Ship it on its own (010) by 10 Oct if possible, so it lands inside the Basic Launch scoring window.

What players should get:
- A new player unlocks Glacier within about 3–5 short runs of 1–2 minutes each, counting mission rewards.
- The results screen keeps showing how many shards are left for the next unlock, so one more run always feels worth it.
- Later worlds and upgrades keep their current pace. `docs/game-design.md` gets the new numbers.

## Decisions

- Price: `Economy.WORLD_COST["glacier"]` 500 → 250. Nothing else in the economy changes (orb/distance pay, mission rewards, upgrade costs, Canyon 1,500 / Volcano 3,500 / Solar 6,000). Update the same number in `docs/game-design.md` and the README worlds table.
- Goal: while Glacier is locked, `Profile.next_goal()` returns it (`id` `"glacier"`, `upgrade` false, cost 250), even when a 150-shard upgrade is cheaper. World Pass already unlocks it, so the pin does not apply. After Glacier is unlocked, the cheapest upgrade or locked world, as today. The upgrades screen still sells every level. A world goal includes `id` so the results button knows what to buy.
- Landscape: `results_screen.gd` `layout()` no longer hides the goal when the screen is landscape. Mission rings stay portrait-only. The base window is 720×720 with stretch aspect `expand` and a 1280×720 override, so desktop is 720 px tall. In landscape the card is a row: score, best, and the three numbers on the left; the goal line and bar, or the unlock / upgrade button, on the right. Title stays above. Offers and HOME / RETRY stay below. All of that is on screen at once.
- One-tap unlock: when the goal is a world and `have >= cost`, both orientations show a gold button in the UPGRADE READY slot, labelled `UNLOCK %s` with the world name. The progress line and bar stay hidden while that button is up, same as UPGRADE READY. UPGRADE READY itself also shows in landscape once that is the goal. Pressing the unlock button records the run first (`_leave_results`, so this run's shards are in the profile and an interstitial can still show), then `Profile.buy_world(id)`, `select_world`, set `world_index`, `_apply_theme()`, and the retry path `_new_run()` + `_start()`. No extra toast. If `buy_world` returns false, do not start a run. `show_doubled` adds the bonus onto the goal's `have` and swaps the bar for this button when that crosses the cost.

## Files

- `scripts/services/economy.gd` — Glacier entry in `WORLD_COST`
- `scripts/services/profile.gd` — `next_goal()` pins Glacier and returns its `id`
- `scripts/ui/screens/results_screen.gd` — landscape row, goal line, unlock button, `show_doubled`
- `scripts/ui/ui_root.gd` — signal for that button
- `scripts/game.gd` — record, buy, select Glacier, start the next run
- `docs/game-design.md` — worlds line
- `README.md` — Glacier row in the worlds table

## Verify

- Fresh profile: Glacier costs 250 on the home screen. Canyon is still 1,500. The upgrades screen still sells level 1 for 150. A few short runs, counting a tier-1 mission, reach 250 in about 2–3 runs.
- Before Glacier is unlocked, the results goal is Glacier even when you could buy an upgrade. After it is unlocked, the line goes back to the cheapest upgrade or world.
- At 1280×720 the goal line and bar sit beside the score and the three numbers, with HOME and RETRY still on screen. Mission rings stay hidden. Portrait still shows the goal under the numbers.
- When Glacier is affordable, UNLOCK GLACIER shows in both orientations. Tapping it spends 250 and the next run is Glacier. RETRY still restarts the world you just played.
- Doubling shards that crosses 250 swaps the bar for UNLOCK GLACIER. Once Glacier is owned and a level is affordable, UPGRADE READY still opens the upgrades screen, including in landscape.

## Outcome

Glacier now costs 250 shards and stays the results goal until it is owned, with a one-tap UNLOCK GLACIER button (including after a double that crosses 250) that records the run, buys it, and starts Glacier. Landscape keeps that goal beside the score. Risk: a wide results card at 1280×720 may still clip on shorter browser chrome; the human check is the Verify list.
