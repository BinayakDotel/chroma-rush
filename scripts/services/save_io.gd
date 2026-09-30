class_name SaveIO
## Crash-safe config writes: save to a temporary file, then swap it into place, so a crash or
## a killed app mid-write never leaves a truncated save behind.


static func write(cfg: ConfigFile, path: String) -> bool:
	var tmp := path + ".tmp"
	if cfg.save(tmp) != OK:
		push_warning("Could not write %s" % tmp)
		return false
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		# Some platforms refuse to rename over an existing file; fall back to replacing it.
		DirAccess.remove_absolute(path)
		err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_warning("Could not replace %s (error %d)" % [path, err])
		return false
	return true


## Loads `path`, falling back to a leftover temporary file if the swap never happened.
static func read(cfg: ConfigFile, path: String) -> bool:
	if cfg.load(path) == OK:
		return true
	return FileAccess.file_exists(path + ".tmp") and cfg.load(path + ".tmp") == OK
