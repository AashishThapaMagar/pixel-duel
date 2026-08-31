extends CharacterBody2D
## A single fighter. Two of these are placed in Arena.tscn with player_id 1 and 2.
## Movement, jumping, punching, kicking, blocking and taking damage all live here.
##
## The body is a small articulated rig (Visual > Head/Torso/Arm*Pivot/Leg*Pivot)
## built from plain Polygon2D pieces — no imported art, but every state has a
## real pose driven by AnimationPlayer (idle sway, walk cycle, jump tuck,
## jab/hook/kick swings, guard stance, hit flinch). The whole rig mirrors via
## `Visual.scale.x = facing` instead of maintaining separate left/right poses.
## Team color comes from tinting the whole rig (`Visual.modulate`), and the
## small white FaceMarker sits outside that tint so it's always readable.
##
## Fighting-style tuning: Arena calls `apply_style()` at the start of each
## round with a FightStyle resource (see scripts/fight_style.gd), which
## overwrites the @export tunables below and enables that style's signature
## mechanic (Karate perfect-block, Muay Thai chip-through kicks, Boxing
## hook/combo, MMA finisher). With no style applied (e.g. testing this scene
## standalone) the @export defaults below behave exactly as before.

signal health_changed(new_health: int, max_health: int)
signal ko

enum State { IDLE, WALK, JUMP, PUNCH, KICK, BLOCK, HITSTUN, KO }

@export var player_id: int = 1          # 1 or 2 — picks which input actions to read
@export var max_health: int = 100
@export var style: FightStyle = null    # optional: preview a style directly in the Inspector

@export_group("Movement")
@export var move_speed: float = 260.0
@export var jump_velocity: float = -760.0

@export_group("Punch")
@export var punch_damage: int = 6
@export var punch_active_time: float = 0.08
@export var punch_total_time: float = 0.22
@export var punch_knockback: float = 220.0

@export_group("Kick")
@export var kick_damage: int = 12
@export var kick_active_time: float = 0.12
@export var kick_total_time: float = 0.38
@export var kick_knockback: float = 380.0

@export_group("Hook (Boxing's kick-button attack)")
@export var hook_damage: int = 9
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
@onready var face_marker: Polygon2D = $FaceMarker
@onready var visual: Node2D = $Visual
@onready var anim: AnimationPlayer = $AnimationPlayer

var health: int
var state: int = State.IDLE
var facing: int = 1
var attack_timer: float = 0.0
var attack_variant: String = "jab"   # "jab" | "hook" | "kick" | "finisher"
var stun_timer: float = 0.0
var input_prefix: String = "p1_"
var opponent: Node = null

var current_style: FightStyle = null

# How long the fighter has been continuously holding BLOCK — reset to 0 the
# instant block starts, so Karate can check "did the hit land within the
# first N seconds of guard going up" for a perfect-block parry.
var block_hold_time: float = 999.0

# Combo/finisher bookkeeping — who/when the last hit was landed BY this
# fighter, used by Boxing's damage-escalating combo and MMA's finisher window.
var combo_stacks: int = 0
var _last_land_type: String = ""
var _last_land_time: float = -999.0
var _finisher_cooldown_until: float = -999.0

const GRAVITY := 2200.0
const HITBOX_OFFSET_X := 34.0
const FACE_OFFSET_X := 18.0

func _ready() -> void:
	health = max_health
	input_prefix = "p1_" if player_id == 1 else "p2_"
	hitbox.owner_player = self
	hitbox.set_active(false)
	visual.modulate = base_color
	if style != null:
		apply_style(style)

func apply_style(new_style: FightStyle) -> void:
	current_style = new_style
	if new_style == null:
		return
	move_speed = new_style.move_speed
	jump_velocity = new_style.jump_velocity
	punch_damage = new_style.punch_damage
	punch_active_time = new_style.punch_active_time
	punch_total_time = new_style.punch_total_time
	punch_knockback = new_style.punch_knockback
	kick_damage = new_style.kick_damage
	kick_active_time = new_style.kick_active_time
	kick_total_time = new_style.kick_total_time
	kick_knockback = new_style.kick_knockback
	hook_damage = new_style.hook_damage
	hook_active_time = new_style.hook_active_time
	hook_total_time = new_style.hook_total_time
	hook_knockback = new_style.hook_knockback
	block_chip_multiplier = new_style.block_chip_multiplier

