extends SceneTree
## Run with: godot --headless --path . -s res://tests/combat_test.gd
var arena: Node
var p1: Node
var p2: Node
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _reset(style_index: int = 0) -> void:
	for action in ["p1_left", "p1_right", "p1_punch", "p1_kick", "p1_jump", "p1_block", "p2_block"]:
		Input.action_release(action)
	arena._begin_round(style_index)
	arena.intro_timer = 0.0
	arena._hide_banner()
	p1.position = Vector2(400, 450)
	p2.position = Vector2(475, 450)
	p1.facing = 1
	p2.facing = -1
	await _frames(3)
	p1.set_physics_process(false)
	p2.set_physics_process(false)

func _run() -> void:
	arena = load("res://scenes/Arena.tscn").instantiate()
	root.add_child(arena)
	p1 = arena.get_node("Player1")
	p2 = arena.get_node("Player2")
	arena.set_process(false)
	await _reset()

	p2.take_hit(10, 220, 1, p1)
	_check(p2.velocity.x > 0.0, "Right-facing hit must push defender right, away from attacker")
	_check(p1.hitstop_remaining > 0.0 and p2.hitstop_remaining > 0.0, "Impact must freeze both fighters")
	p1.take_hit(10, 220, -1)
	_check(p1.velocity.x < 0.0, "Left-facing hit must push defender left")

	# Real overlap: startup is safe, one attack hits exactly once, next attack can hit again.
	await _reset()
	p1._start_attack(p1.State.PUNCH)
	p1._process_attack(0.016)
	await _frames(3)
	_check(p2.health == 100, "Windup must not deal damage")
	p1._process_attack(p1.punch_startup_time)
	await _frames(3)
	_check(p2.health == 100 - p1.punch_damage, "Active attack must hit an already overlapping hurtbox")
	var after_first: int = p2.health
	p1.hitstop_remaining = 0.0
	p2.hitstop_remaining = 0.0
	p1.hitbox.set_active(true)
	await _frames(4)
	_check(p2.health == after_first, "Repeated active ticks must not deal duplicate damage")
	p1._process_attack(p1.attack_duration())
	_check(not p1.hitbox.active, "Recovery must disable the hitbox")
	p1._start_attack(p1.State.PUNCH)
	p1._process_attack(p1.punch_startup_time)
	await _frames(3)
	_check(p2.health == after_first - p1.punch_damage, "A new swing must be able to hit the same opponent")

	# An interrupted swing and a parried swing lose their hitboxes immediately.
	await _reset()
	p1._start_attack(p1.State.PUNCH)
	p1._process_attack(p1.punch_startup_time)
	p1.take_hit(10, 200, -1)
	_check(not p1.hitbox.active and p1.state == p1.State.HITSTUN, "Hitstun must interrupt outgoing damage")
	await _reset()
	p2.state = p2.State.BLOCK
	p2.block_hold_time = 0.0
	p1._start_attack(p1.State.PUNCH)
	p1._process_attack(p1.punch_startup_time)
	p1.hitbox._on_area_entered(p2.hurtbox)
	_check(p2.health == 100, "Karate perfect block must prevent all damage")
	_check(p1.state == p1.State.HITSTUN and not p1.hitbox.active, "Parry must interrupt the attacker")
	_check(not p1.attack_connected, "Parry must not grant hit confirmation")
	await _reset()
	p2.state = p2.State.BLOCK
	p2.block_hold_time = 1.0
	p2.take_hit(10, 200, 1, p1)
	Input.action_press("p2_block")
	p2._process_hitstun(0.2)
	_check(p2.state == p2.State.BLOCK and p2.block_hold_time > 1.0, "Held guard must not re-arm the parry window after blockstun")
	Input.action_release("p2_block")

	await _reset(1)
	p2.state = p2.State.BLOCK
	p2.block_hold_time = 1.0
	var landed: bool = p2.take_hit(p1.kick_damage, 300, 1, p1, "kick")
	var chip: int = int(ceil(p1.kick_damage * (p2.block_chip_multiplier + p1.current_style.kick_chip_bonus)))
	_check(p2.health == 100 - chip, "Muay Thai kicks must retain enhanced chip")
	_check(not landed and p2.state == p2.State.BLOCKSTUN, "Guard must produce blockstun, not a hit confirm")
	p2._process_hitstun(0.016)
	_check(p2.state == p2.State.BLOCKSTUN and p2.velocity.x > 0.0, "Releasing guard must not cancel blockstun or its pushback")

	# Real input during the final recovery frames should start a new attack.
	await _reset(2)
	p2.position.x = 800
	p1._start_attack(p1.State.PUNCH)
	p1.attack_timer = p1.attack_duration() - 0.025
	p1.set_physics_process(true)
	Input.action_press("p1_kick")
	await _frames(1)
	Input.action_release("p1_kick")
	await _frames(3)
	_check(p1.state == p1.State.PUNCH and p1.attack_variant == "rear_hook", "Buffered heavy must become a Boxing rear hook after recovery")
	await _reset(2)
	p1._on_hit_landed("punch")
	p1._start_attack(p1.State.PUNCH, "hook")
	p1._process_attack(0.001)
	_check(p1.hitbox.damage == p1.hook_damage + p1.current_style.combo_damage_step, "Boxing's second connected strike must receive the combo bonus")
	p1.combat_time += p1.current_style.combo_window + 0.01
	p1._process_attack(0.001)
	_check(p1.hitbox.damage == p1.hook_damage, "Expired combos must not retain a damage bonus")

	await _reset(3)
	p1._on_hit_landed("punch")
	p1._start_attack(p1.State.KICK, "kick")
	_check(p1.attack_variant == "finisher", "MMA punch into kick must retain its finisher")
	p1._start_attack(p1.State.KICK, "kick")
	_check(p1.attack_variant == "kick", "MMA finisher must respect its cooldown")

	await _reset()
	p1._start_attack(p1.State.PUNCH)
	p1._on_hit_landed("punch")
	p1.attack_timer = p1.attack_startup() + p1.attack_active_time()
	p1._buffered_action = "kick"
	p1._buffer_remaining = 0.13
	p1._process_attack(0.001)
	_check(p1.state == p1.State.KICK, "Confirmed jab must allow heavy cancel after contact")
	p1._start_attack(p1.State.PUNCH)
	p1.attack_timer = p1.attack_startup() + p1.attack_active_time()
	p1._buffered_action = "kick"
	p1._process_attack(0.001)
	_check(p1.state == p1.State.PUNCH, "Whiffed jab must not grant an early cancel")
	# Crossovers must not reverse a committed strike; idle then corrects facing.
	p2.position.x = 300
	p1._update_facing()
	_check(p1.facing == 1, "Attack facing must remain committed")
	p1.state = p1.State.IDLE
	p1._update_facing()
	_check(p1.facing == -1, "Neutral stance must turn toward the opponent")
	p1._update_animation()
	_check(p1.visual.scale.x == -1.0, "Visual must mirror around fighter origin")

	await _reset()
	p2.position.x = 800
	p1.set_physics_process(true)
	Input.action_press("p1_right")
	await _frames(1)
	Input.action_release("p1_right")
	await _frames(2)
	Input.action_press("p1_right")
	await _frames(2)
	_check(p1.state == p1.State.DASH and p1.velocity.x > p1.move_speed, "Double tap must dash")
	Input.action_release("p1_right")
	await _frames(15)
	Input.action_press("p1_jump")
	await _frames(1)
	Input.action_release("p1_jump")
	_check(p1.state == p1.State.JUMP_START, "Jump must begin with anticipation")
	await _frames(5)
	_check(p1.state == p1.State.JUMP and p1.velocity.y < 0.0, "Jump must launch after anticipation")
	await _frames(55)
	_check(p1.is_on_floor() and p1.state == p1.State.IDLE, "Jump must land and recover")
	p1.position.x = 924
	Input.action_press("p1_right")
	await _frames(15)
	_check(p1.position.x <= 926.0, "Fighters must stay inside the stage")
	Input.action_release("p1_right")

	await _reset()
	p2.take_hit(200, 300, 1, p1, "kick")
	_check(not arena.round_active and arena.round_wins[0] == 1, "KO must end the active round and award a win")
	_check(not p1.controls_enabled and not p2.controls_enabled, "Round end must lock both fighters' controls")
	var ended_health: int = p1.health
	p1.take_hit(20, 100, -1)
	_check(p1.health == ended_health, "Round end must prevent further damage")
	arena._begin_round(1)
	_check(p1.health == 100 and p2.health == 100, "Restart must restore health")
	_check(p1.hitstop_remaining == 0.0 and p1._buffered_action.is_empty(), "Restart must clear freeze and buffered input")
	_check(p1.controls_enabled and not p1.hitbox.active, "Restart must restore controls without a stale attack")
	if failures.is_empty():
		print("COMBAT_TEST: ALL PASS")
	else:
		print("COMBAT_TEST: %d FAILURES" % failures.size())
	quit(0 if failures.is_empty() else 1)
