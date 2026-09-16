extends CharacterBody2D
## Combat and animation share one physics clock.
signal health_changed(new_health: int, max_health: int)
signal ko
signal impact(point: Vector2, blocked: bool, heavy: bool)

const ROSTER := preload("res://scripts/fighter_roster.gd")
const MOVES := preload("res://scripts/move_catalog.gd")
const MOTIONS := preload("res://scripts/motion_input.gd")
const ACTION_MOVES := preload("res://scripts/action_moves.gd")

enum State { IDLE, WALK, JUMP, PUNCH, KICK, BLOCK, HITSTUN, KO, BLOCKSTUN, DASH, JUMP_START, LAND }

@export var player_id: int = 1
@export var max_health: int = 100
@export var style: FightStyle = null
@export_group("Movement")
@export var move_speed: float = 260.0
@export var jump_velocity: float = -760.0
@export var acceleration: float = 3800.0
@export var braking: float = 5200.0
@export var backward_speed_ratio: float = 0.72
@export var input_buffer_time: float = 0.13
@export_group("Punch")
@export var punch_damage: int = 6
@export var punch_startup_time: float = 0.05
@export var punch_active_time: float = 0.08
@export var punch_total_time: float = 0.22
@export var punch_knockback: float = 220.0
@export_group("Kick")
@export var kick_damage: int = 12
@export var kick_startup_time: float = 0.1
@export var kick_active_time: float = 0.12
@export var kick_total_time: float = 0.38
@export var kick_knockback: float = 380.0
@export_group("Hook")
@export var hook_damage: int = 9
@export var hook_startup_time: float = 0.075
@export var hook_active_time: float = 0.09
@export var hook_total_time: float = 0.26
@export var hook_knockback: float = 260.0
@export_group("Guard & Stun")
@export var hitstun_time_light: float = 0.25
@export var hitstun_time_heavy: float = 0.5
@export var block_chip_multiplier: float = 0.15
@export_group("Appearance")
@export var base_color: Color = Color(0.2, 0.4, 0.9, 1)

@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox
@onready var visual: Node2D = $Visual
var health: int
var state: int = State.IDLE
var facing: int = 1
var attack_timer: float = 0.0
var attack_variant: String = "jab"
var stun_timer: float = 0.0
var input_prefix: String = "p1_"
var opponent: Node = null
var current_style: FightStyle = null
var character_index: int = 0
var character_profile: Dictionary = ROSTER.profile(0)
var block_hold_time: float = 999.0
var combo_stacks: int = 0
var hitstop_remaining: float = 0.0
var controls_enabled: bool = true
var combat_paused: bool = false
var running: bool = false
const WALK_SPEED_RATIO := 0.65
var action_timer: float = 0.0
var combat_time: float = 0.0
var attack_connected: bool = false
var current_move: Dictionary = {}
var chain_step: int = 0
var combo_hits: int = 0
var combo_damage: int = 0
var motion_input := MOTIONS.new()
var _buffered_move: String = ""
var _motion_facing: int = 1
var combat_notice: String = ""
var notice_until: float = 0.0
var _combo_attacker: Node = null
var _received_hits: int = 0
var _buffered_direction: int = 0
var _buffered_action: String = ""
var _buffer_remaining: float = 0.0
var _last_tap_dir: int = 0
var _last_tap_time: float = -999.0
var _dash_dir: int = 1
var _jump_direction: float = 0.0
var _last_land_type: String = ""
var _last_land_time: float = -999.0
var _finisher_cooldown_until: float = -999.0
var _flash_tween: Tween
var stamina: float = 100.0
var stamina_delay: float = 0.0
var taunt_ready_at: float = 0.0
var throw_tech_until: float = -1.0

## "action" is the style_id of resources/styles/action.tres, the one style
## resource live matches now use for all four rounds. Archived styles
## (karate/muay_thai/boxing/mma) still load in the regression tests, so this
## flag is how stamina, throws, guard breaks and per-fighter moves stay
## opt-in instead of changing behavior for that legacy coverage.
func is_action_fight() -> bool:
	return current_style != null and current_style.style_id == "action"

