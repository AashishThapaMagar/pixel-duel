extends Control
## On-screen touch controls. Drives the exact same p1_*/p2_* input actions
## a keyboard would (see project.godot [input]) by calling Input.action_press
## / action_release directly — the same technique ai_controller.gd already
## uses to pilot a player without touching Player internals — so nothing
## downstream (dash detection, motion-input commands, buffering) needs to
## know whether a press came from a key or a touch.
##
## A single touch player (MatchSetup.vs_ai) gets the full screen width:
## movement at the far left edge, attacks at the far right, both reachable
## with relaxed thumbs. Local 2P instead splits the screen in half so
## neither player's cluster crosses the midline.
const UI := preload("res://scripts/ui_kit.gd")
var arena: Node

func _ready() -> void:
	arena = get_parent()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Looked up by absolute path rather than the usual bare "MatchSetup"
	# autoload reference: this script is instantiated with a raw
	# preload().new() (see arena.gd) rather than through a .tscn, and in
	# that specific shape referencing the autoload by name hangs GDScript's
	# compiler instead of erroring — get_node sidesteps it entirely.
	var match_setup: Node = get_node("/root/MatchSetup")
	if match_setup.vs_ai:
		_build_player("p1_", 110.0, 840.0, UI.LIME)
	else:
		_build_player("p1_", 85.0, 245.0, UI.LIME)
		_build_player("p2_", 875.0, 715.0, UI.VIOLET)

func _process(_delta: float) -> void:
	# The move guide panel covers this same bottom area; don't fight it.
	if arena != null and "move_guide" in arena and arena.move_guide != null:
		visible = not arena.move_guide.visible

## move_anchor centers the LEFT/RIGHT/JUMP cluster; action_anchor centers
## the GUARD/LIGHT/HEAVY cluster. Passing move_anchor further from center
## than action_anchor (or vice versa) is what puts a lone touch player's
## hands at the far screen edges instead of crowding the middle.
func _build_player(prefix: String, move_anchor: float, action_anchor: float, tint: Color) -> void:
	_button(prefix + "left", move_anchor - 40.0, 470.0, "L", tint)
	_button(prefix + "right", move_anchor + 40.0, 470.0, "R", tint)
	_button(prefix + "jump", move_anchor, 400.0, "JUMP", tint)
	_button(prefix + "block", action_anchor - 50.0, 475.0, "GRD", tint)
	_button(prefix + "punch", action_anchor + 50.0, 475.0, "LT", tint)
	_button(prefix + "kick", action_anchor, 405.0, "HV", tint)

func _button(action: String, x: float, y: float, label: String, tint: Color) -> void:
	var btn := Button.new()
	btn.text = label
	var btn_size := Vector2(64.0, 64.0)
	btn.position = Vector2(x, y) - btn_size * 0.5
	btn.size = btn_size
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 11)
	var normal := UI.box(Color(0.08, 0.1, 0.16, 0.5), Color(tint, 0.35), 2)
	normal.set_corner_radius_all(32)
	var pressed := UI.box(Color(tint, 0.4), Color(tint, 0.8), 2)
	pressed.set_corner_radius_all(32)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("font_color", Color(tint, 0.8))
	btn.add_theme_color_override("font_hover_color", Color(tint, 0.8))
	btn.add_theme_color_override("font_pressed_color", Color(0.05, 0.06, 0.1))
	# action_press/release (not "pressed") so a held finger reads as a held
	# key — needed for movement, guard, and the quarter-circle motion input.
	btn.button_down.connect(func(): Input.action_press(action))
	btn.button_up.connect(func(): Input.action_release(action))
	add_child(btn)
