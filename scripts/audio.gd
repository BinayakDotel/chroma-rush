class_name Sfx
extends Node
## Sound effects and the looping music track, recorded CC0 sounds made by tools/build_audio.py
## (sources in audio/LICENSES.md). Effects play on the "SFX" bus and music on the "Music" bus,
## so the Settings volumes apply to each separately.

## Music level under the effects (the files are levelled to -16 LUFS effects, -20 LUFS music),
## and how far it drops while paused or behind a menu.
const MUSIC_DB := -4.0
const DUCKED_DB := -14.0
const SOUNDS: Dictionary[StringName, AudioStream] = {
	&"switch": preload("res://audio/switch.wav"),
	&"gate": preload("res://audio/gate.wav"),
	&"orb": preload("res://audio/orb.wav"),
	&"jump": preload("res://audio/jump.wav"),
	&"land": preload("res://audio/land.wav"),
	&"lane": preload("res://audio/lane.wav"),
	&"smash": preload("res://audio/smash.wav"),
	&"crash": preload("res://audio/crash.wav"),
	&"prism": preload("res://audio/prism.wav"),
	&"start": preload("res://audio/start.wav"),
	&"fuel": preload("res://audio/fuel.wav"),
	&"warn": preload("res://audio/warn.wav"),
	&"sputter": preload("res://audio/sputter.wav"),
	&"click": preload("res://audio/click.wav"),
	&"coin": preload("res://audio/coin.wav"),
	&"unlock": preload("res://audio/unlock.wav"),
	&"revive": preload("res://audio/revive.wav"),
}
const MUSIC: AudioStreamOggVorbis = preload("res://audio/music.ogg")

## The game's audio node, so UI code can play a click without holding a reference.
static var instance: Sfx

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music := AudioStreamPlayer.new()


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)
	_music.stream = MUSIC # looped by its import settings; the file is cut to whole bars
	_music.volume_db = MUSIC_DB
	_music.bus = &"Music"
	add_child(_music)
	_music.play()


static func click() -> void:
	if is_instance_valid(instance):
		instance.play("click", 1.0, -2.0)


## Softens the music while paused or in menus layered over a run.
func duck(on: bool) -> void:
	var tween := create_tween()
	tween.tween_property(_music, "volume_db", DUCKED_DB if on else MUSIC_DB, 0.25)


func play(sound: StringName, pitch := 1.0, volume_db := 0.0) -> void:
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = SOUNDS[sound]
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()