func _physics_process(delta: float) -> void:
	if state == State.KO:
		velocity.x = move_toward(velocity.x, 0, move_speed * delta)
		velocity.y += GRAVITY * delta
		move_and_slide()
		return

	velocity.y += GRAVITY * delta

	_update_facing()

	match state:
		State.HITSTUN:
			_process_hitstun(delta)
		State.PUNCH, State.KICK:
			_process_attack(delta)
		State.BLOCK:
			_process_block(delta)
		_:
			_process_move_and_actions()

	move_and_slide()

	if is_on_floor() and state == State.JUMP:
		state = State.IDLE

	_update_animation()

func _update_facing() -> void:
	visual.scale.x = facing
	if state in [State.HITSTUN, State.KO]:
		return
	if opponent == null:
		return
	if opponent.global_position.x > global_position.x:
		facing = 1
	elif opponent.global_position.x < global_position.x:
		facing = -1
	hitbox.position.x = facing * HITBOX_OFFSET_X
	face_marker.position.x = facing * FACE_OFFSET_X

# Picks the AnimationPlayer clip for the current state/attack variant and
# plays it — cheap to call every physics frame since play() only restarts
# an animation that isn't already the one running.
func _update_animation() -> void:
	var anim_name := "idle"
	match state:
		State.WALK:
			anim_name = "walk"
		State.JUMP:
			anim_name = "jump"
		State.BLOCK:
			anim_name = "block"
		State.HITSTUN:
			anim_name = "hitstun"
		State.PUNCH:
			anim_name = "hook" if attack_variant == "hook" else "punch"
		State.KICK:
			anim_name = "kick"
		_:
			anim_name = "idle"
	if anim.current_animation != anim_name or not anim.is_playing():
		anim.play(anim_name)

func _process_move_and_actions() -> void:
	var dir := 0.0
	if Input.is_action_pressed(input_prefix + "left"):
		dir -= 1.0
	if Input.is_action_pressed(input_prefix + "right"):
		dir += 1.0

	if Input.is_action_pressed(input_prefix + "block") and is_on_floor():
		if state != State.BLOCK:
			block_hold_time = 0.0
		state = State.BLOCK
		velocity.x = 0
		return

	if Input.is_action_just_pressed(input_prefix + "punch") and is_on_floor():
		_start_attack(State.PUNCH, "jab")
		return
	if Input.is_action_just_pressed(input_prefix + "kick") and is_on_floor():
		var kicks_disabled: bool = current_style != null and current_style.kicks_disabled
		if kicks_disabled:
			_start_attack(State.PUNCH, "hook")
		else:
			_start_attack(State.KICK, "kick")
		return

	if Input.is_action_just_pressed(input_prefix + "jump") and is_on_floor():
		velocity.y = jump_velocity
		state = State.JUMP
		return

	velocity.x = dir * move_speed
	if not is_on_floor():
		state = State.JUMP
	elif dir != 0:
		state = State.WALK
	else:
		state = State.IDLE

func _start_attack(new_state: int, variant: String = "jab") -> void:
	state = new_state
	attack_timer = 0.0
	velocity.x = 0
	attack_variant = variant

	# MMA finisher: a kick that lands soon after a punch upgrades in place.
	if variant == "kick" and current_style != null and current_style.has_finisher:
		var now := Time.get_ticks_msec() / 1000.0
		var within_window: bool = _last_land_type == "punch" and now - _last_land_time <= current_style.finisher_window
		var off_cooldown: bool = now >= _finisher_cooldown_until
		if within_window and off_cooldown:
			attack_variant = "finisher"
			_finisher_cooldown_until = now + current_style.finisher_cooldown
			_flash(Color(0.7, 0.2, 0.9, 1))

func _process_attack(delta: float) -> void:
	attack_timer += delta
	velocity.x = move_toward(velocity.x, 0, move_speed * 4 * delta)

	var active_time: float
	var total_time: float
	var dmg: int
	var kb: float

	match attack_variant:
		"hook":
			active_time = hook_active_time
			total_time = hook_total_time
			dmg = hook_damage
			kb = hook_knockback
		"kick":
			active_time = kick_active_time
			total_time = kick_total_time
			dmg = kick_damage
			kb = kick_knockback
		"finisher":
			active_time = kick_active_time
			total_time = kick_total_time
			dmg = int(round(kick_damage * current_style.finisher_damage_mult))
			kb = kick_knockback * current_style.finisher_knockback_mult
		_: # "jab"
			active_time = punch_active_time
			total_time = punch_total_time
			dmg = punch_damage
			kb = punch_knockback

	dmg += _combo_bonus()

	hitbox.damage = dmg
	hitbox.knockback = kb
	hitbox.attack_type = "kick" if attack_variant in ["kick", "finisher"] else "punch"
	hitbox.set_active(attack_timer <= active_time)

	if attack_timer >= total_time:
		hitbox.set_active(false)
		state = State.IDLE

