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
var _attack_seen_time: float = 0.0
var _combo_reaction: float = 0.0

func _ready() -> void:
	process_physics_priority = -100
	if fighter != null:
		_prefix = "p1_" if fighter.player_id == 1 else "p2_"

func _physics_process(delta: float) -> void:
	if fighter == null or opponent == null or not is_instance_valid(fighter) or not is_instance_valid(opponent):
		return
	if fighter.state == fighter.State.KO or opponent.state == opponent.State.KO or not fighter.controls_enabled or fighter.combat_paused or not fighter.is_physics_processing():
		_release_all()
		return

	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	_reaction_cooldown = maxf(0.0, _reaction_cooldown - delta)
	_decision_timer -= delta

	var distance: float = _opponent_distance()
	var abs_distance: float = absf(distance)
	var toward: int = 1 if distance > 0.0 else -1

	# React to an incoming attack: hold guard while it stays in range.
	var opponent_attacking: bool = opponent.state in [opponent.State.PUNCH, opponent.State.KICK] \
		and opponent.attack_timer >= opponent.attack_startup() * 0.5
	# _attack_seen_time requires an attack to stay visible for a beat before
	# guarding it, rather than reacting on the very first frame it starts.
	_attack_seen_time = _attack_seen_time + delta if opponent_attacking else 0.0
	# Anant is tuned slightly sharper than the regular roster: he reacts to
	# attacks sooner, decides more often, and follows a landed hit into the
	# command ender rather than only jabbing — but with no stat or HP edge.
	var boss: bool = fighter.character_profile.id == "anant"
	var reaction_scale: float = [1.55, 1.0, 0.8][MatchSetup.ai_difficulty]
	# After a landed hit, wait a beat (matching a human's reaction) then
	# continue the chain, same as a buffered player input would.
	if fighter.attack_connected and fighter.state in [fighter.State.PUNCH, fighter.State.KICK]:
		_combo_reaction += delta
		if _combo_reaction > 0.07 * reaction_scale and fighter.chain_step < 2 and fighter._buffered_action.is_empty():
			_request_move("drive" if boss and fighter.chain_step == 1 and fighter.stamina > 24 else "jab")
			_combo_reaction = -0.3
	else:
		_combo_reaction = 0.0
	var can_engage_guard: bool = fighter.state in [fighter.State.IDLE, fighter.State.WALK, fighter.State.BLOCK]
	if opponent_attacking and _attack_seen_time >= (0.12 if boss else 0.18) * reaction_scale and abs_distance < ATTACK_RANGE + 24.0 and can_engage_guard:
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
	_decision_timer *= reaction_scale
	if boss:
		_decision_timer *= 0.7
	# Low on stamina: retreat instead of attacking into a possible guard break.
	if fighter.stamina < 18.0:
		_set_block(false)
		_set_move(-toward if abs_distance < 180.0 else 0)
		return

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
			var move_id := "jab"
			# Sab's forward_heavy is his grab, so he reaches for it in close
			# range; Abhi's back_heavy is his taunt, used to bank stamina
			# only when he's not already flush against the opponent.
			if fighter.character_profile.id == "sab" and abs_distance < 62 and randf() < 0.5:
				move_id = "forward_heavy"
			elif fighter.character_profile.id == "abhi" and fighter.stamina < 55 and abs_distance > 85:
				move_id = "back_heavy"
			elif randf() < 0.35:
				move_id = "drive" if randf() < 0.5 else "breaker"
			elif randf() < 0.4:
				move_id = "kick"
			_request_move(move_id)

func _opponent_distance() -> float:
	return opponent.global_position.x - fighter.global_position.x

func _request_move(id: String) -> void:
	# AI decisions enter the same expiring buffer and hit-confirm rules as input.
	fighter._buffered_action = "punch" if id == "jab" else "kick"
	fighter._buffered_direction = 1 if id == "forward_heavy" else (-1 if id == "back_heavy" else 0)
	fighter._buffered_move = id if id in ["drive", "breaker"] else ""
	fighter._buffer_remaining = fighter.input_buffer_time

func _exit_tree() -> void:
	_release_all()

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
