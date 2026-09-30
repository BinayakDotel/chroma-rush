class_name Sfx
extends Node
## Sound effects and a looping synthwave track, all synthesised at startup. Effects play on the
## "SFX" bus and music on the "Music" bus, so the Settings volumes apply to each separately.

const RATE := 22050
const BPM := 128.0

## The game's audio node, so UI code can play a click without holding a reference.
static var instance: Sfx

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music := AudioStreamPlayer.new()


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sounds["switch"] = _tone(520.0, 780.0, 0.07, "square", 0.22)
	_sounds["gate"] = _tone(700.0, 1400.0, 0.16, "sine", 0.45)
	_sounds["orb"] = _tone(1600.0, 2200.0, 0.08, "sine", 0.28)
	_sounds["jump"] = _tone(260.0, 620.0, 0.14, "square", 0.18)
	_sounds["land"] = _tone(180.0, 60.0, 0.12, "sine", 0.5, 0.3)
	_sounds["lane"] = _tone(900.0, 500.0, 0.05, "sine", 0.12, 0.6)
	_sounds["smash"] = _tone(300.0, 80.0, 0.25, "square", 0.35, 0.7)
	_sounds["crash"] = _tone(220.0, 30.0, 0.8, "saw", 0.6, 0.8)
	_sounds["prism"] = _tone(200.0, 1800.0, 0.9, "saw", 0.3, 0.1)
	_sounds["start"] = _tone(400.0, 1200.0, 0.3, "square", 0.2)
	_sounds["fuel"] = _tone(300.0, 1100.0, 0.25, "sine", 0.45, 0.1)
	_sounds["warn"] = _tone(880.0, 700.0, 0.25, "square", 0.18)
	_sounds["sputter"] = _tone(140.0, 45.0, 0.6, "square", 0.3, 0.45)
	_sounds["click"] = _tone(900.0, 1300.0, 0.05, "sine", 0.3)
	_sounds["coin"] = _tone(1200.0, 1900.0, 0.12, "square", 0.14)
	_sounds["unlock"] = _tone(400.0, 1600.0, 0.5, "square", 0.22)
	_sounds["revive"] = _tone(250.0, 1400.0, 0.6, "sine", 0.45, 0.05)
	for i in 10:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)
	_music.stream = _build_music()
	_music.volume_db = -8.0
	_music.bus = &"Music"
	add_child(_music)
	_music.play()


static func click() -> void:
	if is_instance_valid(instance):
		instance.play("click", 1.0, -8.0)


## Softens the music while paused or in menus layered over a run.
func duck(on: bool) -> void:
	var tween := create_tween()
	tween.tween_property(_music, "volume_db", -18.0 if on else -8.0, 0.25)


func play(sound: StringName, pitch := 1.0, volume_db := 0.0) -> void:
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _sounds[sound]
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()


func _tone(f0: float, f1: float, length: float, wave: String, volume: float, noise := 0.0) -> AudioStreamWAV:
	var count := int(length * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		phase += lerpf(f0, f1, t) / RATE
		var x := fposmod(phase, 1.0)
		var v: float
		match wave:
			"square":
				v = 1.0 if x < 0.5 else -1.0
			"saw":
				v = x * 2.0 - 1.0
			_:
				v = sin(x * TAU)
		v = lerpf(v, rng.randf_range(-1.0, 1.0), noise)
		var envelope := minf(1.0, i / (0.004 * RATE)) * (1.0 - t) * (1.0 - t)
		data.encode_s16(i * 2, int(clampf(v * envelope * volume, -1.0, 1.0) * 32767.0))
	return _wav(data, false)


## Four bars of Am - F - C - G: kick, offbeat hats, pumping bass and an arpeggio.
func _build_music() -> AudioStreamWAV:
	var beat_len := 60.0 / BPM
	var step_len := beat_len / 4.0
	var count := int(RATE * beat_len * 16.0)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var roots := [110.0, 87.31, 130.81, 98.0]
	var thirds := [3, 4, 4, 4]
	var arp := [0, 1, 2, 1]
	var bass_phase := 0.0
	var lead_phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var beat := int(t / beat_len)
		var tb := t - beat * beat_len
		var step := int(t / step_len)
		var ts := t - step * step_len
		var bar := (beat / 4) % 4
		var root: float = roots[bar]

		var kick_phase := 45.0 * tb + 3.0 * (1.0 - exp(-tb * 30.0))
		var kick := sin(kick_phase * TAU) * exp(-tb * 9.0)

		var hat := 0.0
		var t8 := fmod(t, beat_len * 0.5)
		if int(t / (beat_len * 0.5)) % 2 == 1:
			hat = rng.randf_range(-1.0, 1.0) * exp(-t8 * 50.0)

		bass_phase += root * (2.0 if step % 4 == 2 else 1.0) / RATE
		var bass := (fposmod(bass_phase, 1.0) * 2.0 - 1.0) * exp(-ts * 10.0)

		var semis: int = [0, thirds[bar], 7][arp[step % 4]]
		lead_phase += root * 4.0 * pow(2.0, semis / 12.0) / RATE
		var lead := (1.0 if fposmod(lead_phase, 1.0) < 0.5 else -1.0) * exp(-ts * 14.0)

		var sidechain := 1.0 - 0.7 * exp(-tb * 8.0)
		var mix := kick * 0.55 + hat * 0.07 + (bass * 0.22 + lead * 0.06) * sidechain
		data.encode_s16(i * 2, int(clampf(mix, -1.0, 1.0) * 32000.0))
	return _wav(data, true)


func _wav(data: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = data.size() / 2
	return wav
