extends Node
## Selection survives scene changes; round restart never changes the roster.
var selected_fighters: Array[int] = [0, 1]
var selected_arena: int = 0
## 3D arena for VS Battle / VS Computer: JOURNEY_STAGE plays the four-arena
## journey, 0-3 fixes every round to that arena, RANDOM_STAGE draws one per
## match. Arcade and Story always play the journey.
const JOURNEY_STAGE := -1
const RANDOM_STAGE := 4
var stage_choice: int = JOURNEY_STAGE
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
	var bindings_3d := [
		["left", KEY_A, KEY_LEFT], ["right", KEY_D, KEY_RIGHT],
		["far", KEY_W, KEY_UP], ["near", KEY_S, KEY_DOWN],
		["jump", KEY_SPACE, KEY_ENTER], ["block", KEY_E, KEY_O],
		["punch", KEY_F, KEY_K], ["kick", KEY_G, KEY_L],
		["grapple", KEY_H, KEY_J],
		["run", KEY_SHIFT, KEY_CTRL]]
	for binding in bindings_3d:
		for player in 2:
			var action := "p%d_3d_%s" % [player + 1, binding[0]]
			if not InputMap.has_action(action):
				InputMap.add_action(action)
				var event := InputEventKey.new()
				event.physical_keycode = binding[player + 1]
				InputMap.action_add_event(action, event)
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
	_map_gamepads()

## Gamepads: pad 1 drives player one, pad 2 player two, on every action a
## key already drives (fight, select screen and the legacy 2D arena). A =
## punch, X = kick, Y = jump, right shoulder = guard, left shoulder = run,
## right trigger = grapple, stick or d-pad = move and sidestep, Start or B =
## pause, Back = movebook. Menus use Godot's own ui_* pad bindings.
const PAD := {
	"left": [JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT], "right": [JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT],
	"far": [JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP], "near": [JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN],
	"jump": [JOY_BUTTON_Y], "block": [JOY_BUTTON_RIGHT_SHOULDER], "punch": [JOY_BUTTON_A], "kick": [JOY_BUTTON_X],
	"grapple": [JOY_AXIS_TRIGGER_RIGHT, 1.0], "run": [JOY_BUTTON_LEFT_SHOULDER],
}

static func _map_gamepads() -> void:
	for player in 2:
		for key in PAD:
			for action in ["p%d_3d_%s" % [player + 1, key], "p%d_%s" % [player + 1, key]]:
				if InputMap.has_action(action):
					_pad_bind(action, player, PAD[key])
	for pair in [["ui_cancel", [JOY_BUTTON_START]], ["move_list", [JOY_BUTTON_BACK]]]:
		if InputMap.has_action(pair[0]):
			for player in 2:
				_pad_bind(pair[0], player, pair[1])

static func _pad_bind(action: String, device: int, spec: Array) -> void:
	for existing in InputMap.action_get_events(action):
		if (existing is InputEventJoypadButton or existing is InputEventJoypadMotion) and existing.device == device:
			return
	if spec.size() >= 2 and spec[1] is float:
		var motion := InputEventJoypadMotion.new()
		motion.device = device
		motion.axis = spec[0]
		motion.axis_value = spec[1]
		InputMap.action_add_event(action, motion)
		if spec.size() == 3:
			var pad := InputEventJoypadButton.new()
			pad.device = device
			pad.button_index = spec[2]
			InputMap.action_add_event(action, pad)
	else:
		var button := InputEventJoypadButton.new()
		button.device = device
		button.button_index = spec[0]
		InputMap.action_add_event(action, button)
