extends Control
## Arcade-cabinet title screen treatment: pure black, under a few sharp
## amber energy fractures, a rising ember glow, drifting embers, a faint
## CRT scanline grid and a corner vignette for cinematic framing. No arena
## photography and no character artwork — the black is the point, so the
## wordmark and mode list read like they're lit on an empty stage rather
## than pasted over a busier scene.
const FIRE := Color("ff9966")
const EMBER := Color("ffb27a")
var motion_time: float = 0.0
## One direction/length/hue/phase per fracture so they don't flicker in sync.
var fractures: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hues := [Color("ffb27a"), Color("ff9966"), Color("c96a4a")]
	for i in 4:
		fractures.append({
			"origin": Vector2(120.0 + i * 230.0, -20.0),
			"angle": deg_to_rad(58.0 + fmod(i * 17.0, 20.0)),
			"length": 420.0 + fmod(i * 53.0, 90.0),
			"color": hues[i % hues.size()],
			"phase": i * 1.7,
		})

func _process(delta: float) -> void:
	motion_time += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	# Everything past the base fill drifts a few pixels toward the cursor,
	# a cheap parallax that sells depth without a shader or 3D layer.
	var parallax: Vector2 = ((get_local_mouse_position() - size * 0.5) / maxf(size.x, 1.0)) * 16.0
	draw_set_transform(parallax, 0.0, Vector2.ONE)
	# A low ember glow rising behind the mode list, standing in for firelight
	# without needing a particle system or shader.
	var ember_pulse := 1.0 + sin(motion_time * 0.5) * 0.1
	for i in range(26, 0, -1):
		draw_circle(Vector2(700, 470), (70.0 + i * 9.0) * ember_pulse, Color(0.55, 0.3, 0.16, 0.009))
	# Soft central halo behind the wordmark.
	var glow_pulse := 1.0 + sin(motion_time * 0.6) * 0.12
	for i in range(32, 0, -1):
		var radius := (100.0 + i * 10.0) * glow_pulse
		draw_circle(Vector2(480, 210), radius, Color(0.42, 0.28, 0.2, 0.008))
	# Sharp amber energy fractures — thin, jagged, and independently
	# flickering, echoing arcade fighting-game title art without a texture.
	for f in fractures:
		var flicker: float = 0.35 + 0.35 * absf(sin(motion_time * 1.6 + f.phase))
		var dir := Vector2(cos(f.angle), sin(f.angle))
		var perp := Vector2(-dir.y, dir.x)
		var a: Vector2 = f.origin
		var b: Vector2 = f.origin + dir * f.length
		var kink: Vector2 = f.origin + dir * f.length * 0.55 + perp * 14.0
		draw_polyline(PackedVector2Array([a, kink, b]), Color(f.color, flicker * 0.5), 3.0, true)
		draw_polyline(PackedVector2Array([a, kink, b]), Color(Color.WHITE, flicker * 0.22), 1.0, true)
	# Perspective floor below the title, with very slow traveling lines.
	for x in range(-480, 1500, 120):
		draw_line(Vector2(480 + (x - 480) * 0.18, 309), Vector2(x, 499), Color("15110d"), 1.0, true)
	for i in 7:
		var depth := fmod(i / 7.0 + motion_time * 0.014, 1.0)
		var y := 309.0 + depth * depth * 190
		draw_line(Vector2(36, y), Vector2(924, y), Color(0.24, 0.17, 0.11, depth * 0.26), 1.0, true)
	draw_line(Vector2(36, 66), Vector2(924, 66), Color("221a12"))
	draw_line(Vector2(36, 498), Vector2(924, 498), Color("221a12"))
	# Corner cuts frame the wordmark without competing with it.
	for side in 2:
		var x := 151.0 if side == 0 else 809.0
		var direction := 1.0 if side == 0 else -1.0
		draw_polyline(PackedVector2Array([Vector2(x + direction * 20, 164), Vector2(x, 164), Vector2(x - direction * 14, 188)]), FIRE, 2, true)
		draw_polyline(PackedVector2Array([Vector2(x - direction * 14, 232), Vector2(x, 256), Vector2(x + direction * 20, 256)]), FIRE, 2, true)
	for i in 14:
		var x := 60.0 + i * 65.0
		var y := 90.0 + fmod(i * 37.0 + motion_time * (2.0 + fmod(i * 1.7, 3.0)), 210.0)
		var twinkle := 0.08 + 0.1 * absf(sin(motion_time * 1.3 + i))
		draw_circle(Vector2(x, y), 1.0 + fmod(i, 3) * 0.4, Color(EMBER, twinkle))
	# A faint light sweep drifts across the title band on a slow loop.
	var sweep_x := fmod(motion_time * 70.0, 1400.0) - 250.0
	draw_colored_polygon(PackedVector2Array([Vector2(sweep_x, 60), Vector2(sweep_x + 40, 60), Vector2(sweep_x - 60, 300), Vector2(sweep_x - 100, 300)]), Color(0.9, 0.95, 1.0, 0.025))
	# Corner vignette, drawn last (after the fractures/floor/sweep above it)
	# so it actually darkens their edges too instead of just the empty black
	# it would otherwise be blending into — a cinematic frame around the
	# whole composition, not just the base fill.
	for corner in [Vector2(-40, -40), Vector2(1000, -40), Vector2(-40, 580), Vector2(1000, 580)]:
		for i in range(18, 0, -1):
			draw_circle(corner, 140.0 + i * 22.0, Color(0, 0, 0, 0.02))
	# Faint fixed-in-screen-space scanlines for a hint of arcade-cabinet CRT
	# texture; reset the transform first so drift doesn't blur them.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var y := 0.0
	while y < size.y:
		draw_rect(Rect2(0, y, size.x, 1.0), Color(1, 1, 1, 0.015))
		y += 3.0
