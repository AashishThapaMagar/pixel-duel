extends Control
## A random arena's own illustration behind the same abstract lighting,
## grid and particle overlay as before — a different one of the seven each
## time the game opens, so the title screen never looks quite the same
## twice. No character artwork, per the existing title screen convention.
const ARENAS := preload("res://scripts/arena_catalog.gd")
var motion_time: float = 0.0
var photo: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photo = load(ARENAS.arena(randi() % ARENAS.ARENAS.size()).texture)

func _process(delta: float) -> void:
	motion_time += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("090e17"))
	# Everything past the base fill drifts a few pixels toward the cursor,
	# a cheap parallax that sells depth without a shader or 3D layer. The
	# photo is oversized so that drift never uncovers its edges.
	var parallax: Vector2 = ((get_local_mouse_position() - size * 0.5) / maxf(size.x, 1.0)) * 16.0
	draw_set_transform(parallax, 0.0, Vector2.ONE)
	if photo != null:
		var tex_size: Vector2 = photo.get_size()
		var cover: float = maxf((size.x + 40.0) / tex_size.x, (size.y + 40.0) / tex_size.y)
		var draw_size: Vector2 = tex_size * cover
		var draw_pos: Vector2 = (size - draw_size) * 0.5
		draw_texture_rect(photo, Rect2(draw_pos, draw_size), false, Color(0.5, 0.53, 0.62))
		# A soft top-to-bottom vignette keeps the title and buttons readable
		# no matter which arena's own colors land behind them.
		for i in 26:
			var t: float = i / 26.0
			draw_rect(Rect2(0, t * 210.0, size.x, 210.0 / 26.0 + 1.0), Color(0.02, 0.03, 0.05, (1.0 - t) * 0.5))
		for i in 26:
			var t: float = i / 26.0
			var y: float = size.y - 230.0 + t * 230.0
			draw_rect(Rect2(0, y, size.x, 230.0 / 26.0 + 1.0), Color(0.02, 0.03, 0.05, t * 0.55))
	var glow_pulse := 1.0 + sin(motion_time * 0.6) * 0.12
	# Soft central halo, layered without a texture or shader dependency.
	for i in range(32, 0, -1):
		var radius := (100.0 + i * 10.0) * glow_pulse
		draw_circle(Vector2(480, 222), radius, Color(0.22, 0.29, 0.38, 0.007))
	draw_colored_polygon(PackedVector2Array([Vector2(105, 65), Vector2(130, 65), Vector2(421, 442), Vector2(220, 442)]), Color(0.37, 0.46, 0.57, 0.035))
	draw_colored_polygon(PackedVector2Array([Vector2(830, 65), Vector2(855, 65), Vector2(740, 442), Vector2(539, 442)]), Color(0.8, 0.42, 0.25, 0.035))
	# Perspective floor below the title, with very slow traveling lines.
	for x in range(-480, 1500, 120):
		draw_line(Vector2(480 + (x - 480) * 0.18, 309), Vector2(x, 499), Color("18222d"), 1.0, true)
	for i in 7:
		var depth := fmod(i / 7.0 + motion_time * 0.014, 1.0)
		var y := 309.0 + depth * depth * 190
		draw_line(Vector2(36, y), Vector2(924, y), Color(0.17, 0.24, 0.3, depth * 0.24), 1.0, true)
	draw_line(Vector2(36, 66), Vector2(924, 66), Color("26303d"))
	draw_line(Vector2(36, 498), Vector2(924, 498), Color("26303d"))
	# Corner cuts frame the wordmark without competing with it.
	var warm := Color("be7756")
	for side in 2:
		var x := 151.0 if side == 0 else 809.0
		var direction := 1.0 if side == 0 else -1.0
		draw_polyline(PackedVector2Array([Vector2(x + direction * 20, 164), Vector2(x, 164), Vector2(x - direction * 14, 188)]), warm, 2, true)
		draw_polyline(PackedVector2Array([Vector2(x - direction * 14, 232), Vector2(x, 256), Vector2(x + direction * 20, 256)]), warm, 2, true)
	for i in 14:
		var x := 60.0 + i * 65.0
		var y := 90.0 + fmod(i * 37.0 + motion_time * (2.0 + fmod(i * 1.7, 3.0)), 210.0)
		var twinkle := 0.08 + 0.1 * absf(sin(motion_time * 1.3 + i))
		draw_circle(Vector2(x, y), 1.0 + fmod(i, 3) * 0.4, Color(0.85, 0.58, 0.4, twinkle))
	# A faint light sweep drifts across the title band on a slow loop.
	var sweep_x := fmod(motion_time * 70.0, 1400.0) - 250.0
	draw_colored_polygon(PackedVector2Array([Vector2(sweep_x, 60), Vector2(sweep_x + 40, 60), Vector2(sweep_x - 60, 300), Vector2(sweep_x - 100, 300)]), Color(0.9, 0.95, 1.0, 0.02))