func spend_stamina(amount: float) -> bool:
	if not is_action_fight():
		return true
	if stamina < amount:
		combat_notice = "CATCH YOUR BREATH"
		notice_until = combat_time + 0.6
		return false
	stamina -= amount
	stamina_delay = 0.65
	return true

func available_moves() -> Dictionary:
	if is_action_fight():
		return ACTION_MOVES.for_fighter(character_profile.id)
	return MOVES.for_style(current_style.style_id if current_style != null else "karate")

const GRAVITY := 2200.0
const DASH_DURATION := 0.16
const JUMP_START_TIME := 0.05
const LAND_TIME := 0.05

func _ready() -> void:
	health = max_health
	input_prefix = "p1_" if player_id == 1 else "p2_"
	hitbox.owner_player = self
	hitbox.set_active(false)
	if style != null:
		apply_style(style)
	_update_animation()

func apply_style(new_style: FightStyle) -> void:
	current_style = new_style
	if new_style == null:
		return
	for property in ["move_speed", "jump_velocity", "punch_damage", "punch_startup_time",
		"punch_active_time", "punch_total_time", "punch_knockback", "kick_damage",
		"kick_startup_time", "kick_active_time", "kick_total_time", "kick_knockback",
		"hook_damage", "hook_startup_time", "hook_active_time", "hook_total_time",
		"hook_knockback", "block_chip_multiplier"]:
		set(property, new_style.get(property))
	# Always start with resource values so bonuses cannot stack between rounds.
	move_speed *= float(character_profile.speed)
	punch_damage += int(character_profile.punch_bonus)
	hook_damage += int(character_profile.punch_bonus)
	kick_damage += int(character_profile.kick_bonus)
	block_chip_multiplier = maxf(0.0, block_chip_multiplier + float(character_profile.chip_bonus))

func apply_character(index: int) -> void:
	character_index = clampi(index, 0, ROSTER.PROFILES.size() - 1)
	character_profile = ROSTER.profile(character_index)
	stamina = character_profile.stamina
	base_color = character_profile.color
	if current_style != null:
		apply_style(current_style)
	if is_node_ready():
		_update_animation()

func _physics_process(delta: float) -> void:
	running = false
	# Capture presses during hit-stop, but pause their expiry and the combat clock
	# so an impact freeze does not swallow the player's follow-up input.
	if controls_enabled and state != State.KO:
		_capture_input()
	if hitstop_remaining > 0.0:
		hitstop_remaining = maxf(0.0, hitstop_remaining - delta)
		return
	combat_time += delta
	stamina_delay = maxf(0.0, stamina_delay - delta)
	if is_action_fight() and controls_enabled and stamina_delay <= 0.0 and state in [State.IDLE, State.WALK, State.JUMP]:
		stamina = minf(character_profile.stamina, stamina + float(character_profile.regen) * delta)
	if combat_time - _last_land_time > (current_style.combo_window if current_style != null else 0.6):
		combo_stacks = 0
	_update_facing()
	var was_grounded := is_on_floor()
	velocity.y += GRAVITY * delta
	if not controls_enabled or state == State.KO:
		velocity.x = move_toward(velocity.x, 0.0, braking * delta)
	else:
		match state:
			State.HITSTUN, State.BLOCKSTUN:
				_process_hitstun(delta)
			State.PUNCH, State.KICK:
				_process_attack(delta)
			State.BLOCK:
				_process_block(delta)
			State.DASH:
				running = _dash_dir == facing
				action_timer -= delta
				velocity.x = _dash_dir * move_speed * (1.85 if _dash_dir == facing else 1.45)
				if action_timer <= 0.0:
					state = State.IDLE
				if _dash_dir == facing:
					_consume_action()
				if Input.is_action_pressed(input_prefix + "block"):
					_enter_block()
			State.JUMP_START:
				action_timer -= delta
				if action_timer <= 0.0:
					velocity.y = jump_velocity
					velocity.x = _jump_direction * move_speed
					state = State.JUMP
			State.LAND:
				velocity.x = move_toward(velocity.x, 0.0, braking * delta)
				action_timer -= delta
				if action_timer <= 0.0:
					state = State.IDLE
					_process_move_and_actions(delta)
			_:
				_process_move_and_actions(delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, 34.0, 926.0)
	_resolve_body_overlap()
	if not was_grounded and is_on_floor() and state == State.JUMP:
		state = State.LAND
		action_timer = LAND_TIME
	# Consume before aging: a queued action remains valid on the recovery tick.
	_buffer_remaining -= delta
	if _buffer_remaining <= 0.0:
		_buffered_action = ""
		_buffered_move = ""
	_update_animation()

