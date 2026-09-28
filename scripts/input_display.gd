extends Control
## Training-style input history: the last few presses for each player as
## key chips low on their side of the screen, newest nearest the middle.
## Reads the fighters' input prefixes so it works for the 3D and 2D arenas.
const UI := preload("res://scripts/ui_kit.gd")
const ACTIONS := [["left", "◀"], ["right", "▶"], ["far", "▲"], ["near", "▼"], ["jump", "J"], ["block", "G"], ["punch", "P"], ["kick", "K"], ["grapple", "T"], ["run", "R"]]
const KEEP := 9
var hud: Node
var history: Array = [[], []]
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	elapsed += delta
	var settings := get_node_or_null("/root/Settings")
	visible = settings != null and settings.input_display and hud != null and hud.arena != null
	if not visible:
		return
	for i in 2:
		var fighter: Node = hud.arena.player1 if i == 0 else hud.arena.player2
		var prefix: String = fighter.input_prefix
		for action in ACTIONS:
			var name: String = prefix + action[0]
			if InputMap.has_action(name) and Input.is_action_just_pressed(name):
				history[i].append([action[1], elapsed])
		while history[i].size() > KEEP:
			history[i].pop_front()
	queue_redraw()

func _draw() -> void:
	for i in 2:
		var chips: Array = history[i]
		for k in chips.size():
			var age: float = elapsed - chips[k][1]
			var alpha := clampf(1.0 - (age - 2.0) / 1.5, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var slot := chips.size() - 1 - k
			var x := (426.0 - slot * 26.0) if i == 0 else (512.0 + slot * 26.0)
			var rect := Rect2(x, 474, 22, 22)
			draw_rect(rect, Color(0.02, 0.02, 0.05, 0.8 * alpha))
			draw_rect(rect, Color(UI.GOLD if i == 0 else UI.VIOLET, 0.9 * alpha), false, 1.5)
			draw_string(UI.strong_font(), rect.position + Vector2(0, 16), chips[k][0], HORIZONTAL_ALIGNMENT_CENTER, 22, 12, Color(UI.WHITE, alpha))
