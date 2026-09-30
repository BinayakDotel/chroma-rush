class_name Defs
## Shared gameplay constants and tuning.

const LANES := 3
const LANE_WIDTH := 2.4

# Obstacle cell types. 0..2 are colour gates matching Defs.colors.
const EMPTY := -1
const SOLID := 3
const LOW := 4

## The three gate colours for the current theme (set from Themes when a theme is applied).
static var colors: Array[Color] = [Color(0.9, 0.12, 0.18), Color(0.0, 0.6, 0.6), Color(0.5, 0.18, 0.85)]

const BASE_SPEED := 16.0
const MAX_SPEED := 44.0
const SPEED_RAMP := 0.01  # m/s gained per metre travelled


static func lane_x(lane: int) -> float:
	return (lane - 1) * LANE_WIDTH


static func speed_at(distance: float) -> float:
	return minf(BASE_SPEED + distance * SPEED_RAMP, MAX_SPEED)


static func difficulty(distance: float) -> float:
	return clampf(distance / 2500.0, 0.0, 1.0)