func _resolve_body_overlap() -> void:
	# Rivals are horizontal pushboxes, never floors or moving platforms.
	# Leave room to jump over them, then separate sideways while landing.
	if not is_instance_valid(opponent):
		return
	if absf(global_position.y - opponent.global_position.y) >= 100.0:
		return
	var distance: float = opponent.global_position.x - global_position.x
	var overlap := 38.0 - absf(distance)
	if overlap <= 0.0:
		return
	var side := signf(distance) if absf(distance) > 0.01 else float(facing)
	var own_x := global_position.x
	var other_x: float = opponent.global_position.x
	global_position.x = clampf(own_x - side * overlap * 0.5, 34.0, 926.0)
	var moved := absf(global_position.x - own_x)
	opponent.global_position.x = clampf(other_x + side * (overlap - moved), 34.0, 926.0)
	var remaining: float = 38.0 - absf(opponent.global_position.x - global_position.x)
	if remaining > 0.0:
		global_position.x = clampf(global_position.x - side * remaining, 34.0, 926.0)
	if velocity.x * side > 0.0:
		velocity.x = 0.0

func _capture_input() -> void:
	# Throw tech: tapping Light + Heavy together opens a 0.16s window (checked
	# in take_hit) during which an incoming grapple is escaped instead of landing.
	if Input.is_action_pressed(input_prefix + "punch") and Input.is_action_pressed(input_prefix + "kick") and (Input.is_action_just_pressed(input_prefix + "punch") or Input.is_action_just_pressed(input_prefix + "kick")):
		throw_tech_until = combat_time + 0.16
		return
	if facing != _motion_facing:
		motion_input.reset()
		_motion_facing = facing
	var horizontal := int(Input.get_axis(input_prefix + "left", input_prefix + "right")) * facing
	var down := Input.is_action_pressed(input_prefix + "block")
	motion_input.record((2 + horizontal) if down else (5 + horizontal), combat_time)
	for action in ["jump", "punch", "kick"]:
		if Input.is_action_just_pressed(input_prefix + action):
			_buffered_action = action
			_buffer_remaining = input_buffer_time
			_buffered_direction = int(Input.get_axis(input_prefix + "left", input_prefix + "right")) * facing
			_buffered_move = motion_input.consume(combat_time) if action == "kick" else ""
	for direction in [-1, 1]:
		var action: String = "left" if direction < 0 else "right"
		if Input.is_action_just_pressed(input_prefix + action):
			if direction == _last_tap_dir and combat_time - _last_tap_time <= 0.22:
				if state in [State.IDLE, State.WALK] and is_on_floor() and spend_stamina(7.0):
					state = State.DASH
					_dash_dir = direction
					action_timer = DASH_DURATION
				_last_tap_dir = 0
			else:
				_last_tap_dir = direction
			_last_tap_time = combat_time

func _update_facing() -> void:
	# Strikes and jumps commit to their initial facing.
	if opponent != null and state in [State.IDLE, State.WALK, State.BLOCK, State.LAND]:
		var distance: float = opponent.global_position.x - global_position.x
		if absf(distance) > 1.0:
			facing = 1 if distance > 0.0 else -1

func _update_animation() -> void:
	if visual.has_method("sync_pose"):
		visual.sync_pose(self)
	elif visual is AnimatedSprite2D:
		visual.flip_h = facing < 0
		var names := ["idle", "walk", "jump", "punch", "kick", "block", "hitstun", "ko", "block", "walk", "jump", "idle"]
		var anim: String = names[state]
		if state == State.PUNCH and attack_variant == "hook":
			anim = "hook"
		visual.play(anim)
		if state in [State.PUNCH, State.KICK]:
			visual.pause()
			visual.frame = 0 if attack_timer < attack_startup() else (1 if attack_timer < attack_startup() + attack_active_time() else 2)

