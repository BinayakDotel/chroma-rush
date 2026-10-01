class_name Pacing
## How a run builds up: speed, difficulty, the calm-then-build waves, how far apart obstacle
## rows are, which kinds of rows can appear, and the fuel economy. Everything here is a pure
## function of the distance travelled, so the track generator and the game agree. Tune here;
## docs/game-design.md explains the targets behind these numbers.

## Forward speed in m/s eases from BASE towards MAX: about 63% of the way after SPEED_SCALE
## metres (roughly 2.5 minutes), 90% after about 6 minutes. It never jumps.
const BASE_SPEED := 15.0
const MAX_SPEED := 36.0
const SPEED_SCALE := 3500.0

## Difficulty 0..1 eases in the same way: about 0.3 at 1 km, 0.6 at 2.5 km, 0.85 at 5 km.
const DIFFICULTY_SCALE := 2800.0

## Relaxed spacing for the first metres of a run while the player settles in.
const WARM_UP := 250.0
const WARM_UP_SPACING := 1.35

## Waves: every WAVE metres (the "500 m!" milestones) a breather starts. For BREATHER metres
## rows are far apart and easy, and a fuel pickup is guaranteed; then the spacing tightens
## steadily until the next milestone.
const WAVE := 500.0
const BREATHER := 100.0
const BREATHER_SPACING := 1.8
const BUILD_SPACING := Vector2(1.2, 0.95)  # spacing multiplier at the start / end of a build

## Seconds between obstacle rows at difficulty 0 and 1, before the wave multiplier.
const ROW_TIME := Vector2(2.4, 1.35)
## Rows are never closer than this: time to read the row, plus time for each action (lane
## change, colour switch, jump) the next row needs after the previous one.
const REACT_TIME := 0.8
const ACTION_TIME := 0.28
## Endgame: from ENDGAME_FROM metres (about 4.5 minutes in) the minimum spacing tightens over
## the next ENDGAME_SCALE metres towards what only quick players manage, and fuel gets a little
## scarcer, so even great runs end in the end, instead of going on for ever.
const ENDGAME_FROM := 7000.0
const ENDGAME_SCALE := 6000.0
const ENDGAME_REACT := 0.62
const ENDGAME_ACTION := 0.22
const ENDGAME_ROW_TIME := 1.15
const ENDGAME_TANK_TIME := 24.0
## Fuel pickups get rarer through the endgame and keep getting rarer after it (this much more
## spacing per ENDGAME_SCALE metres), so in the end no tank is big enough.
const ENDGAME_FUEL_SCARCITY := 0.45
const MAX_FUEL_SCARCITY := 2.5
## Generation never needs more than this between rows (metres).
const MAX_GAP := 160.0

## Fuel drains with time, not distance, so going faster doesn't secretly empty the tank
## faster. A full tank lasts TANK_TIME seconds at difficulty 0 and 1.
##
## The economy is a few big pickups, not a stream of small ones. Each is worth nearly half a
## tank, and every one is fair to collect: it sits in a lane that is open in the next row, far
## enough along for the lane changes (see fuel_lead). Because they can all be caught, the
## pressure comes from how many may be missed: half of them in the first kilometre, a third
## by 2 km, one in six by 5 km, and none from about 8 km, after which every tank runs down.
## The Fuel Tank upgrade moves each of those marks out by a fifth.
const TANK_TIME := Vector2(40.0, 30.0)
## Fuel added by a pickup (fraction of the tank).
const FUEL_PICKUP := 0.4
## Seconds of driving between fuel pickups at difficulty 0 and 1 (randomised +-15%). The one
## nearest each milestone moves into that milestone's breather.
const FUEL_TIME := Vector2(9.0, 12.8)
const FUEL_JITTER := 0.15
## Seconds a player needs after everything else to settle before the row behind a pickup.
const FUEL_SETTLE := 0.25
## Last resort, and rare: with the tank nearly empty and no pickup reachable before it runs
## dry, a fuel drop lands a few seconds ahead. It holds less than a pickup, lands in any open
## lane (not the player's), and after one there is a long wait before another can come.
const DROP_BELOW := 0.14
const DROP_AHEAD := Vector2(3.0, 4.6)  # seconds ahead that the drop lands
const DROP_FUEL := 0.3
const DROP_COOLDOWN := 45.0

## Row patterns. Cells: 0..2 colour gates, Defs.SOLID block, Defs.LOW hurdle, Defs.EMPTY.
## "from": first metre the pattern can appear (teach one idea at a time); "weight": how common
## it is at difficulty 0 and 1; "calm": allowed in warm-up and breathers.
enum Row { WALL, BLOCK, HURDLES, TWO_COLOURS, TWO_BLOCKS, GATES_AND_BLOCK, RAINBOW, HURDLES_AND_BLOCK, MIXED }
const ROWS := {
	Row.WALL: {"from": 0.0, "weight": Vector2(3.0, 1.2), "calm": true},
	Row.BLOCK: {"from": 0.0, "weight": Vector2(2.5, 0.8), "calm": true},
	Row.HURDLES: {"from": 350.0, "weight": Vector2(1.5, 0.8), "calm": true},
	Row.TWO_COLOURS: {"from": 350.0, "weight": Vector2(1.5, 1.8), "calm": false},
	Row.TWO_BLOCKS: {"from": 900.0, "weight": Vector2(0.8, 1.4), "calm": false},
	Row.GATES_AND_BLOCK: {"from": 900.0, "weight": Vector2(1.0, 1.8), "calm": false},
	Row.RAINBOW: {"from": 1300.0, "weight": Vector2(1.0, 2.2), "calm": false},
	Row.HURDLES_AND_BLOCK: {"from": 1800.0, "weight": Vector2(0.8, 1.4), "calm": false},
	Row.MIXED: {"from": 2500.0, "weight": Vector2(0.5, 1.8), "calm": false},
}


