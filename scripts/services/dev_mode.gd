class_name DevMode
## True when the game is running inside the developer harness (scripts/dev/dev.tscn) in a
## debug build. Saves and settings then go to user://dev so tests never touch real progress.


static func active() -> bool:
	return OS.is_debug_build() and "res://scripts/dev/dev.tscn" in OS.get_cmdline_args()
