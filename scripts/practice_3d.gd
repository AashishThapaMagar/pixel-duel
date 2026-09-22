extends "res://scripts/arena_3d.gd"
## Immediate playable practice with the selected fighter and a passive rival.

func _ready() -> void:
	var previous_ai := MatchSetup.vs_ai
	MatchSetup.vs_ai = false
	super._ready()
	MatchSetup.vs_ai = previous_ai
	$UI/P2Label.text = player2.character_profile.name + " / PRACTICE DUMMY"
	$UI/ControlsHint.text = "A/D WALK   W/S SIDESTEP   SHIFT + FORWARD RUN   DOUBLE-TAP + HOLD FORWARD TO RUN\nF PUNCH   G KICK   H THROW   E GUARD   SPACE JUMP   R RESET   F1 MOVES   ESC MENU"

func _begin_round(index: int) -> void:
	super._begin_round(index)
	intro_timer = 0.0
	_hide_banner()
	player2.controls_enabled = false
	round_label.text = "FREE PRACTICE"
	pips1.hide()
	pips2.hide()

func _process(delta: float) -> void:
	time_remaining = 9999.0
	if not move_guide.visible and Input.is_action_just_pressed("restart"):
		_reset_practice()
	super._process(delta)
	timer_label.text = "--"

func _end_round(_winner: int) -> void:
	_reset_practice.call_deferred()

func _reset_practice() -> void:
	for fighter in [player1, player2]:
		fighter.reset_for_new_round()
	player2.controls_enabled = false
	combat_effects.reset()