func _process_move_and_actions(delta: float = 1.0 / 60.0) -> void:
	var direction := Input.get_axis(input_prefix + "left", input_prefix + "right")
	if is_on_floor():
		if Input.is_action_pressed(input_prefix + "block"):
			_enter_block()
			return
		if _consume_action():
			return
		running = direction * facing > 0.0 and Input.is_action_pressed(input_prefix + "run")
		var speed := move_speed * (1.0 if running else WALK_SPEED_RATIO)
		if not running and direction * facing < 0.0:
			speed *= backward_speed_ratio
		velocity.x = move_toward(velocity.x, direction * speed, (braking if direction == 0.0 else acceleration) * delta)
		state = State.WALK if absf(velocity.x) > 8.0 else State.IDLE
	else:
		if direction != 0.0:
			velocity.x = move_toward(velocity.x, direction * move_speed, acceleration * 0.12 * delta)
		state = State.JUMP

func _consume_action() -> bool:
	if _buffered_action.is_empty() or not is_on_floor():
		return false
	var action := _buffered_action
	var direction := _buffered_direction
	var command := _buffered_move
	# A neutral (no-direction) buffer continues the current chain; a directional
	# press always starts a fresh directional move instead of linking.
	var next_id := _next_chain_move(action) if direction == 0 else ""
	_buffered_action = ""
	_buffered_move = ""
	_buffer_remaining = 0.0
	if action == "jump":
		state = State.JUMP_START
		action_timer = JUMP_START_TIME
		_jump_direction = Input.get_axis(input_prefix + "left", input_prefix + "right")
	else:
		if not command.is_empty():
			_start_style_move(command, chain_step + 1 if state in [State.PUNCH, State.KICK] else 0)
		elif not next_id.is_empty():
			_start_style_move(next_id, chain_step + 1)
		else:
			var move_id := "jab" if action == "punch" else "kick"
			if direction > 0:
				move_id = "cross" if action == "punch" else "forward_heavy"
			elif direction < 0:
				move_id = "hook" if action == "punch" else "back_heavy"
			_start_style_move(move_id)
	return true

func _next_chain_move(action: String) -> String:
	if current_move.is_empty() or not attack_connected or chain_step >= 2:
		return ""
	if action == "punch":
		return current_move.next_light
	if action == "kick":
		return current_move.next_heavy
	return ""

func _start_style_move(move_id: String, step: int = 0) -> void:
	var data: Dictionary = available_moves()[move_id]
	# "utility" moves (Abhi's taunt, Sup's feint) deal no damage and never
	# open a hitbox (see _process_attack) — they're on their own cooldown gate.
	if data.get("utility", "") == "taunt" and combat_time < taunt_ready_at:
		combat_notice = "LET THE FISTS TALK"
		notice_until = combat_time + 0.6
		return
	if not spend_stamina(float(data.get("cost", 0.0))):
		return
	if data.get("utility", "") == "taunt":
		taunt_ready_at = combat_time + 5.0
		combat_notice = "IS THAT ALL YOU GOT?"
		notice_until = combat_time + 0.9
	_start_attack(State.KICK if data.kind == "kick" else State.PUNCH, data.pose)
	current_move = data
	chain_step = step
	_update_animation()

func move_name() -> String:
	if not current_move.is_empty():
		return str(current_move.name) + (" / FINISHER" if attack_variant == "finisher" else "")
	return attack_variant.capitalize()

func _enter_block() -> void:
	state = State.BLOCK
	block_hold_time = 0.0
	velocity.x = 0.0

func attack_startup() -> float:
	if not current_move.is_empty():
		return current_move.startup
	return hook_startup_time if attack_variant == "hook" else (kick_startup_time if attack_variant in ["kick", "finisher"] else punch_startup_time)

func attack_active_time() -> float:
	if not current_move.is_empty():
		return current_move.active
	return hook_active_time if attack_variant == "hook" else (kick_active_time if attack_variant in ["kick", "finisher"] else punch_active_time)

func attack_duration() -> float:
	if not current_move.is_empty():
		return current_move.startup + current_move.active + current_move.recovery
	# Style data may shorten total duration, but every move still needs recovery.
	var total := hook_total_time if attack_variant == "hook" else (kick_total_time if attack_variant in ["kick", "finisher"] else punch_total_time)
	return maxf(total, attack_startup() + attack_active_time() + 0.05)

