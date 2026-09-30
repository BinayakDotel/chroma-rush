class_name Defs
## Shared gameplay constants and tuning.

const LANES := 3
const LANE_WIDTH := 2.4

# Obstacle cell types. 0..2 are colour gates matching Defs.COLORS.
const EMPTY := -1
const SOLID := 3
const LOW := 4

## The three gate colours, the same in every world so players learn them once: red, yellow and
## deep blue. Chosen for separation for all viewers: minimum CIEDE2000 difference of 44 with
## normal vision and 26+ under simulated protanopia, deuteranopia and tritanopia, and at least
## 12 against every world's road, sky and ground. Each colour also has its own shape.
const COLORS: Array[Color] = [Color(0.9, 0.12, 0.2), Color(1.0, 0.84, 0.1), Color(0.1, 0.3, 0.9)]
const COLOR_NAMES: Array[String] = ["RED", "YELLOW", "BLUE"]
## Shape per colour slot, drawn on gates, orbs and the colour buttons.
enum Symbol { CIRCLE, TRIANGLE, SQUARE }
const SYMBOLS: Array[int] = [Symbol.CIRCLE, Symbol.TRIANGLE, Symbol.SQUARE]

const BASE_SPEED := 16.0
const MAX_SPEED := 44.0
const SPEED_RAMP := 0.01  # m/s gained per metre travelled


static func lane_x(lane: int) -> float:
	return (lane - 1) * LANE_WIDTH


static func speed_at(distance: float) -> float:
	return minf(BASE_SPEED + distance * SPEED_RAMP, MAX_SPEED)


static func difficulty(distance: float) -> float:
	return clampf(distance / 2500.0, 0.0, 1.0)


## Dark variant of a gate colour for outlines and pressed states.
static func shade(index: int, amount := 0.45) -> Color:
	return COLORS[index].darkened(amount)
