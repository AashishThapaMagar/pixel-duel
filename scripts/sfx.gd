extends Node
## Autoload "Sfx": every game sound effect, played on the SFX bus.
##
## Sounds come from recordings in res://assets/audio/sfx/ named after NAMES
## (e.g. hit_heavy.ogg or .wav); open the project in the Godot editor once
## so new files get imported. A sound with no recording stays silent.
##
## The synthesised fallbacks below are switched off (USE_GENERATED): they
## sounded too artificial. Set it to true to hear them again.
##
## Call from anywhere: preload("res://scripts/sfx.gd").fire("hit_heavy")
const FOLDER := "res://assets/audio/sfx/"
const RATE := 22050
const VOICES := 10
const USE_GENERATED := false
const NAMES := ["hit_light", "hit_heavy", "block", "whoosh", "whoosh_heavy", "ko", "round", "fight", "menu_move", "menu_confirm", "menu_back", "wipe"]
var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var next_voice := 0

## Play a sound through the autoload if it exists (safe in any context).
static func fire(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var node := tree.root.get_node_or_null("Sfx")
	if node != null:
		node.play(sound, volume_db, pitch)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		settings.apply_audio()
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		players.append(player)
	for sound in NAMES:
		var recorded := _recorded(sound)
		if recorded != null:
			streams[sound] = recorded
		elif USE_GENERATED:
			streams[sound] = _wav(call("_make_" + sound))

## A small random pitch spread keeps repeated hits from sounding mechanical.
func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not streams.has(sound) or players.is_empty():
		return
	var player := players[next_voice]
	next_voice = (next_voice + 1) % players.size()
	player.stream = streams[sound]
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(0.95, 1.05)
	player.play()

func _recorded(sound: String) -> AudioStream:
	for extension in ["ogg", "wav", "mp3"]:
		var path: String = FOLDER + sound + "." + extension
		if ResourceLoader.exists(path):
			return load(path)
	return null

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream

# --- synthesis helpers --------------------------------------------------

func _buffer(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * RATE))
	return samples

## Sine whose pitch glides from one frequency to another over the sound.
func _add_sweep(samples: PackedFloat32Array, from_hz: float, to_hz: float, decay: float, gain: float, start := 0.0) -> void:
	var phase := 0.0
	var length := samples.size()
	for i in range(int(start * RATE), length):
		var t := float(i) / RATE - start
		var hz := lerpf(from_hz, to_hz, clampf(t / maxf(float(length) / RATE - start, 0.001), 0.0, 1.0))
		phase += TAU * hz / RATE
		samples[i] += sin(phase) * exp(-t * decay) * gain

## Noise through a one-pole low-pass (smaller smooth = darker), optionally
## with the lows removed for an airy band-pass.
func _add_noise(samples: PackedFloat32Array, smooth: float, decay: float, gain: float, high_pass := 0.0, start := 0.0) -> void:
	var low := 0.0
	var lower := 0.0
	for i in range(int(start * RATE), samples.size()):
		var t := float(i) / RATE - start
		low += (randf_range(-1.0, 1.0) - low) * smooth
		lower += (low - lower) * high_pass
		samples[i] += (low - lower) * exp(-t * decay) * gain

func _add_tone(samples: PackedFloat32Array, hz: float, decay: float, gain: float, start := 0.0, square := false) -> void:
	for i in range(int(start * RATE), samples.size()):
		var t := float(i) / RATE - start
		var wave := sin(TAU * hz * t)
		if square:
			wave = signf(wave) * 0.6
		samples[i] += wave * exp(-t * decay) * gain

## Gentle saturation so layered hits punch without clipping harshly.
func _shape(samples: PackedFloat32Array, drive := 1.4) -> PackedFloat32Array:
	for i in samples.size():
		samples[i] = tanh(samples[i] * drive) * 0.9
	return samples

# --- the sounds ---------------------------------------------------------

func _make_hit_light() -> PackedFloat32Array:
	var s := _buffer(0.16)
	_add_sweep(s, 190.0, 85.0, 26.0, 0.85)
	_add_noise(s, 0.35, 42.0, 0.7)
	_add_noise(s, 0.9, 260.0, 0.4)
	return _shape(s)

