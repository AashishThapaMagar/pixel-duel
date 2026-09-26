extends Control
## Live 3D arena behind the menus. Each mode shows a different mood of the
## Nepal arena under a slowly drifting camera; `opening` drives the crimson
## slash wipe that carries the player into the next screen.
const ACCENTS := [Color("ffc53d"), Color("ff4a5a"), Color("6fb4ff"), Color("e59bff")]
const MODE_ORDER := ["arcade", "local", "ai", "story"]
## Arena round shown for each mode, in MODE_ORDER.
const MODE_ROUND := [0, 1, 2, 3]
const STAGE := preload("res://scripts/nepal_stage_3d.gd")
var elapsed := 0.0
var selected := 0:
	set(value):
		selected = value
		if stage != null:
			stage.show_round(MODE_ROUND[clampi(value, 0, 3)])
var opening := 0.0:
	set(value):
		opening = value
		queue_redraw()
		if is_instance_valid(wipe_canvas):
			wipe_canvas.queue_redraw()
## Topmost control the transition slash is drawn on, above the menu itself.
var wipe_canvas: Control
## How far the dark reading panel covers the left of the screen (0..1).
var shade_width := 0.62
var stage: Node3D
var camera: Camera3D
var view: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	stage = STAGE.new()
	viewport.add_child(stage)
	camera = Camera3D.new()
	camera.fov = 50
	camera.far = 400
	viewport.add_child(camera)
	camera.current = true
	view = TextureRect.new()
	view.texture = viewport.get_texture()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.show_behind_parent = true
	add_child(view)
	stage.show_round(MODE_ROUND[selected])
	_place_camera()

func _process(delta: float) -> void:
	elapsed += delta
	if stage != null:
		stage.animate(delta)
	_place_camera()
	queue_redraw()

## A slow crane shot across the square, looking toward the centrepiece.
func _place_camera() -> void:
	if camera == null:
		return
	var sweep := sin(elapsed * 0.12)
	camera.position = Vector3(sweep * 3.2 + 1.5, 2.1 + sin(elapsed * 0.2) * 0.25, 6.5)
	camera.look_at(Vector3(sweep * 1.2 - 0.5, 3.4, -20))

func _draw() -> void:
	var size := Vector2(960, 540)
	# Reading shade on the left, fading out toward the scene.
	var reach := size.x * shade_width
	if reach > 0.0:
		draw_rect(Rect2(0, 0, reach * 0.55, size.y), Color(0.02, 0.025, 0.05, 0.78))
	if reach > 0.0:
		var dark := Color(0.02, 0.025, 0.05, 0.78)
		var clear := Color(0.02, 0.025, 0.05, 0.0)
		draw_polygon(PackedVector2Array([Vector2(reach * 0.55, 0), Vector2(reach, 0), Vector2(reach, size.y), Vector2(reach * 0.55, size.y)]), PackedColorArray([dark, clear, clear, dark]))
	# Letterbox bars and a thin gold rule give it a broadcast-card frame.
	draw_rect(Rect2(0, 0, size.x, 6), Color(0, 0, 0, 0.9))
	draw_rect(Rect2(0, size.y - 34, size.x, 34), Color(0.01, 0.012, 0.025, 0.92))
	draw_rect(Rect2(0, size.y - 35, size.x, 1.5), Color(ACCENTS[selected], 0.8))

## Crimson slash sweeps across with a gold edge until it covers the screen.
func draw_wipe(canvas: CanvasItem) -> void:
	if opening <= 0.0:
		return
	var size := Vector2(960, 540)
	var front := lerpf(-400.0, size.x + 400.0, clampf(opening, 0.0, 1.0))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-800, 0), Vector2(front + 180, 0), Vector2(front - 180, size.y), Vector2(-800, size.y)]), Color("b3162d"))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(front + 180, 0), Vector2(front + 206, 0), Vector2(front - 154, size.y), Vector2(front - 180, size.y)]), Color("ffc53d"))
