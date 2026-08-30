extends CharacterBody2D
## A single fighter. Two of these are placed in Arena.tscn with player_id 1 and 2.
## Movement, jumping, punching, kicking, blocking and taking damage all live here.
## No animations/sprites yet — the ColorRect body and a small "face" marker are
## placeholders so the game is playable before any art exists.

signal health_changed(new_health: int, max_health: int)
signal ko

enum State { IDLE, WALK, JUMP, PUNCH, KICK, BLOCK, HITSTUN, KO }

@export var player_id: int = 1          # 1 or 2 — picks which input actions to read
@export var max_health: int = 100
@export var move_speed: float = 260.0
@export var jump_velocity: float = -760.0
@export var punch_damage: int = 6
@export var punch_active_time: float = 0.08
@export var punch_total_time: float = 0.22
@export var kick_damage: int = 12
@export var kick_active_time: float = 0.12
@export var kick_total_time: float = 0.38
@export var hitstun_time_light: float = 0.25
@export var hitstun_time_heavy: float = 0.5
@export var block_chip_multiplier: float = 0.15
@export var base_color: Color = Color(0.2, 0.4, 0.9, 1)

@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox
@onready var face_marker: Polygon2D = $FaceMarker
@onready var body_rect: Polygon2D = $Body

var health: int
var state: int = State.IDLE
var facing: int = 1
var attack_timer: float = 0.0
var stun_timer: float = 0.0
var input_prefix: String = "p1_"
var opponent: Node = null

const GRAVITY := 2200.0
const HITBOX_OFFSET_X := 34.0
const FACE_OFFSET_X := 18.0

func _ready() -> void:
	health = max_health
	input_prefix = "p1_" if player_id == 1 else "p2_"
	hitbox.owner_player = self
	hitbox.set_active(false)
	body_rect.color = base_color

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
			_process_block()
		_:
			_process_move_and_actions()

	move_and_slide()

	if is_on_floor() and state == State.JUMP:
		state = State.IDLE

func _update_facing() -> void:
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

func _process_move_and_actions() -> void:
	var dir := 0.0
	if Input.is_action_pressed(input_prefix + "left"):
		dir -= 1.0
	if Input.is_action_pressed(input_prefix + "right"):
		dir += 1.0

	if Input.is_action_pressed(input_prefix + "block") and is_on_floor():
		state = State.BLOCK
		velocity.x = 0
		return

	if Input.is_action_just_pressed(input_prefix + "punch") and is_on_floor():
		_start_attack(State.PUNCH)
		return
	if Input.is_action_just_pressed(input_prefix + "kick") and is_on_floor():
		_start_attack(State.KICK)
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

func _start_attack(new_state: int) -> void:
	state = new_state
	attack_timer = 0.0
	velocity.x = 0

func _process_attack(delta: float) -> void:
	attack_timer += delta
	velocity.x = move_toward(velocity.x, 0, move_speed * 4 * delta)

	var active_time = punch_active_time if state == State.PUNCH else kick_active_time
	var total_time = punch_total_time if state == State.PUNCH else kick_total_time

	hitbox.damage = punch_damage if state == State.PUNCH else kick_damage
	hitbox.knockback = 220.0 if state == State.PUNCH else 380.0
	hitbox.set_active(attack_timer <= active_time)

	if attack_timer >= total_time:
		hitbox.set_active(false)
		state = State.IDLE

func _process_block() -> void:
	velocity.x = 0
	if not Input.is_action_pressed(input_prefix + "block"):
		state = State.IDLE

func _process_hitstun(delta: float) -> void:
	stun_timer -= delta
	velocity.x = move_toward(velocity.x, 0, move_speed * 3 * delta)
	if stun_timer <= 0:
		state = State.IDLE

func take_hit(damage: int, knockback: float, attacker_facing: int) -> void:
	if state == State.KO:
		return

	var attacker_dir: int = int(sign(attacker_facing))
	var is_blocking: bool = state == State.BLOCK and attacker_dir != facing
	var dealt: int = damage
	var stun: float = hitstun_time_heavy if damage >= kick_damage else hitstun_time_light

	if is_blocking:
		dealt = int(ceil(damage * block_chip_multiplier))
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
		fall_tween.tween_property(body_rect, "rotation", deg_to_rad(85) * facing, 0.3)
		ko.emit()
	elif not is_blocking:
		stun_timer = stun

func _flash(color: Color) -> void:
	body_rect.color = color
	var tween := create_tween()
	tween.tween_property(body_rect, "color", base_color, 0.15)

func reset_for_new_round() -> void:
	health = max_health
	state = State.IDLE
	velocity = Vector2.ZERO
	hurtbox.monitorable = true
	hitbox.set_active(false)
	body_rect.rotation = 0.0
	body_rect.color = base_color
	health_changed.emit(health, max_health)