static func speed_at(s: float) -> float:
	return BASE_SPEED + (MAX_SPEED - BASE_SPEED) * (1.0 - exp(-maxf(s, 0.0) / SPEED_SCALE))


static func difficulty(s: float) -> float:
	return 1.0 - exp(-maxf(s, 0.0) / DIFFICULTY_SCALE)


## 0 until the endgame starts, rising to 1 over ENDGAME_SCALE metres.
static func endgame(s: float) -> float:
	return clampf((s - ENDGAME_FROM) / ENDGAME_SCALE, 0.0, 1.0)


## True during the calm stretch after each milestone (and the warm-up).
static func is_calm(s: float) -> bool:
	return s < WARM_UP or fmod(s, WAVE) < BREATHER


## Which wave a distance is in; the breather at its start has the guaranteed fuel.
static func wave_index(s: float) -> int:
	return floori(s / WAVE)


## Spacing multiplier from the wave: wide in breathers, tightening through each build.
static func wave_spacing(s: float) -> float:
	if s < WARM_UP:
		return WARM_UP_SPACING
	var phase := fmod(s, WAVE)
	if phase < BREATHER:
		return BREATHER_SPACING
	return lerpf(BUILD_SPACING.x, BUILD_SPACING.y, (phase - BREATHER) / (WAVE - BREATHER))


## Seconds to read a row, and seconds per action (lane change, colour switch, jump), at `s`.
static func react_time(s: float) -> float:
	return lerpf(REACT_TIME, ENDGAME_REACT, endgame(s))


static func action_time(s: float) -> float:
	return lerpf(ACTION_TIME, ENDGAME_ACTION, endgame(s))


## Metres from the previous row (at `s`) to the next one, which needs `actions` actions, and
## never less than `min_seconds` of driving.
static func row_gap(s: float, actions: int, min_seconds := 0.0) -> float:
	var row_time := lerpf(ROW_TIME.x, lerpf(ROW_TIME.y, ENDGAME_ROW_TIME, endgame(s)), difficulty(s))
	var seconds := row_time * wave_spacing(s)
	seconds = maxf(seconds, react_time(s) + action_time(s) * actions)
	return minf(maxf(seconds, min_seconds) * speed_at(s), MAX_GAP)


static func tank_time(s: float) -> float:
	return lerpf(lerpf(TANK_TIME.x, TANK_TIME.y, difficulty(s)), ENDGAME_TANK_TIME, endgame(s))


## Metres to the next fuel pickup, given a random roll in -1..1.
static func fuel_spacing(s: float, roll: float) -> float:
	var scarcity := minf(1.0 + ENDGAME_FUEL_SCARCITY * maxf(s - ENDGAME_FROM, 0.0) / ENDGAME_SCALE, MAX_FUEL_SCARCITY)
	return lerpf(FUEL_TIME.x, FUEL_TIME.y, difficulty(s)) * scarcity * (1.0 + FUEL_JITTER * roll) * speed_at(s)


## Seconds after a row before a fuel pickup `lane_changes` lanes away can fairly be reached:
## time to see it, then one action per lane.
static func fuel_lead(s: float, lane_changes: int) -> float:
	return react_time(s) + action_time(s) * lane_changes


## Pattern weight at a distance: 0 before it is introduced, and only calm rows in a breather.
static func row_weight(row: Row, s: float) -> float:
	var spec: Dictionary = ROWS[row]
	if s < float(spec.from) or (is_calm(s) and not spec.calm):
		return 0.0
	var w: Vector2 = spec.weight
	return lerpf(w.x, w.y, difficulty(s))


## The ways through a row: [{lane, color (-1 = any), jump}]. Blocks have no way through.
static func row_options(cells: Array) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for lane in cells.size():
		var cell: int = cells[lane]
		if cell == Defs.SOLID:
			continue
		var gate := cell >= 0 and cell <= 2
		options.append({"lane": lane, "color": cell if gate else -1, "jump": cell == Defs.LOW})
	return options


## What it takes to collect a pickup in `lane` between `prev` and `next` and then go through
## `next` in that same lane, from the worst-placed way through `prev`:
## {lane_changes (to reach the pickup), actions (those plus the colour switch or jump after)}.
static func actions_via(prev: Array[Dictionary], next: Array[Dictionary], lane: int) -> Dictionary:
	var through := {}
	for n in next:
		if int(n.lane) == lane:
			through = n
	var lane_changes := 0
	var actions := 0
	for p in prev:
		var changes := absi(lane - int(p.lane))
		var cost := changes
		if not through.is_empty():
			if int(through.color) >= 0 and int(through.color) != int(p.color):
				cost += 1
			if through.jump:
				cost += 1
		lane_changes = maxi(lane_changes, changes)
		actions = maxi(actions, cost)
	return {"lane_changes": lane_changes, "actions": actions}


## Actions needed to get through `next` after passing `prev`, assuming the player came
## through whichever way of `prev` leaves them worst placed (so every way through is fair).
static func actions_between(prev: Array[Dictionary], next: Array[Dictionary]) -> int:
	if prev.is_empty() or next.is_empty():
		return 0
	var worst := 0
	for p in prev:
		var best := 99
		for n in next:
			var cost := absi(int(n.lane) - int(p.lane))
			if int(n.color) >= 0 and int(n.color) != int(p.color):
				cost += 1
			if n.jump:
				cost += 1
			best = mini(best, cost)
		worst = maxi(worst, best)
	return worst
