extends Node
## Autoload (see project.godot [autoload]) — holds user-facing settings that
## need to survive scene changes and, via a small save file, across sessions.
## MainMenu's Settings screen reads/writes this; nothing else needs to.

const SAVE_PATH := "user://settings.cfg"

var fullscreen: bool = false
var volume: float = 0.8   # 0..1 linear, converted to dB for the Master bus
var sfx_volume: float = 0.9   # 0..1 linear, for the SFX bus (see sfx.gd)
## Defaults on for an actual touchscreen (mobile export) and off elsewhere,
## but the player can flip it either way (a touch laptop, testing on desktop).
var touch_controls: bool = DisplayServer.is_touchscreen_available()

func _ready() -> void:
	_load()
	_apply()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply()
	_save()

func set_volume(value: float) -> void:
	volume = clamp(value, 0.0, 1.0)
	_apply()
	_save()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	apply_audio()
	_save()

func set_touch_controls(value: bool) -> void:
	touch_controls = value
	_save()

func _apply() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	apply_audio()

## Also called by the Sfx autoload once it has created the SFX bus.
func apply_audio() -> void:
	# volume=0 should be silent, not just very quiet — linear_to_db(0) is -inf,
	# which AudioServer already treats as silent, but clamp explicitly anyway.
	for pair in [["Master", volume], ["SFX", sfx_volume]]:
		var bus := AudioServer.get_bus_index(pair[0])
		if bus != -1:
			AudioServer.set_bus_volume_db(bus, -80.0 if pair[1] <= 0.0 else linear_to_db(pair[1]))

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
		volume = cfg.get_value("audio", "volume", volume)
		sfx_volume = cfg.get_value("audio", "sfx_volume", sfx_volume)
		touch_controls = cfg.get_value("display", "touch_controls", touch_controls)

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("display", "touch_controls", touch_controls)
	cfg.save(SAVE_PATH)
