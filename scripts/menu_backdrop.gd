extends Control
## Abstract arena lighting and a quiet perspective grid; no character artwork.
var motion_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	motion_time += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("090e17"))
	# Soft central halo, layered without a texture or shader dependency.
	for i in range(32, 0, -1):
		var radius := 100.0 + i * 10.0
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
	for i in 8:
		var x := 95.0 + i * 110
		var y := 95.0 + fmod(i * 43.0 + motion_time * 2.0, 200.0)
		draw_circle(Vector2(x, y), 1.0, Color(0.85, 0.58, 0.4, 0.15))