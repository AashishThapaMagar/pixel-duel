extends Node
## Selection survives scene changes; round restart never changes the roster.
var selected_fighters: Array[int] = [0, 1]

func _ready() -> void:
	if not InputMap.has_action("move_list"):
		InputMap.add_action("move_list")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F1
		InputMap.action_add_event("move_list", key)
