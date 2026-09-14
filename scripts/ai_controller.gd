extends Node
## Drives a Player node the same way a human would: by faking presses on its
## own p1_/p2_ input actions each physics tick, rather than touching Player
## internals. That keeps it decoupled from player.gd entirely.
##
## Reaction/decision timers keep it beatable — it doesn't re-plan every frame,
## and it only reacts to an incoming attack after a short human-like delay.

var fighter: Node
var opponent: Node

const ATTACK_RANGE := 92.0
const CLOSE_RANGE := 58.0
const APPROACH_RANGE := 230.0
const BLOCK_REACTION_TIME := 0.14
const DECISION_INTERVAL := 0.32

var _prefix: String = "p2_"
var _reaction_cooldown: float = 0.0
var _decision_timer: float = 0.0
var _held_block: bool = false
var _held_dir: int = 0
var _jump_cooldown: float = 0.0

func _ready() -> void:
	process_physics_priority = -100
	if fighter != null:
		_prefix = "p1_" if fighter.player_id == 1 else "p2_"

func _physics_process(delta: float) -> void:
	if fighter == null or opponent == null or not is_instance_valid(fighter) or not is_instance_valid(opponent):
		return
	if fighter.state == fighter.State.KO or opponent.state == opponent.State.KO or not fighter.controls_enabled:
		_release_all()
		return

	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	_reaction_cooldown = maxf(0.0, _reaction_cooldown - delta)
	_decision_timer -= delta

	var distance: float = opponent.global_position.x - fighter.global_position.x
	var abs_distance: float = absf(distance)
	var toward: int = 1 if distance > 0.0 else -1

	# React to an incoming attack: hold guard while it stays in range.
	var opponent_attacking: bool = opponent.state in [opponent.State.PUNCH, opponent.State.KICK] \
		and opponent.attack_timer >= opponent.attack_startup() * 0.5
	var can_engage_guard: bool = fighter.state in [fighter.State.IDLE, fighter.State.WALK, fighter.State.BLOCK]
	if opponent_attacking and abs_distance < ATTACK_RANGE + 24.0 and can_engage_guard:
		if not _held_block and _reaction_cooldown <= 0.0:
			if randf() < 0.7:
				_set_block(true)
			_reaction_cooldown = BLOCK_REACTION_TIME
	elif _held_block and (not opponent_attacking or abs_distance > ATTACK_RANGE + 24.0):
		_set_block(false)

	if _held_block:
		_set_move(0)
		return

	if _decision_timer > 0.0:
		return
	_decision_timer = DECISION_INTERVAL + randf() * 0.25

	if abs_distance > APPROACH_RANGE and _jump_cooldown <= 0.0 and randf() < 0.15:
		_tap(_prefix + "jump")
		_jump_cooldown = 1.8

	if abs_distance > ATTACK_RANGE:
		_set_move(toward)
	elif abs_distance < CLOSE_RANGE and randf() < 0.3:
		_set_move(-toward)
	else:
		_set_move(0)
		if fighter.state in [fighter.State.IDLE, fighter.State.WALK] and randf() < 0.6:
			_tap(_prefix + ("kick" if randf() < 0.4 else "punch"))

func _set_move(direction: int) -> void:
	if direction == _held_dir:
		return
	Input.action_release(_prefix + "left")
	Input.action_release(_prefix + "right")
	if direction < 0:
		Input.action_press(_prefix + "left")
	elif direction > 0:
		Input.action_press(_prefix + "right")
	_held_dir = direction

func _set_block(active: bool) -> void:
	_held_block = active
	if active:
		Input.action_press(_prefix + "block")
	else:
		Input.action_release(_prefix + "block")

func _tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)

func _release_all() -> void:
	for suffix in ["left", "right", "block", "jump", "punch", "kick"]:
		Input.action_release(_prefix + suffix)
	_held_dir = 0
	_held_block = false
