extends Control
## Original arcade backdrop: deep blue, red light and a restrained scan texture.
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	for row in 90:
		var t := row / 90.0
		var shade := Color("080b23").lerp(Color("253755"), sin(t * PI) * 0.62)
		draw_rect(Rect2(0, row * 6, 960, 6), shade)
	for i in 14:
		var x := fmod(i * 111.0 + elapsed * 4.0, 1500.0) - 300.0
		draw_line(Vector2(x, 0), Vector2(x + 360, 540), Color(0.23, 0.31, 0.48, 0.09), 24)
	for i in range(12, 0, -1):
		draw_circle(Vector2(480, 170), i * 21, Color(0.8, 0.14, 0.06, 0.018))
	for y in range(0, 540, 4):
		draw_line(Vector2(0, y), Vector2(960, y), Color(0, 0, 0, 0.11))
	draw_line(Vector2(24, 48), Vector2(936, 48), Color("576279"), 1)
	draw_line(Vector2(24, 492), Vector2(936, 492), Color("576279"), 1)
