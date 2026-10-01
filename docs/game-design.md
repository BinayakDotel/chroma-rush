# Chroma Rush: game design and balance

What a run should feel like, the numbers behind it, and how the balance was measured. The tuning lives in code: `scripts/pacing.gd` (speed, spacing, waves, fuel), `scripts/powers.gd` (power gems) and `scripts/services/economy.gd` (shards, upgrades, worlds).

## Goals

1. **Calm start.** The first minute teaches, it doesn't test. Nobody should crash out in the first 30 seconds.
2. **Pressure builds in waves.** Tension rises towards each milestone, then releases.
3. **Every death is fair.** There is always time to do what the next row needs. Players blame themselves, not the game.
4. **Mistakes are recoverable.** Missing one fuel pickup costs pressure, not the run.
5. **Always something to chase.** Each run earns shards towards upgrades and worlds, and rare gems make runs memorable.

## What was wrong (October 2026)

Measured with the human-like bot (see [Measuring balance](#measuring-balance)), 12 runs per profile:

| | Casual | Average | Skilled |
| --- | --- | --- | --- |
| Median run | 0.8 min | 0.9 min | 1.2 min |
| Ran out of fuel | 8 of 12 | 11 of 12 | 12 of 12 |

- **Fuel was a slow, certain death.** A full tank lasted 420 m and a pickup added 0.4 tank every 130 to 210 m. Even catching every pickup lost fuel overall, so the tank always ran dry by about 2.4 km. Burn was per metre, so at top speed a full tank lasted only 9.5 seconds.
- **Difficulty peaked after a minute.** Speed rose 0.01 m/s per metre, which compounds over time: top speed (44 m/s) after 100 seconds, and rows 1.05 s apart from about 60 seconds.
- **Spacing ignored what the row needed.** A gate needing two lane changes and a colour switch got the same gap as a gate already in your lane and colour.
- **Everything at once.** Every row type except the hardest was in play from 300 m.
- **Taps lost in Overdrive.** Colour taps during Prism Overdrive were ignored, so a tap for the next gate in Overdrive's last moment caused a crash.
- **Shards had little use.** After a few world unlocks there was nothing to spend them on.

## Run pacing

| Time | Distance | Speed | Difficulty | Row gap (build) | Full tank lasts |
| --- | --- | --- | --- | --- | --- |
| 0:00 | 0 m | 15 m/s | 0.00 | 3.2 s (warm-up) | 32 s |
| 1:00 | 1.1 km | 21 m/s | 0.32 | 2.0 to 2.5 s | 29 s |
| 2:00 | 2.5 km | 26 m/s | 0.59 | 1.7 to 2.1 s | 27 s |
| 4:00 | 6.0 km | 32 m/s | 0.88 | 1.4 to 1.8 s | 25 s |
| 6:00 | 10 km | 35 m/s | 0.97 | 1.2 to 1.5 s (endgame) | 22 s |

- **Speed** eases from 15 towards 36 m/s (`BASE_SPEED + (MAX - BASE) * (1 - e^(-s / 3500))`). It never jumps.
- **Difficulty** eases the same way over 2,800 m. It sets row spacing, which row kinds appear, and fuel.
- **Waves**: every 500 m milestone opens a 100 m breather. Spacing is ×1.8, only easy rows appear, there are more orbs and a fuel pickup is guaranteed. Then spacing tightens from ×1.2 to ×0.95 until the next milestone.
- **Endgame**: from 7 km (about 4.5 minutes) the minimum spacing tightens over the next 6 km, from 0.8 s + 0.28 s per action to 0.62 s + 0.22 s per action, and fuel gets 25% scarcer. Great runs end eventually instead of going on for ever.

### Fair spacing

Each row's gap is the larger of:

- the paced time: `lerp(2.4 s, 1.35 s, difficulty) × wave multiplier`
- the time to act: **0.8 s to read the row + 0.28 s per action** it needs (lane change, colour switch, jump)

Actions are counted from the worst-placed way through the previous row, so every way through is fair (`Pacing.actions_between`).

### Teaching order

| From | New row |
| --- | --- |
| 0 m | Gate wall of one colour, single block |
| 350 m | Hurdles to jump, two-colour gates |
| 900 m | Two blocks, gates with a block |
| 1,300 m | One lane per colour |
| 1,800 m | Hurdles with a block |
| 2,500 m | Gate, block and hurdle in one row |

Breathers and the warm-up only use the first three.

## Fuel

| | Value |
| --- | --- |
| Drain | by time: a full tank lasts 32 s at the start, 24 s at difficulty 1, 20 s in the endgame |
| Pickup | +40% of the tank |
| Regular pickups | every 8.5 s of driving at the start, 7 s later (±20%) |
| Breather pickup | one guaranteed after every 500 m milestone |
| Rescue | below 35% with no pickup in the next 5 s: one is placed 2.5 to 4.5 s ahead, near your lane (at most every 6 s) |
| Empty tank | 2.2 s of coasting; a pickup in that time saves the run |

Catching about two pickups in three keeps the tank level. The rescue means running dry needs several misses in a row.

## Power gems

One every 700 to 1,050 m (from 650 m), placed 4 to 6 seconds ahead in a free lane, with a tall beam in its colour.

| Gem | Shape | Effect | Weight |
| --- | --- | --- | --- |
| Shield | Hexagon | Shrugs off the next crash | 1.0 (0 while one is held) |
| Magnet | Horseshoe | Pulls in orbs from every lane, 8 s | 1.2 |
| Full Tank | Jerrycan | Fills the tank | 1.0 (×3 under half a tank, ×0.3 above 80%) |
| Prism Charge | Triangular prism | Fills the Prism meter (or restarts Overdrive) | 0.9 (0 with the meter above 60%) |
| Phoenix Gem | Cut gem | Banks a free revive for any later run (max 3) | 0.22 (from 1.5 km, while under 3) |

On the results screen, a banked revive is offered before the ad. Either way there is one second chance per run.

## Prism Overdrive

Gates (+12%), hurdles (+6%) and orbs (+5% matching, +2% otherwise) fill the meter. Overdrive lasts 5 s (up to 8 s with upgrades). It gives ×1.25 speed, smashes through everything, uses no fuel, and pulls in orbs from every lane at double shards. That makes it the best moment of a run to collect, worth saving for a long orb line.

## Progression

- **Shards per run**: 1 per orb collected (2 in Overdrive) + 1 per 50 m. A 5-minute run earns roughly 250 to 350.
- **Worlds**: 500 / 1,500 / 3,500 / 6,000 shards.
- **Upgrades**: 150 / 400 / 800 / 1,500 / 2,500 shards per level (5,350 per upgrade, 21,400 for all four).

| Upgrade | Level 0 | Level 5 |
| --- | --- | --- |
| Overdrive | 5 s | 8 s |
| Magnet | 8 s | 14 s |
| Fuel Tank | - | a tank lasts +25% |
| Gem Luck | - | gems (and Phoenix gems) +50% as often |

Purchases (Supporter Pack, World Pass, No Ads) never change difficulty. The Supporter Pack's double shards does reach upgrades faster. Keep shard packs switched off (`live: false`) unless that trade-off is wanted.

## Measuring balance

The dev harness drives the real game with a bot that plays like a person (`--bot=human`). It looks at each row only after passing the previous one, reacts after `--react` seconds (±25%), takes `--action` seconds per swipe or tap, and goes for each fuel pickup with probability `--fuel-skill`. With `--fixed-fps 60` it simulates about 8× faster than real time.

| Profile | react | action | fuel-skill |
| --- | --- | --- | --- |
| Casual | 0.9 s | 0.32 s | 0.65 |
| Average | 0.7 s | 0.25 s | 0.8 |
| Skilled | 0.5 s | 0.18 s | 0.95 |

Results with all of the above, 12 runs per profile, capped at 15 minutes:

| | Casual | Average | Skilled |
| --- | --- | --- | --- |
| Median run | 4.9 min | 7.1 min | 15+ min |
| Shortest run | 2.2 min | 4.5 min | 6.8 min |
| Fuel pickups caught | 50% | 54% | 72% |
| Endings | 6 crashes, 6 fuel | 8 fuel, 2 crashes, 2 survived | 11 survived, 1 fuel |

The bot never misreads a row or taps the wrong colour, so people will have shorter runs than these. Treat the numbers as an upper bound, and compare them between tuning changes.

## Ideas for next

Not built yet, roughly in order of value for retention:

1. **Missions**: three at a time ("pass 40 gates in one run", "collect 2 power gems", "drive 2 km in Glacier"). Each pays shards, and a new one replaces it when done. Gives every run a short-term goal. `Game.run_stats` already counts what they need.
2. **Daily reward streak**: shards for days 1 to 6, and a Phoenix gem on day 7.
3. **Cosmetics for shards**: paint finishes, trails and horns per vehicle. A shard sink that never touches difficulty.
4. **Near-miss bonus**: score and meter for passing a block with a late lane change.
5. **Best-run marker**: a flag at your best distance in each world.
6. **Leaderboards and achievements**: Game Center and Google Play Games.
7. **World modifiers**: ice lanes that delay lane changes in Glacier, lava bursts in Volcano, low gravity in Space. They would make worlds play differently, not just look different.