func _combo_bonus() -> int:
	if current_style != null and current_style.combo_damage_step > 0:
		return combo_stacks * current_style.combo_damage_step
	return 0

# Called by our own Hitbox the moment one of our attacks connects — tracks
# the timing Boxing's combo escalation and MMA's finisher window need.
func _on_hit_landed(attack_type: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if current_style != null and current_style.combo_damage_step > 0:
		if now - _last_land_time <= current_style.combo_window:
			combo_stacks = min(combo_stacks + 1, current_style.combo_max_stacks - 1)
		else:
			combo_stacks = 0
	_last_land_type = attack_type
	_last_land_time = now

func _process_block(delta: float) -> void:
	velocity.x = 0
	block_hold_time += delta
	if not Input.is_action_pressed(input_prefix + "block"):
		state = State.IDLE

func _process_hitstun(delta: float) -> void:
	stun_timer -= delta
	velocity.x = move_toward(velocity.x, 0, move_speed * 3 * delta)
	if stun_timer <= 0:
		state = State.IDLE

func take_hit(damage: int, knockback: float, attacker_facing: int, attacker: Node = null, attack_type: String = "punch") -> void:
	if state == State.KO:
		return

	var attacker_dir: int = int(sign(attacker_facing))
	var is_blocking: bool = state == State.BLOCK and attacker_dir != facing

	# Karate: a hit that lands within the perfect-block window is a full parry
	# — zero damage, tiny pushback, and the attacker gets punished for it.
	var is_perfect: bool = false
	if is_blocking and current_style != null and current_style.perfect_block_window > 0.0:
		is_perfect = block_hold_time <= current_style.perfect_block_window

	if is_perfect:
		velocity.x = -attacker_facing * knockback * 0.15
		_flash(Color(1, 0.9, 0.3, 1))
		if attacker and attacker.has_method("apply_parry_punish"):
			attacker.apply_parry_punish()
		health_changed.emit(health, max_health)
		return

	var dealt: int = damage
	var stun: float = hitstun_time_heavy if damage >= kick_damage else hitstun_time_light

	if is_blocking:
		var chip_mult: float = block_chip_multiplier
		# Muay Thai: kicks chip through guard harder than punches do.
		if attack_type == "kick" and attacker and "current_style" in attacker and attacker.current_style != null:
			chip_mult += attacker.current_style.kick_chip_bonus
		dealt = int(ceil(damage * chip_mult))
		stun = 0.08
	else:
		state = State.HITSTUN
		stun_timer = stun

	health = max(0, health - dealt)
	velocity.x = -attacker_facing * knockback * (0.3 if is_blocking else 1.0)
	health_changed.emit(health, max_health)
	_flash(Color(0.5, 0.7, 1, 1) if is_blocking else Color(1, 0.3, 0.3, 1))

	if health <= 0:
		state = State.KO
		hurtbox.set_deferred("monitorable", false)
		var fall_tween := create_tween()
		fall_tween.tween_property(visual, "rotation", deg_to_rad(85) * facing, 0.3)
		ko.emit()
	elif not is_blocking:
		stun_timer = stun

# Karate-only: called on the ATTACKER when their swing gets perfectly
# blocked, so whiffing into a well-timed guard has a real cost.
func apply_parry_punish() -> void:
	if state == State.KO:
		return
	state = State.HITSTUN
	stun_timer = 0.2
	velocity.x = -facing * 160.0
	_flash(Color(1, 0.9, 0.3, 1))

func _flash(color: Color) -> void:
	visual.modulate = color
	var tween := create_tween()
	tween.tween_property(visual, "modulate", base_color, 0.15)

func reset_for_new_round() -> void:
	health = max_health
	state = State.IDLE
	velocity = Vector2.ZERO
	hurtbox.monitorable = true
	hitbox.set_active(false)
	visual.rotation = 0.0
	visual.modulate = base_color
	block_hold_time = 999.0
	combo_stacks = 0
	attack_variant = "jab"
	_last_land_type = ""
	_last_land_time = -999.0
	_finisher_cooldown_until = -999.0
	health_changed.emit(health, max_health)
