extends RefCounted
## Shared visual language for menus and match overlays.
const INK := Color("090c16")
const PANEL := Color("131827")
const LINE := Color("30394b")
const WHITE := Color("f3f5ed")
const MUTED := Color("9ba6ba")
const LIME := Color("d5fa53")
const VIOLET := Color("b8a0ff")
const RED := Color("ff797e")

static func box(color: Color, border: Color = LINE, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	style.content_margin_left = 16
	style.content_margin_right = 16
	return style

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 15
	result.set_color("font_color", "Label", WHITE)
	for type in ["Button", "OptionButton", "CheckBox"]:
		result.set_stylebox("normal", type, box(PANEL))
		result.set_stylebox("hover", type, box(Color("252e3e"), LIME))
		result.set_stylebox("pressed", type, box(Color("394329"), LIME))
		result.set_stylebox("focus", type, box(Color(0, 0, 0, 0), LIME, 2))
		result.set_stylebox("disabled", type, box(Color("101420"), Color("242c3a")))
		result.set_color("font_color", type, WHITE)
		result.set_color("font_hover_color", type, LIME)
		result.set_color("font_pressed_color", type, WHITE)
		result.set_color("font_disabled_color", type, Color("677185"))
	result.set_stylebox("panel", "PopupMenu", box(PANEL))
	result.set_stylebox("hover", "PopupMenu", box(Color("303d30"), LIME))
	var track := box(LINE, LINE, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var active_track := box(LIME, LIME, 0)
	active_track.content_margin_top = 3
	active_track.content_margin_bottom = 3
	result.set_stylebox("slider", "HSlider", track)
	result.set_stylebox("grabber_area", "HSlider", active_track)
	result.set_stylebox("grabber_area_highlight", "HSlider", active_track)
	return result

static func label(parent: Node, text: String, pos: Vector2, dimensions: Vector2, font_size: int = 16, color: Color = WHITE) -> Label:
	var node := Label.new()
	node.text = text
	node.position = pos
	node.size = dimensions
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node

static func panel(parent: Node, pos: Vector2, dimensions: Vector2, color: Color = PANEL, border: Color = LINE) -> Panel:
	var node := Panel.new()
	node.position = pos
	node.size = dimensions
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", box(color, border))
	parent.add_child(node)
	return node

static func button(parent: Node, text: String, pos: Vector2, dimensions: Vector2, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.position = pos
	node.size = dimensions
	node.pivot_offset = dimensions * 0.5
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(node)
	node.mouse_entered.connect(func(): _pop(node, 1.045, 0.15))
	node.mouse_exited.connect(func(): _pop(node, 1.0, 0.18))
	node.button_down.connect(func(): _pop(node, 0.93, 0.06))
	node.button_up.connect(func(): _pop(node, 1.045 if node.is_hovered() else 1.0, 0.12))
	if primary:
		node.add_theme_stylebox_override("normal", box(LIME, LIME))
		node.add_theme_stylebox_override("hover", box(Color("e5ff8e"), WHITE))
		node.add_theme_stylebox_override("pressed", box(Color("b6d740"), LIME))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			node.add_theme_color_override(state, INK)
	return node

## Springy scale toward target_scale, replacing any pop still in flight on
## this control so rapid hover in/out doesn't fight itself.
static func _pop(node: Control, target_scale: float, duration: float) -> void:
	var existing: Tween = node.get_meta("_pop_tween") if node.has_meta("_pop_tween") else null
	if existing != null and existing.is_valid():
		existing.kill()
	var tween := node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE * target_scale, duration)
	node.set_meta("_pop_tween", tween)

## Fade in with a short slide-down, used for pages and modals alike. Works
## on any control regardless of size since it animates position, not scale.
static func enter(control: Control) -> void:
	control.modulate.a = 0.0
	var target_position := control.position
	control.position = target_position + Vector2(0, 14)
	var tween := control.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.24)
	tween.tween_property(control, "position", target_position, 0.32)
