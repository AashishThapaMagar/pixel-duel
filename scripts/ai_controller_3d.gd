extends "res://scripts/ai_controller.gd"

func _ready() -> void:
	super._ready()
	_prefix = fighter.input_prefix

func _opponent_distance() -> float:
	# AI forward/back inputs follow the opponent around the ring.
	return fighter._opponent_distance(opponent)