func _start_attack(new_state: int, variant: String = "jab") -> void:
	current_move = {}
	chain_step = 0
	hitbox.set_active(false)
	state = new_state
	attack_timer = 0.0
	attack_connected = false
	velocity.x = 0.0
	attack_variant = variant
	if variant == "kick" and current_style != null and current_style.has_finisher:
		if _last_land_type == "punch" and combat_time - _last_land_time <= current_style.finisher_window and combat_time >= _finisher_cooldown_until:
			attack_variant = "finisher"
			_finisher_cooldown_until = combat_time + current_style.finisher_cooldown
			_flash(Color(0.85, 0.55, 1.0))
	_update_animation()

func _process_attack(delta: float) -> void:
	attack_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, braking * delta)
	var heavy: bool = attack_variant in ["kick", "finisher"]
	var damage: int = kick_damage if heavy else (hook_damage if attack_variant == "hook" else punch_damage)
	var knockback: float = kick_knockback if heavy else (hook_knockback if attack_variant == "hook" else punch_knockback)
	if not current_move.is_empty():
		heavy = current_move.kind == "kick"
		var base: int = punch_damage if current_move.base == "punch" else (hook_damage if current_move.base == "hook" else kick_damage)
		# Scaling is applied by the defender to every uninterrupted combo,
		# including manual links. Early punches retain close-range pressure.
		damage = maxi(1, int(round(base * float(current_move.damage))))
		knockback = (kick_knockback if heavy else punch_knockback) * float(current_move.push)
		velocity.x = facing * float(current_move.lunge) / attack_startup() if attack_timer < attack_startup() else 0.0
	if attack_variant == "finisher":
		damage = int(round(damage * current_style.finisher_damage_mult))
		knockback *= current_style.finisher_knockback_mult
	hitbox.damage = damage + _combo_bonus()
	hitbox.knockback = knockback
	hitbox.attack_type = "kick" if heavy else "punch"
	var reach := 64.0 if heavy else (44.0 if attack_variant == "hook" else 58.0)
	hitbox.position = Vector2(facing * reach, -66.0 if heavy else -88.0)
	if not current_move.is_empty():
		hitbox.position = Vector2(facing * float(current_move.reach), float(current_move.height))
	hitbox.set_active(current_move.get("utility", "").is_empty() and attack_timer >= attack_startup() and attack_timer < attack_startup() + attack_active_time())
	# A fresh buffered press and a confirmed hit are required. Cancels close
	# six frames into recovery; holding an attack never advances the string.
	if not current_move.is_empty():
		var active_end := attack_startup() + attack_active_time()
		var cancel_open: bool = attack_connected and attack_timer >= active_end and attack_timer <= active_end + float(current_move.cancel_window)
		var normal_route: bool = _buffered_move.is_empty() and _buffered_direction == 0 and not _next_chain_move(_buffered_action).is_empty()
		var special_route: bool = not _buffered_move.is_empty() and current_move.special_cancel and chain_step < 2
		if cancel_open and _buffer_remaining > 0.0 and (normal_route or special_route):
			_consume_action()
			return
	# A confirmed jab can cancel into the heavy button once contact ends.
	if current_move.is_empty() and attack_connected and attack_variant == "jab" and _buffered_action == "kick" and attack_timer >= attack_startup() + attack_active_time():
		_consume_action()
		return
	if attack_timer >= attack_duration():
		# Reaching the end of the animation uninterrupted is the payoff for
		# taunting; take_hit clears current_move on interruption, so a hit
		# taken mid-taunt never reaches this branch and grants nothing.
		if current_move.get("utility", "") == "taunt":
			stamina = minf(character_profile.stamina, stamina + 24.0)
		hitbox.set_active(false)
		current_move = {}
		chain_step = 0
		state = State.IDLE
		_process_move_and_actions(delta)

func _combo_bonus() -> int:
	if current_style != null and current_style.combo_damage_step > 0 and combat_time - _last_land_time <= current_style.combo_window:
		return combo_stacks * current_style.combo_damage_step
	return 0

