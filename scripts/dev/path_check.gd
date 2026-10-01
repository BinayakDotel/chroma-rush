extends SceneTree
## Checks the shape of the generated track over many seeds: how close it comes to itself (it
## must never loop back, or one stretch's scenery lands on another's road), how tight its turns
## get and how far its heading swings. Run with
##   godot --headless --path . -s res://scripts/dev/path_check.gd

func _initialize() -> void:
	var seeds := 40
	var length := 15000
	var near := 0
	var cross := 0
	var worst := INF
	var max_yaw := 0.0
	var max_turn := 0.0
	var tight := 0
	for k in seeds:
		var track: Track = Track.new()
		root.add_child(track)
		track._rng.seed = k * 7919 + 13
		track._turn_noise.seed = k * 7919 + 13
		track._hill_noise.seed = k * 7919 + 20
		track._ensure_samples(float(length))
		var pos: PackedVector3Array = track._pos
		var grid := {}
		var cell := 30.0
		for i in range(0, pos.size(), 2):
			var key := Vector2i(floori(pos[i].x / cell), floori(pos[i].z / cell))
			if not grid.has(key):
				grid[key] = PackedInt32Array()
			grid[key].append(i)
		var seed_near := 0
		var last_hit := -1000
		for i in range(0, pos.size(), 2):
			var key := Vector2i(floori(pos[i].x / cell), floori(pos[i].z / cell))
			var best := INF
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					for j: int in grid.get(key + Vector2i(dx, dz), PackedInt32Array()):
						if j - i > 120:
							var d := pos[i] - pos[j]
							if absf(d.y) < 9.0:
								best = minf(best, Vector2(d.x, d.z).length())
			worst = minf(worst, best)
			if best < 26.0 and i - last_hit > 200:
				seed_near += 1
				last_hit = i
				if best < 8.0:
					cross += 1
		near += seed_near
		for i in range(1, pos.size() - 1):
			var a := pos[i] - pos[i - 1]
			var b := pos[i + 1] - pos[i]
			var turn := absf(Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z)))
			max_turn = maxf(max_turn, turn)
			if turn > 1.0 / 16.0:
				tight += 1
			max_yaw = maxf(max_yaw, absf(atan2(-b.x, -b.z)))
		track.free()
	print("[path] seeds=%d length=%d m  near-approaches(<26 m, |dy|<9)=%d (%.2f per 10 km)  crossings(<8 m)=%d  closest=%.1f m  max turn=%.3f rad/m (R=%.1f m)  metres tighter than R=16: %d  max |heading|=%.0f deg" % [
		seeds, length, near, near * 10000.0 / (seeds * length), cross, worst, max_turn, 1.0 / max_turn, tight, rad_to_deg(max_yaw)])
	quit()
