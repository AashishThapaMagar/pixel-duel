extends Node
## Selection survives scene changes; round restart never changes the roster.
var selected_fighters: Array[int] = [0, 1]
var selected_arena: int = 0
var vs_ai: bool = false
var ai_difficulty: int = 1
var round_seconds: int = 99
var camera_shake: bool = true
var arcade: bool = false
var arcade_opponents: Array[int] = []
var arcade_index: int = 0
## Story Mode is Arcade's same matchup order with dialogue layered around
## each fight (see story_director.gd); this only marks that the dialogue
## layer is active, all progression state above still drives it.
var story: bool = false

## Builds the run's opponent order: every regular roster fighter (indices
## 0-5) except the one the player picked, in roster order, with Anant
## (index 6, always the final boss) appended last.
func begin_arcade() -> void:
	arcade_opponents.clear()
	for i in 6:
		if i != selected_fighters[0]:
			arcade_opponents.append(i)
	arcade_opponents.append(6)
	arcade_index = 0
	selected_fighters[1] = arcade_opponents[0]
	vs_ai = true

func is_final_boss() -> bool:
	return arcade and arcade_index == arcade_opponents.size() - 1

func _ready() -> void:
	for binding in [["p1_run", KEY_SHIFT], ["p2_run", KEY_CTRL]]:
		if not InputMap.has_action(binding[0]):
			InputMap.add_action(binding[0])
			var run_key := InputEventKey.new()
			run_key.physical_keycode = binding[1]
			InputMap.action_add_event(binding[0], run_key)
	if not InputMap.has_action("move_list"):
		InputMap.add_action("move_list")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F1
		InputMap.action_add_event("move_list", key)