func _make_hit_heavy() -> PackedFloat32Array:
	var s := _buffer(0.34)
	_add_sweep(s, 120.0, 42.0, 11.0, 1.0)
	_add_noise(s, 0.22, 18.0, 0.85)
	_add_noise(s, 0.95, 220.0, 0.55)
	return _shape(s, 1.8)

func _make_block() -> PackedFloat32Array:
	var s := _buffer(0.24)
	for partial in [[820.0, 18.0, 0.45], [1330.0, 22.0, 0.32], [2150.0, 30.0, 0.22], [3100.0, 40.0, 0.14]]:
		_add_tone(s, partial[0], partial[1], partial[2])
	_add_noise(s, 0.8, 190.0, 0.5)
	_add_sweep(s, 150.0, 90.0, 35.0, 0.4)
	return _shape(s)

func _make_whoosh() -> PackedFloat32Array:
	return _swish(0.2, 0.55, 0.08, 0.55)

func _make_whoosh_heavy() -> PackedFloat32Array:
	return _swish(0.3, 0.35, 0.04, 0.7)

func _swish(seconds: float, smooth: float, high_pass: float, gain: float) -> PackedFloat32Array:
	var s := _buffer(seconds)
	var low := 0.0
	var lower := 0.0
	for i in s.size():
		var t := float(i) / s.size()
		low += (randf_range(-1.0, 1.0) - low) * smooth
		lower += (low - lower) * high_pass
		s[i] = (low - lower) * pow(sin(PI * t), 2.0) * gain * 2.2
	return _shape(s, 1.2)

func _make_ko() -> PackedFloat32Array:
	var s := _buffer(1.3)
	_add_sweep(s, 95.0, 28.0, 3.2, 1.0)
	_add_noise(s, 0.12, 4.5, 0.7)
	_add_noise(s, 0.9, 90.0, 0.6)
	_add_sweep(s, 60.0, 35.0, 2.0, 0.5, 0.18)
	return _shape(s, 2.0)

## Temple-gong strike for the round call.
func _make_round() -> PackedFloat32Array:
	var s := _buffer(1.6)
	for partial in [[196.0, 2.0, 0.42], [297.0, 2.6, 0.3], [418.0, 3.3, 0.22], [587.0, 4.2, 0.15], [835.0, 5.8, 0.09]]:
		_add_tone(s, partial[0], partial[1], partial[2])
	_add_noise(s, 0.5, 60.0, 0.35)
	return _shape(s, 1.1)

## Bright brass-like chord stab for FIGHT!
func _make_fight() -> PackedFloat32Array:
	var s := _buffer(0.75)
	var filtered := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var drop := 1.0 - 0.06 * clampf((t - 0.35) / 0.4, 0.0, 1.0)
		var wave := 0.0
		for hz in [220.0, 330.0, 440.0, 554.4]:
			wave += (2.0 * fposmod(hz * drop * t, 1.0) - 1.0) * 0.28
		filtered += (wave - filtered) * 0.18
		var envelope := minf(t / 0.012, 1.0) * exp(-maxf(t - 0.08, 0.0) * 3.2)
		s[i] = filtered * envelope
	_add_noise(s, 0.6, 70.0, 0.3)
	return _shape(s, 1.5)

func _make_menu_move() -> PackedFloat32Array:
	var s := _buffer(0.06)
	_add_tone(s, 1320.0, 55.0, 0.32, 0.0, true)
	return s

func _make_menu_confirm() -> PackedFloat32Array:
	var s := _buffer(0.2)
	_add_tone(s, 880.0, 30.0, 0.3, 0.0, true)
	_add_tone(s, 1320.0, 18.0, 0.32, 0.065, true)
	return s

func _make_menu_back() -> PackedFloat32Array:
	var s := _buffer(0.17)
	_add_tone(s, 660.0, 28.0, 0.3, 0.0, true)
	_add_tone(s, 440.0, 22.0, 0.3, 0.06, true)
	return s

## Long rising swoosh for the crimson slash transition.
func _make_wipe() -> PackedFloat32Array:
	var s := _buffer(0.6)
	var low := 0.0
	var lower := 0.0
	for i in s.size():
		var t := float(i) / s.size()
		var smooth := lerpf(0.15, 0.7, t)
		low += (randf_range(-1.0, 1.0) - low) * smooth
		lower += (low - lower) * 0.06
		s[i] = (low - lower) * pow(sin(PI * t), 1.5) * 1.3
	return _shape(s, 1.2)
