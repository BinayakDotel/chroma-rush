# Chroma Rush: game design and balance

What a run should feel like, the numbers behind it, and how the balance was measured. The tuning lives in code: `scripts/pacing.gd` (speed, spacing, waves, fuel), `scripts/powers.gd` (power gems), `scripts/services/economy.gd` (shards, upgrades, worlds) and `scripts/services/missions.gd` (missions). The look is described at the end, under [Look and feel](#look-and-feel).

## Goals

1. **Calm start.** The first minute teaches, it doesn't test. Nobody should crash out in the first 30 seconds.
2. **Pressure builds in waves.** Tension rises towards each milestone, then releases.
3. **Every death is fair.** There is always time to do what the next row needs. Players blame themselves, not the game.
4. **Mistakes are recoverable.** Missing one fuel pickup costs pressure, not the run.
5. **Always something to chase.** Each run earns shards towards upgrades and worlds, missions give it a short-term goal, and rare gems make runs memorable.
6. **Upgrades are felt.** The game is fair without them, but an upgrade visibly lengthens runs.

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
| 0:00 | 0 m | 15 m/s | 0.00 | 3.2 s (warm-up) | 40 s |
| 1:00 | 1.1 km | 21 m/s | 0.32 | 2.0 to 2.5 s | 37 s |
| 2:00 | 2.5 km | 26 m/s | 0.59 | 1.7 to 2.1 s | 34 s |
| 4:00 | 6.0 km | 32 m/s | 0.88 | 1.4 to 1.8 s | 31 s |
| 6:00 | 10 km | 35 m/s | 0.97 | 1.2 to 1.5 s (endgame) | 27 s |

- **Speed** eases from 15 towards 36 m/s (`BASE_SPEED + (MAX - BASE) * (1 - e^(-s / 3500))`). It never jumps.
- **Difficulty** eases the same way over 2,800 m. It sets row spacing, which row kinds appear, and fuel.
- **Waves**: every 500 m milestone opens a 100 m breather. Spacing is ×1.8, only easy rows appear, there are more orbs and there is a fuel pickup. Then spacing tightens from ×1.2 to ×0.95 until the next milestone.
- **Endgame**: from 7 km (about 4.5 minutes) the minimum spacing tightens over the next 6 km, from 0.8 s + 0.28 s per action to 0.62 s + 0.22 s per action. A tank lasts less (down to 24 s) and fuel pickups get steadily rarer (45% more spacing per 6 km, and it keeps growing), so every run ends in the end.

### Track shape

The path is built from smooth noise: turns of up to 0.055 rad/m, hills, and banking into turns. Its heading is kept within about 60° of straight ahead: past 31° (0.55 rad), turning further out is damped, reaching zero at 60° (1.05 rad). Without that limit the track could turn back and pass close to, or through, an earlier stretch, which put one stretch's ground and cliffs on top of another's road.

| 600 km of generated track (40 seeds × 15 km) | Before | After |
| --- | --- | --- |
| Stretches passing within 26 m of another at a similar height | 270 (4.5 per 10 km) | 0 |
| Of those, crossings (within 8 m) | 17 | 0 |
| Furthest heading from straight ahead | 180° | 59° |

`godot --headless --path . -s res://scripts/dev/path_check.gd` repeats the measurement.

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

Fuel is the pressure that builds over a run, and the thing the Fuel Tank upgrade relieves. It works as a few big pickups, each one fair to collect.

| | Value |
| --- | --- |
| Drain | by time: a full tank lasts 40 s at the start, 30 s at difficulty 1, 24 s in the endgame. Prism Overdrive burns none. |
| Pickup | +36% of the tank |
| Spacing | one about every 7.5 s of driving at the start, 12.6 s at difficulty 1 (±15%), further apart through the endgame. The one nearest each 500 m milestone moves into its breather. |
| Fair placement | in a lane that is open in the next row, at least 0.8 s + 0.28 s per lane change after the previous row. The next row moves back if the detour needs more time. |
| Fuel drop | below 14%, with no pickup reachable before the tank runs dry: a drop worth 25% lands 3 to 4.6 s ahead (nearer if the tank would not last that long) in another open lane, announced with "FUEL DROP!". At most one every 45 s and three per run. |
| Empty tank | 2.2 s of coasting; a pickup in that time saves the run |

How many pickups can be missed, from pickups alone: about half at the start, one in three by 1 km, one in seven by 2.5 km. From about 4 km the tank slowly runs down however well the player collects; Overdrive and Full Tank gems stretch it. With the Fuel Tank upgrade at level 5 each of those marks is a fifth easier.

**What changed in the polish pass, and why.** A pickup used to be placed in the player's own lane whenever the tank fell below 35%. Measured over 12 bot runs per profile, that happened 1.2 times a minute for a casual player (13% of all pickups), and it could be seen appearing. It existed because regular pickups were often not collectable: they sat mid-gap in a random lane, which could be blocked in the next row or too far away, so even the skilled bot caught only 71% of them. Now every pickup is collectable, so the rescue can be rare:

| | Casual | Average | Skilled |
| --- | --- | --- | --- |
| Pickups on the road per minute, before → after | 9.4 → 5.2 | 9.6 → 4.9 | 9.2 → 4.5 |
| Pickups caught, before → after | 44% → 72% | 55% → 88% | 71% → 96% |
| Rescues / fuel drops per minute, before → after | 1.18 → 0.22 | 0.80 → 0.18 | 0.20 → 0.14 |

## Power gems

One every 700 to 1,050 m (from 650 m), placed 4 to 6 seconds ahead in a lane that is open in the next row, with a tall beam in its colour.

| Gem | Shape | Effect | Weight |
| --- | --- | --- | --- |
| Shield | Hexagon | Shrugs off the next crash | 1.0 (0 while one is held) |
| Magnet | Horseshoe | Pulls in orbs from every lane, 8 s | 1.2 |
| Full Tank | Jerrycan | Fills the tank | 1.0 (×1.6 under half a tank, ×0.3 above 80%) |
| Prism Charge | Triangular prism | Fills the Prism meter (or restarts Overdrive) | 0.9 (0 with the meter above 60%) |
| Phoenix Gem | Cut gem | Banks a free revive for any later run (max 3) | 0.22 (from 1.5 km, while under 3) |

On the results screen, a banked revive is offered before the ad. Either way there is one second chance per run.

## Prism Overdrive

Gates (+12%), hurdles (+6%) and orbs (+5% matching, +2% otherwise) fill the meter. Overdrive lasts 5 s (up to 8 s with upgrades). It gives ×1.25 speed, smashes through everything, uses no fuel, and pulls in orbs from every lane at double shards. That makes it the best moment of a run to collect, worth saving for a long orb line.

## Progression

- **Shards per run**: 1 per orb collected (2 in Overdrive) + 1 per 50 m. A 5-minute run earns roughly 250 to 350.
- **Missions**: three at a time, 60 to 200 shards each (see below).
- **Worlds**: 250 / 1,500 / 3,500 / 6,000 shards.
- **Upgrades**: 150 / 400 / 800 / 1,500 / 2,500 shards per level (5,350 per upgrade, 21,400 for all four).

| Upgrade | Level 0 | Level 5 |
| --- | --- | --- |
| Overdrive | 5 s | 8 s |
| Magnet | 8 s | 14 s |
| Fuel Tank | - | a tank lasts +25% |
| Gem Luck | - | gems (and Phoenix gems) +50% as often |

The results screen always shows what the shards are building towards: how many more are needed for the cheapest upgrade or world, or that it can be afforded now.

Purchases (Supporter Pack, World Pass, No Ads) never change difficulty. The Supporter Pack's double shards does reach upgrades faster, and doubles mission rewards. Keep shard packs switched off (`live: false`) unless that trade-off is wanted.

### Missions

Three goals at a time, so every run has something to aim for besides the score. A mission pays the moment it is completed, with a "MISSION COMPLETE!" call-out in the run, and a new one takes its place when the run ends. No two active missions count the same thing.

| Mission | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
| --- | --- | --- | --- | --- |
| Pass gates in one run | 15 | 30 | 50 | 80 |
| Drive in one run | 800 m | 1,500 m | 3,000 m | 5,000 m |
| Collect orbs in one run | 20 | 40 | 70 | 110 |
| Jump hurdles in one run | 3 | 6 | 10 | 16 |
| Collect orbs (in total) | 60 | 140 | 260 | 420 |
| Pick up fuel | 5 | 10 | 18 | 28 |
| Collect power gems | 2 | 4 | 6 | 10 |
| Smash obstacles in Overdrive | 3 | 8 | 16 | 30 |
| Use Prism Overdrive | 2 | 4 | 6 | 10 |
| Drive (in total) | 3 km | 6 km | 12 km | 20 km |
| Reward | 60 | 100 | 150 | 200 |

The tier goes up after every three missions completed. Tier 1 missions fit in a first or second run, so a new player earns the first upgrade (150 shards) within a few runs.

## Measuring balance

The dev harness drives the real game with a bot that plays like a person (`--bot=human`). It looks at each row only after passing the previous one, reacts after `--react` seconds (±25%), takes `--action` seconds per swipe or tap, and goes for each fuel pickup with probability `--fuel-skill`. With `--fixed-fps 60` it simulates about 8× faster than real time.

| Profile | react | action | fuel-skill |
| --- | --- | --- | --- |
| Casual | 0.9 s | 0.32 s | 0.65 |
| Average | 0.7 s | 0.25 s | 0.8 |
| Skilled | 0.5 s | 0.18 s | 0.95 |

Results, 12 runs per profile, capped at 15 minutes. "Inattentive" is the casual profile with a fuel-skill of 0.4 (8 runs):

| No upgrades | Inattentive | Casual | Average | Skilled |
| --- | --- | --- | --- | --- |
| Median run | 4.4 min | 6.0 min | 8.4 min | 12.0 min |
| Shortest run | 1.8 min | 3.3 min | 6.1 min | 8.2 min |
| Fuel pickups caught | 58% | 72% | 88% | 96% |
| Fuel drops per minute | 0.28 | 0.22 | 0.18 | 0.14 |
| Endings | 8 fuel | 7 fuel, 5 crashes | 12 fuel | 12 fuel |

| Fuel Tank at level 5 | Inattentive | Casual | Average | Skilled |
| --- | --- | --- | --- | --- |
| Median run | 8.1 min | 7.5 min | 12.2 min | 13.2 min |
| Change | +84% | +25% | +45% | +10% |

So nobody runs dry early, every run ends in the end (the skilled bot used to survive the full 15 minutes in 11 runs of 12), and the upgrade is worth minutes. No run used more than its three fuel drops; the average was 1.5.

The bot never misreads a row or taps the wrong colour, so people will have shorter runs than these, and more of them will end in a crash. Treat the numbers as an upper bound, and compare them between tuning changes.

## Look and feel

The art is low-poly, but it should read as a modern, soft, toy-like game, not as an old one. The rules:

- **No dark outlines.** Shapes are separated by light: a rim of light around silhouettes, glow, and soft shadows on the road. Gems, pickups, gate panels and lane marks have no outline.
- **One soft surface** (`shaders/soft.gdshader`, set up in `scripts/look.gd`) for scenery, obstacles, vehicles and drivers: a short smooth step from lit to shaded, less ambient light on faces that point down, and a rim light in each world's own colour. Paint adds one crisp highlight.
- **Moulded, not stacked.** Vehicles, drivers and pickups are built from smooth shapes (lofted shells, rounded boxes, lathes, bent pipes; see `scripts/mesh_kit.gd`). Scenery stays faceted on purpose: rocks should look chiselled.
- **A calm road.** One colour with soft shoulders and low kerbs, light dashes between lanes that only mark them, and a thin edge line in the player's colour. The current colour also glows on the road under the vehicle.
- **Gates are tinted glass** with a glowing rim and a white symbol over a soft shadow.
- **Linear tone mapping and soft bloom**, so the authored colours stay vivid and bright things glow.
- **Motion on springs.** The wheels stay on the road; the body above them leans into lane changes, squashes on landing and pops on a colour change, all as spring impulses. Nothing snaps, blinks or buzzes.

### Interface

- **Icons support words; they do not replace them.** Buttons and call-outs carry an icon and a short label. A pass that replaced the labels with symbols alone was tried and undone: without the words the buttons and call-outs were not understandable.
- **The score is the hero.** The results screen is a scoreboard, not a form: the score straight on the scene, one card with three numbers, the missions as rings and one line for what the shards are building towards, then at most one row of offers and RETRY.
- **Actions in thumb reach.** The home screen keeps shards and settings in the top corners and puts MISSIONS, UPGRADES, SHOP and PLAY at the bottom.
- **Readable.** Body text is bold (Nunito 700 to 900) and nothing is smaller than 18 canvas pixels, about 9 pt on a phone. Numbers that matter use the title font.
- **Lists scroll from anywhere.** A list built with `UiScreen.scroll_list()` scrolls when dragged by a row or a button, not only by the gaps (see `UiKit.pass_touches`); a 12 px dead zone keeps taps from nudging it. Overlays that are a card of options close on a tap outside the card, and cards pop in.
- **The brand shows the vehicle and its driver**, so the game reads as a racer, not a block puzzle. `scripts/dev/render_icons.gd` renders the fox in its kart from the real model and builds everything from it: the logo (white CHROMA on a deep lip, then RUSH leaning forward beside the kart, which trails the three gate colours; `scripts/ui/logo.gd`), the app icon (the kart racing out of a three-colour trail) and the splash.
- **No hard cut at launch, and one picture throughout.** The boot splash is the icon's picture at full screen (the same sky, colour trail and kart) with the logo above it, cropped to cover any screen. A flat colour with a logo on it was tried first and read as cheap and unrelated to the game. The game opens on a cover showing that same picture and fades it away to show the home screen.

### Performance

Measured in Meadow on the desktop renderer, portrait, about four samples each:

| | Before | After |
| --- | --- | --- |
| Draw calls per frame | 190 to 277 | 168 to 274 |
| Triangles per frame | 37k to 74k | 58k to 85k |
| Shadow maps drawn (High / Medium) | 4 / 4 | 2 / 1 |
| Worst script frame over 12 km | 2.1 ms | 1.3 ms |
| Memory growth over 12 km | none | none |

Smooth shapes cost more triangles (still small for a phone); fewer shadow maps and scenery that is not drawn beyond its range pay for them. Every mesh is generated once and shared; smooth meshes are indexed. `--perf` in the dev harness prints the frame-time percentiles, and its memory lines include draw calls and triangles.

## Ideas for next

Not built yet, roughly in order of value for retention:

1. **Daily reward streak**: shards for days 1 to 6, and a Phoenix gem on day 7.
2. **Cosmetics for shards**: paint finishes, trails and horns per vehicle. A shard sink that never touches difficulty.
3. **Near-miss bonus**: score and meter for passing a block with a late lane change.
4. **Best-run marker**: a flag at your best distance in each world.
5. **World missions**: "drive 2 km in Glacier", once the mission system knows which worlds are unlocked.
6. **Leaderboards and achievements**: Game Center and Google Play Games.
7. **World modifiers**: ice lanes that delay lane changes in Glacier, lava bursts in Volcano, low gravity in Space. They would make worlds play differently, not just look different.
