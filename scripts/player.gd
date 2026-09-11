extends CharacterBody2D
## Combat and animation share one physics clock.
signal health_changed(new_health: int, max_health: int)
signal ko
signal impact(point: Vector2, blocked: bool, heavy: bool)

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
var block_hold_time: float = 999.0
var combo_stacks: int = 0
var hitstop_remaining: float = 0.0
var controls_enabled: bool = true
var action_timer: float = 0.0
var combat_time: float = 0.0
var attack_connected: bool = false
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

func _physics_process(delta: float) -> void:
	# Capture presses during hit-stop, but pause their expiry and the combat clock
	# so an impact freeze does not swallow the player's follow-up input.
	if controls_enabled and state != State.KO:
		_capture_input()
	if hitstop_remaining > 0.0:
		hitstop_remaining = maxf(0.0, hitstop_remaining - delta)
		return
	combat_time += delta
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
	if not was_grounded and is_on_floor() and state == State.JUMP:
		state = State.LAND
		action_timer = LAND_TIME
	# Consume before aging: a queued action remains valid on the recovery tick.
	_buffer_remaining -= delta
	if _buffer_remaining <= 0.0:
		_buffered_action = ""
	_update_animation()

func _capture_input() -> void:
	for action in ["jump", "punch", "kick"]:
		if Input.is_action_just_pressed(input_prefix + action):
			_buffered_action = action
			_buffer_remaining = input_buffer_time
	for direction in [-1, 1]:
		var action: String = "left" if direction < 0 else "right"
		if Input.is_action_just_pressed(input_prefix + action):
			if direction == _last_tap_dir and combat_time - _last_tap_time <= 0.22:
				if state in [State.IDLE, State.WALK] and is_on_floor():
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
		var speed := move_speed * (backward_speed_ratio if direction * facing < 0.0 else 1.0)
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
	_buffered_action = ""
	_buffer_remaining = 0.0
	if action == "jump":
		state = State.JUMP_START
		action_timer = JUMP_START_TIME
		_jump_direction = Input.get_axis(input_prefix + "left", input_prefix + "right")
	elif action == "punch":
		_start_attack(State.PUNCH, "jab")
	else:
		var hook: bool = current_style != null and current_style.kicks_disabled
		_start_attack(State.PUNCH if hook else State.KICK, "hook" if hook else "kick")
	return true

func _enter_block() -> void:
	state = State.BLOCK
	block_hold_time = 0.0
	velocity.x = 0.0

func attack_startup() -> float:
	return hook_startup_time if attack_variant == "hook" else (kick_startup_time if attack_variant in ["kick", "finisher"] else punch_startup_time)

func attack_active_time() -> float:
	return hook_active_time if attack_variant == "hook" else (kick_active_time if attack_variant in ["kick", "finisher"] else punch_active_time)

func attack_duration() -> float:
	# Style data may shorten total duration, but every move still needs recovery.
	var total := hook_total_time if attack_variant == "hook" else (kick_total_time if attack_variant in ["kick", "finisher"] else punch_total_time)
	return maxf(total, attack_startup() + attack_active_time() + 0.05)

func _start_attack(new_state: int, variant: String = "jab") -> void:
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
	if attack_variant == "finisher":
		damage = int(round(damage * current_style.finisher_damage_mult))
		knockback *= current_style.finisher_knockback_mult
	hitbox.damage = damage + _combo_bonus()
	hitbox.knockback = knockback
	hitbox.attack_type = "kick" if heavy else "punch"
	var reach := 64.0 if heavy else (44.0 if attack_variant == "hook" else 58.0)
	hitbox.position = Vector2(facing * reach, -66.0 if heavy else -88.0)
	hitbox.set_active(attack_timer >= attack_startup() and attack_timer < attack_startup() + attack_active_time())
	# A confirmed jab can cancel into the heavy button once contact ends.
	if attack_connected and attack_variant == "jab" and _buffered_action == "kick" and attack_timer >= attack_startup() + attack_active_time():
		_consume_action()
		return
	if attack_timer >= attack_duration():
		hitbox.set_active(false)
		state = State.IDLE
		_process_move_and_actions(delta)

func _combo_bonus() -> int:
	if current_style != null and current_style.combo_damage_step > 0 and combat_time - _last_land_time <= current_style.combo_window:
		return combo_stacks * current_style.combo_damage_step
	return 0

func _on_hit_landed(attack_type: String) -> void:
	attack_connected = true
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
	var blocked: bool = state in [State.BLOCK, State.BLOCKSTUN] and attacker_facing != facing
	var perfect: bool = blocked and state == State.BLOCK and current_style != null and current_style.perfect_block_window > 0.0 and block_hold_time <= current_style.perfect_block_window
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
	if blocked:
		var chip := block_chip_multiplier
		if heavy and attacker != null and attacker.current_style != null:
			chip += attacker.current_style.kick_chip_bonus
		dealt = int(ceil(damage * chip))
		state = State.BLOCKSTUN
		stun_timer = 0.12 if heavy else 0.08
	else:
		state = State.HITSTUN
		stun_timer = hitstun_time_heavy if heavy else hitstun_time_light
	health = maxi(0, health - dealt)
	velocity.x = attacker_facing * knockback * (0.3 if blocked else 1.0)
	health_changed.emit(health, max_health)
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
	if _flash_tween != null:
		_flash_tween.kill()
	health = max_health
	state = State.IDLE
	velocity = Vector2.ZERO
	hurtbox.set_deferred("monitorable", true)
	hitbox.set_active(false)
	visual.modulate = Color.WHITE
	controls_enabled = true
	hitstop_remaining = 0.0
	attack_timer = 0.0
	stun_timer = 0.0
	action_timer = 0.0
	combat_time = 0.0
	block_hold_time = 999.0
	combo_stacks = 0
	attack_connected = false
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
