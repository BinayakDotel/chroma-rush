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


## True on phones and tablets, including in a browser, where OS.has_feature("mobile") is false.
## Decides touch hints over keyboard hints and the lighter graphics defaults.
static func touch_device() -> bool:
	return (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
		or DevMode.touch())


static func lane_x(lane: int) -> float:
	return (lane - 1) * LANE_WIDTH


## Dark variant of a gate colour for outlines and pressed states.
static func shade(index: int, amount := 0.45) -> Color:
	return COLORS[index].darkened(amount)
