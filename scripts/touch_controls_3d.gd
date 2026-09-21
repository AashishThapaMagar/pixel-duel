extends "res://scripts/touch_controls.gd"

func _exit_tree() -> void:
	for player in [1, 2]:
		for suffix in ["left", "right", "far", "near", "jump", "block", "punch", "kick", "run"]:
			Input.action_release("p%d_3d_%s" % [player, suffix])

func _build_player(prefix: String, move_anchor: float, action_anchor: float, tint: Color) -> void:
	var action_prefix := prefix + "3d_"
	_button(action_prefix + "left", move_anchor - 38, 443, "L", tint)
	_button(action_prefix + "right", move_anchor + 38, 443, "R", tint)
	_button(action_prefix + "far", move_anchor, 377, "UP", tint)
	_button(action_prefix + "near", move_anchor, 505, "DOWN", tint)
	_button(action_prefix + "run", move_anchor, 307, "RUN", tint)
	_button(action_prefix + "jump", action_anchor - 35, 327, "JUMP", tint)
	_button(action_prefix + "block", action_anchor - 40, 464, "GUARD", tint)
	_button(action_prefix + "punch", action_anchor + 35, 464, "LIGHT", tint)
	_button(action_prefix + "kick", action_anchor, 395, "HEAVY", tint)
