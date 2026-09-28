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

## Graphics. Presets set every option below; changing one makes it CUSTOM.
signal graphics_changed
enum Quality { LOW, MEDIUM, HIGH, CUSTOM }
const RENDER_SCALES := [0.5, 0.75, 1.0]
## [render scale index, anti-aliasing (0 off, 1 2x, 2 4x),
##  shadows (0 off, 1 low, 2 high), photo-real arena textures].
const PRESETS := [
	[1, 0, 0, false],
	[2, 1, 1, false],
	# High uses 2x MSAA: 4x cost ~15 fps at 1080p on integrated GPUs.
	[2, 1, 2, true],
]
var quality: int = Quality.HIGH
var render_scale: int = 2
var anti_aliasing: int = 1
var shadows: int = 2
var detailed_textures: bool = true
var vsync: bool = true
var show_fps: bool = false
## Bloom and the per-arena finishing grade (nepal_stage_3d.gd).
var post_effects: bool = true
## Sparks, shock rings, dust, trails and the impact punch (arena_3d.gd).
var hit_effects: bool = true
## Training-style input history under each fighter's side of the HUD.
var input_display: bool = false
## Steps the graphics preset down by itself when a fight runs under 30 FPS
## for a few seconds (never up, never past LOW, never from CUSTOM).
var adaptive_quality: bool = true
const ADAPTIVE_FLOOR_FPS := 30.0
const ADAPTIVE_WINDOW := 3.0
const ADAPTIVE_WARMUP := 4.0
var _adaptive_scene: Node
var _adaptive_time := 0.0
var _adaptive_frames := 0
var _adaptive_window := 0.0
var notice_label: Label
var _notice_tween: Tween
var fps_label: Label

func _ready() -> void:
	_load()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	fps_label = Label.new()
	fps_label.position = Vector2(8, 518)
	fps_label.add_theme_font_size_override("font_size", 13)
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 4)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fps_label)
	notice_label = Label.new()
	notice_label.position = Vector2(0, 92)
	notice_label.size = Vector2(960, 22)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 12)
	notice_label.add_theme_color_override("font_color", Color("ffc53d"))
	notice_label.add_theme_color_override("font_outline_color", Color.BLACK)
	notice_label.add_theme_constant_override("outline_size", 4)
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_label.modulate.a = 0.0
	layer.add_child(notice_label)
	_apply()
	apply_graphics()

func _process(delta: float) -> void:
	fps_label.visible = show_fps
	if show_fps:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	_adapt(delta)

## Watches the frame rate during fights only (menus are cheap) and steps
## the preset down one notch at a time, telling the player on screen.
func _adapt(delta: float) -> void:
	var scene := get_tree().current_scene
	var fighting := scene != null and scene.get_script() != null and (str(scene.get_script().resource_path).ends_with("arena_3d.gd") or str(scene.get_script().resource_path).ends_with("practice_3d.gd"))
	if not adaptive_quality or not fighting or quality == Quality.LOW or quality == Quality.CUSTOM:
		_adaptive_scene = null
		return
	if scene != _adaptive_scene:
		_adaptive_scene = scene
		_adaptive_time = 0.0
		_adaptive_frames = 0
		_adaptive_window = 0.0
	_adaptive_time += delta
	if _adaptive_time < ADAPTIVE_WARMUP:
		return
	_adaptive_frames += 1
	_adaptive_window += delta
	if _adaptive_window < ADAPTIVE_WINDOW:
		return
	var average := _adaptive_frames / _adaptive_window
	_adaptive_frames = 0
	_adaptive_window = 0.0
	if average < ADAPTIVE_FLOOR_FPS:
		set_quality(quality - 1)
		notify("SMOOTHER PLAY: GRAPHICS SET TO %s  (SETTINGS ▸ GRAPHICS TO CHANGE)" % ["LOW", "MEDIUM", "HIGH", "CUSTOM"][quality])
		_adaptive_time = 0.0

## A short line of gold text over the top of the screen.
func notify(text: String) -> void:
	notice_label.text = text
	if _notice_tween != null:
		_notice_tween.kill()
	notice_label.modulate.a = 1.0
	_notice_tween = create_tween()
	_notice_tween.tween_interval(3.5)
	_notice_tween.tween_property(notice_label, "modulate:a", 0.0, 0.6)

func set_quality(value: int) -> void:
	quality = value
	if value < PRESETS.size():
		var preset: Array = PRESETS[value]
		render_scale = preset[0]
		anti_aliasing = preset[1]
		shadows = preset[2]
		detailed_textures = preset[3]
	apply_graphics()
	_save()

## Sets one graphics option by name; the preset becomes CUSTOM unless the
## new combination matches one exactly.
func set_graphic(option: String, value: Variant) -> void:
	set(option, value)
	quality = Quality.CUSTOM
	for i in PRESETS.size():
		if PRESETS[i] == [render_scale, anti_aliasing, shadows, detailed_textures]:
			quality = i
	apply_graphics()
	_save()

func apply_graphics() -> void:
	var viewport := get_tree().root
	viewport.scaling_3d_scale = RENDER_SCALES[render_scale]
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][anti_aliasing]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	RenderingServer.directional_shadow_atlas_set_size(4096 if shadows == 2 else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW if shadows == 2 else RenderingServer.SHADOW_QUALITY_HARD)
	# Scenes with a sun (nepal_stage_3d.gd) listen and update their lights.
	graphics_changed.emit()

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
		quality = cfg.get_value("graphics", "quality", quality)
		render_scale = cfg.get_value("graphics", "render_scale", render_scale)
		anti_aliasing = cfg.get_value("graphics", "anti_aliasing", anti_aliasing)
		shadows = cfg.get_value("graphics", "shadows", shadows)
		detailed_textures = cfg.get_value("graphics", "detailed_textures", detailed_textures)
		vsync = cfg.get_value("graphics", "vsync", vsync)
		show_fps = cfg.get_value("graphics", "show_fps", show_fps)
		post_effects = cfg.get_value("graphics", "post_effects", post_effects)
		adaptive_quality = cfg.get_value("graphics", "adaptive_quality", adaptive_quality)
		hit_effects = cfg.get_value("fight", "hit_effects", hit_effects)
		input_display = cfg.get_value("fight", "input_display", input_display)

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("display", "touch_controls", touch_controls)
	for key in ["quality", "render_scale", "anti_aliasing", "shadows", "detailed_textures", "vsync", "show_fps", "post_effects", "adaptive_quality"]:
		cfg.set_value("graphics", key, get(key))
	for key in ["hit_effects", "input_display"]:
		cfg.set_value("fight", key, get(key))
	cfg.save(SAVE_PATH)

## A named option that is neither a preset graphic nor audio: saved and,
## for post effects, pushed to the arena lighting straight away.
func set_option(option: String, value: Variant) -> void:
	set(option, value)
	if option == "post_effects":
		graphics_changed.emit()
	_save()

## Everything back to how it ships, saved.
func reset_defaults() -> void:
	fullscreen = false
	volume = 0.8
	sfx_volume = 0.9
	touch_controls = DisplayServer.is_touchscreen_available()
	vsync = true
	show_fps = false
	post_effects = true
	adaptive_quality = true
	hit_effects = true
	input_display = false
	_apply()
	set_quality(Quality.HIGH)