func _on_hit_landed(attack_type: String, continued: bool = false, dealt: int = 0) -> void:
	attack_connected = true
	combo_hits = combo_hits + 1 if continued else 1
	combo_damage = combo_damage + dealt if continued else dealt
	if current_style != null and current_style.combo_damage_step > 0:
		combo_stacks = mini(combo_stacks + 1, current_style.combo_max_stacks - 1) if combat_time - _last_land_time <= current_style.combo_window else mini(1, current_style.combo_max_stacks - 1)
	_last_land_type = attack_type
	_last_land_time = combat_time

func _process_block(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, braking * delta)
	block_hold_time += delta
	if not Input.is_action_pressed(input_prefix + "block"):
		state = State.IDLE
		_process_move_and_actions(delta)

func _process_hitstun(delta: float) -> void:
	stun_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, move_speed * 3.0 * delta)
	if state == State.BLOCKSTUN:
		block_hold_time += delta
	if stun_timer <= 0.0:
		if state == State.BLOCKSTUN and Input.is_action_pressed(input_prefix + "block") and is_on_floor():
			# Holding guard through blockstun must not re-arm Karate's parry.
			state = State.BLOCK
			return
		state = State.IDLE if is_on_floor() else State.JUMP
		_process_move_and_actions(delta)

## Returns true only for an unblocked hit; chip and parries cannot grant a cancel.
func take_hit(damage: int, knockback: float, attacker_facing: int, attacker: Node = null, attack_type: String = "punch") -> bool:
	if state == State.KO or not controls_enabled:
		return false
	var move: Dictionary = attacker.current_move if attacker != null else {}
	var grapple: bool = move.get("kind", "") == "grapple"
	if grapple:
		# Throws lose to jumps, active hitstun, spacing, or a timed two-button tech.
		if not is_on_floor() or state in [State.HITSTUN, State.BLOCKSTUN] or absf(global_position.x - attacker.global_position.x) > 64.0:
			return false
		if combat_time <= throw_tech_until:
			combat_notice = "THROW ESCAPE"
			notice_until = combat_time + 0.9
			throw_tech_until = -1.0
			attacker.apply_parry_punish()
			velocity.x = attacker_facing * 140.0
			return false
	var blocked: bool = state in [State.BLOCK, State.BLOCKSTUN] and attacker_facing != facing
	# Holding away from the rival guards grounded strikes without turning
	# the fighter around. Retreat still loses to throws and guard breaks.
	var back_held := Input.get_axis(input_prefix + "left", input_prefix + "right") * facing < 0.0
	if is_action_fight() and is_on_floor() and state in [State.IDLE, State.WALK] and back_held and attacker_facing != facing:
		blocked = true
	blocked = blocked and not grapple
	var attacking := state in [State.PUNCH, State.KICK]
	var counter: bool = not blocked and attacking and attack_timer < attack_startup()
	var punish: bool = not blocked and attacking and attack_timer >= attack_startup() + attack_active_time()
	var continued: bool = state == State.HITSTUN and stun_timer > 0.0 and _combo_attacker == attacker
	var parry_window: float = current_style.perfect_block_window if current_style != null else 0.0
	if is_action_fight() and character_profile.id == "anug":
		parry_window = 0.12
	var perfect: bool = blocked and state == State.BLOCK and parry_window > 0.0 and block_hold_time <= parry_window
	var guard_broken := false
	if blocked and not perfect and is_action_fight():
		# Abhi's trait is extra guard chip: blocking him drains stamina faster.
		var guard_cost := damage * (1.1 if character_profile.id == "abhi" else 0.6)
		guard_broken = stamina < guard_cost
		stamina = maxf(0.0, stamina - guard_cost)
		stamina_delay = 0.8
		if guard_broken:
			blocked = false
			combat_notice = "GUARD BREAK"
			notice_until = combat_time + 1.0
	hitbox.set_active(false)
	var heavy := attack_type == "kick"
	var freeze := 0.075 if heavy else 0.045
	hitstop_remaining = freeze
	if attacker != null:
		attacker.hitstop_remaining = freeze
	impact.emit(global_position + Vector2(-attacker_facing * 16.0, -66.0 if heavy else -88.0), blocked, heavy)
	if perfect:
		velocity.x = attacker_facing * knockback * 0.15
		_flash(Color(1.0, 0.9, 0.3))
		if attacker != null and attacker.has_method("apply_parry_punish"):
			attacker.apply_parry_punish()
		return false
	var dealt := damage
	# Ish's weak knee: unblocked low strikes (height close to the ground,
	# i.e. not a punch/kick aimed at the torso or head) deal 25% extra.
	if is_action_fight() and character_profile.id == "ish" and not blocked and float(move.get("height", -88.0)) >= -65.0:
		damage = roundi(damage * 1.25)
		dealt = damage
	if not blocked:
		motion_input.reset()
		_received_hits = _received_hits + 1 if continued else 1
		_combo_attacker = attacker
		if not move.is_empty():
			var scaling := maxf(0.4, 1.0 - (_received_hits - 1) * 0.15)
			dealt = maxi(1, roundi(damage * scaling * (1.2 if counter else 1.0)))
		if attacker != null and (counter or punish):
			attacker.combat_notice = "COUNTER HIT" if counter else "PUNISH"
			attacker.notice_until = attacker.combat_time + 0.9
	if blocked:
		var chip := block_chip_multiplier
		if heavy and attacker != null and attacker.current_style != null:
			chip += attacker.current_style.kick_chip_bonus
		dealt = int(ceil(damage * chip))
		state = State.BLOCKSTUN
		stun_timer = float(move.blockstun) if not move.is_empty() else (0.12 if heavy else 0.08)
	else:
		state = State.HITSTUN
		stun_timer = float(move.hitstun) if not move.is_empty() else (hitstun_time_heavy if heavy else hitstun_time_light)
		if counter and not move.is_empty():
			stun_timer += 6.0 / 60.0
		if guard_broken:
			stun_timer = maxf(stun_timer, 0.55)
		if grapple:
			velocity.y = -260.0
			stun_timer = 0.55
	health = maxi(0, health - dealt)
	velocity.x = attacker_facing * knockback * (0.3 if blocked else 1.0)
	health_changed.emit(health, max_health)
	current_move = {}
	attack_connected = false
	chain_step = 0
	_flash(Color(0.65, 0.85, 1.0) if blocked else Color(1.0, 0.65, 0.55))
	if health <= 0:
		state = State.KO
		hurtbox.set_deferred("monitorable", false)
		ko.emit()
	_update_animation()
	return not blocked

