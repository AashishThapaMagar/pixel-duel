extends "res://scripts/player.gd"
## Combat controller in legacy pose units; CharacterBody3D owns all movement.
## Keeping combat in one implementation preserves hit confirms and frame data.
const UNITS := 64.0
var body: CharacterBody3D
var pivot: Node3D
var forward := Vector3.RIGHT
var spawn_position := Vector3.ZERO
var ai_controlled := false
var lateral_speed := 0.0
var travel := 0.0
var dash_vector := Vector3.RIGHT

func _ready() -> void:
	super._ready()
	input_prefix = "p%d_3d_" % player_id
	collision_layer = 0
	collision_mask = 0
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = 0
	hitbox.collision_layer = 0
	hitbox.collision_mask = 0
	hitbox.set_physics_process(false)
	$CollisionShape2D.disabled = true
	$Hurtbox/CollisionShape2D.disabled = true
	$Hitbox/CollisionShape2D.disabled = true

func world_input() -> Vector3:
	if ai_controlled:
		return forward * Input.get_axis(input_prefix + "left", input_prefix + "right")
	var axes := Input.get_vector(input_prefix + "left", input_prefix + "right", input_prefix + "far", input_prefix + "near")
	return Vector3(axes.x, 0.0, axes.y)

func _movement_axis() -> float:
	var projection := world_input().dot(forward)
	return signf(projection) if absf(projection) > 0.35 else 0.0

func _is_grounded() -> bool:
	return body != null and body.is_on_floor()

func _opponent_distance(other: Node) -> float:
	return body.global_position.distance_to(other.body.global_position) * UNITS

func _update_facing() -> void:
	facing = 1
	if body == null or opponent == null or opponent.body == null:
		return
	if state in [State.IDLE, State.WALK, State.BLOCK, State.LAND]:
		var offset: Vector3 = opponent.body.global_position - body.global_position
		offset.y = 0.0
		if offset.length_squared() > 0.01:
			forward = offset.normalized()

func _capture_input() -> void:
	# Commands use opponent-relative forward/back plus the dedicated guard
	# button as their down input. A/D double taps dash along the input vector.
	var before := state
	super._capture_input()
	if before != State.DASH and state == State.DASH:
		dash_vector = world_input().normalized()
		if dash_vector.length_squared() < 0.01:
			dash_vector = forward * _dash_dir

func _move_combat_body(delta: float) -> void:
	if body == null:
		return
	var input := world_input() if controls_enabled else Vector3.ZERO
	var lateral := Vector3(-forward.z, 0.0, forward.x)
	var can_move := controls_enabled and state in [State.IDLE, State.WALK, State.JUMP, State.JUMP_START]
	var speed := move_speed * (1.0 if Input.is_action_pressed(input_prefix + "run") else WALK_SPEED_RATIO)
	var lateral_target := input.dot(lateral) * speed if can_move else 0.0
	lateral_speed = move_toward(lateral_speed, lateral_target, (acceleration if can_move else braking) * delta)
	var planar := forward * velocity.x + lateral * lateral_speed
	if can_move and state in [State.IDLE, State.WALK]:
		# Both axes use one normalized vector, so diagonals never move faster.
		running = input.length_squared() > 0.01 and Input.is_action_pressed(input_prefix + "run")
		var target := input * speed
		if input.dot(forward) < -0.35 and not running:
			target *= backward_speed_ratio
		var current := Vector3(body.velocity.x, 0.0, body.velocity.z) * UNITS
		planar = current.move_toward(target, (braking if input.is_zero_approx() else acceleration) * delta)
		state = State.WALK if planar.length() > 8.0 else State.IDLE
	if state == State.DASH:
		planar = dash_vector * move_speed * (1.85 if dash_vector.dot(forward) >= 0 else 1.45)
	if state in [State.HITSTUN, State.BLOCKSTUN, State.KO]:
		lateral_speed = 0.0
		planar = forward * velocity.x
	if state == State.JUMP:
		planar = planar.limit_length(move_speed)
	body.get_node("Hurtbox3D").rotation.y = atan2(-forward.z, forward.x)
	body.velocity = planar / UNITS + Vector3.UP * -velocity.y / UNITS
	var previous := body.position
	_separate_bodies()
	body.move_and_slide()
	_separate_bodies()
	velocity.y = -body.velocity.y * UNITS
	var displacement := body.position - previous
	var signed_distance := Vector2(displacement.x, displacement.z).length() * (-1.0 if planar.dot(forward) < -0.1 else 1.0)
	travel += signed_distance * UNITS
	global_position = Vector2(travel, -body.position.y * UNITS)
	var target_angle := atan2(-forward.z, forward.x)
	pivot.rotation.y = lerp_angle(pivot.rotation.y, target_angle, 1.0 - exp(-22.0 * delta))

func _separate_bodies() -> void:
	# Grounded fighters are circular pushboxes, never platforms. They still
	# collide with the environment using the engine's 3D capsule solver.
	if opponent == null or opponent.body == null:
		return
	if absf(body.position.y - opponent.body.position.y) > 1.65:
		return
	var offset: Vector3 = body.position - opponent.body.position
	offset.y = 0
	var distance := offset.length()
	if distance >= 0.64:
		return
	var normal := offset / distance if distance > 0.001 else -forward
	var push := normal * (0.64 - distance + 0.001)
	body.move_and_collide(push * 0.5)
	opponent.body.move_and_collide(-push * 0.5)
	# Give the free fighter the remaining space when the rival is at a wall.
	var gap: Vector3 = body.position - opponent.body.position
	gap.y = 0
	if gap.length() < 0.64:
		body.move_and_collide(normal * (0.64 - gap.length()))
		gap = body.position - opponent.body.position
		gap.y = 0
		if gap.length() < 0.64:
			opponent.body.move_and_collide(-normal * (0.64 - gap.length()))

func take_hit(damage: int, knockback: float, _attacker_facing: int, attacker: Node = null, attack_type: String = "punch") -> bool:
	var guarded_from_front := true
	if attacker != null:
		var offset: Vector3 = attacker.body.position - body.position
		offset.y = 0
		guarded_from_front = forward.dot(offset.normalized()) > 0.25
	var result := super.take_hit(damage, knockback, -1 if guarded_from_front else 1, attacker, attack_type)
	if attacker != null and state in [State.HITSTUN, State.BLOCKSTUN, State.KO]:
		var away: Vector3 = body.position - attacker.body.position
		away.y = 0
		forward = -away.normalized() if away.length_squared() > 0.001 else -attacker.forward
		velocity.x = -absf(velocity.x)
	return result

func reset_for_new_round() -> void:
	if body != null:
		body.position = spawn_position
		body.velocity = Vector3.ZERO
	lateral_speed = 0.0
	travel = 0.0
	super.reset_for_new_round()
	if pivot != null:
		pivot.rotation.y = atan2(-forward.z, forward.x)
	if visual != null:
		for surface in visual.materials.values():
			surface.emission_energy_multiplier = 0.0

func _flash(color: Color) -> void:
	if visual == null or visual.materials.is_empty():
		return
	if _flash_tween != null:
		_flash_tween.kill()
	for surface in visual.materials.values():
		surface.emission_enabled = true
		surface.emission = color
		surface.emission_energy_multiplier = 0.35
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(amount: float):
		for surface in visual.materials.values():
			surface.emission_energy_multiplier = amount, 0.35, 0.0, 0.15)