func apply_parry_punish() -> void:
	if state == State.KO:
		return
	hitbox.set_active(false)
	state = State.HITSTUN
	stun_timer = 0.2
	velocity.x = -facing * 160.0
	_flash(Color(1.0, 0.9, 0.3))
	_update_animation()

func _flash(color: Color) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	visual.modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(visual, "modulate", Color.WHITE, 0.15)

func reset_for_new_round() -> void:
	running = false
	stamina = character_profile.stamina
	stamina_delay = 0.0
	taunt_ready_at = 0.0
	throw_tech_until = -1.0
	if _flash_tween != null:
		_flash_tween.kill()
	health = max_health
	state = State.IDLE
	velocity = Vector2.ZERO
	hurtbox.set_deferred("monitorable", true)
	hitbox.set_active(false)
	visual.modulate = Color.WHITE
	controls_enabled = true
	combat_paused = false
	hitstop_remaining = 0.0
	attack_timer = 0.0
	stun_timer = 0.0
	action_timer = 0.0
	combat_time = 0.0
	block_hold_time = 999.0
	combo_stacks = 0
	attack_connected = false
	current_move = {}
	chain_step = 0
	combo_hits = 0
	combo_damage = 0
	motion_input.reset()
	_motion_facing = facing
	_buffered_move = ""
	combat_notice = ""
	notice_until = 0.0
	_combo_attacker = null
	_received_hits = 0
	_buffered_direction = 0
	attack_variant = "jab"
	_buffered_action = ""
	_buffer_remaining = 0.0
	_last_tap_dir = 0
	_last_tap_time = -999.0
	_last_land_type = ""
	_last_land_time = -999.0
	_finisher_cooldown_until = -999.0
	_update_facing()
	if visual.has_method("reset_pose"):
		visual.reset_pose()
	_update_animation()
	health_changed.emit(health, max_health)
