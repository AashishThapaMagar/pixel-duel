extends SceneTree
const MOVES := preload("res://scripts/move_catalog.gd")
const ROSTER := preload("res://scripts/fighter_roster.gd")
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

func _reset(style_index: int) -> void:
	for action in ["p1_punch", "p1_kick", "p1_left", "p1_right", "p2_block"]:
		Input.action_release(action)
	arena._begin_round(style_index)
	arena.intro_timer = 0.0
	arena._hide_banner()
	p1.position = Vector2(400, 450)
	p2.position = Vector2(458, 450)
	p1.facing = 1
	p2.facing = -1
	await _frames(3)

func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(1)
	Input.action_release(action)

func _wait_for_hits(count: int) -> void:
	for i in 35:
		if p1.combo_hits >= count:
			return
		await _frames(1)
	_check(false, "Combo did not reach %d hits in %s (got %d, move %s)" % [count, p1.current_style.style_id, p1.combo_hits, p1.move_name()])

func _run() -> void:
	arena = load("res://scenes/Arena.tscn").instantiate()
	root.add_child(arena)
	# Archived style resources remain covered independently of the action roster.
	arena.round_styles = [load("res://resources/styles/karate.tres"), load("res://resources/styles/muay_thai.tres"), load("res://resources/styles/boxing.tres"), load("res://resources/styles/mma.tres")]
	arena.set_process(false)
	p1 = arena.get_node("Player1")
	p2 = arena.get_node("Player2")
	# Every listed technique must be reachable and actually damage an opponent.
	for style_index in 4:
		var style_id: String = arena.round_styles[style_index].style_id
		var moves := MOVES.for_style(style_id)
		_check(moves.size() == 8, "Each style must expose six normals and two command enders")
		for move_id in moves:
			await _reset(style_index)
			p1.set_physics_process(false)
			p2.set_physics_process(false)
			p1._start_style_move(move_id)
			p1._process_attack(p1.attack_startup())
			await _frames(4)
			_check(p2.health < 100, "%s / %s must connect at close range" % [style_id, move_id])
			_check(p1.current_move.name == moves[move_id].name, "Move label must match the catalog")
			if style_id == "boxing":
				_check(p1.state == p1.State.PUNCH and p1.hitbox.attack_type == "punch", "Boxing must never use a leg attack")
		# Actual buffered button presses, real pushback, and an active defender.
		await _reset(style_index)
		await _tap("p1_punch")
		await _wait_for_hits(1)
		await _tap("p1_punch")
		await _wait_for_hits(2)
		await _tap("p1_punch")
		await _wait_for_hits(3)
		_check(p1.chain_step == 2, "Three punches should reach the final chain step")
		_check(p1.combo_damage == 100 - p2.health, "Combo damage must match real health loss")
		await _reset(style_index)
		await _tap("p1_punch")
		await _wait_for_hits(1)
		await _tap("p1_punch")
		await _wait_for_hits(2)
		await _tap("p1_kick")
		await _wait_for_hits(3)
		_check(p1.current_move.name == moves[moves.cross.next_heavy].name, "Mixed chain must select the style's ender")

	# Direction is captured on the press, including when the opponent is left.
	await _reset(2)
	p1.position.x = 470
	p2.position.x = 400
	await _frames(2)
	Input.action_press("p1_left")
	await _tap("p1_punch")
	Input.action_release("p1_left")
	_check(p1.attack_variant == "cross", "Forward light must mirror for a left-facing fighter")
	await _reset(2)
	Input.action_press("p2_block")
	await _frames(2)
	await _tap("p1_punch")
	await _frames(9)
	_check(not p1.attack_connected and p1.combo_hits == 0, "Guarded punches must not start a combo")
	await _tap("p1_punch")
	await _frames(3)
	_check(p1.attack_variant == "jab", "Guard must deny the early cross cancel")
	Input.action_release("p2_block")

	# Opening the move guide must pause live attack collisions and the timer.
	await _reset(0)
	p1._start_style_move("jab")
	p1._process_attack(p1.attack_startup())
	var health_before: int = p2.health
	var time_before: float = arena.time_remaining
	arena._toggle_move_guide()
	await _frames(5)
	_check(p2.health == health_before and arena.time_remaining == time_before, "Move guide must pause combat")
	arena._toggle_move_guide()
	_check(p1.is_physics_processing() and not p1.combat_paused, "Closing the guide must restore combat")

	# Reapplying a round cannot accumulate character bonuses.
	for i in 4:
		p1.apply_character(i)
		p1.apply_style(arena.round_styles[0])
		var speed: float = p1.move_speed
		var damage: int = p1.punch_damage
		p1.apply_style(arena.round_styles[0])
		_check(p1.move_speed == speed and p1.punch_damage == damage, "Character bonuses must not stack")
		_check(p1.character_profile.id == ROSTER.profile(i).id, "All four profiles must apply")

	# Exercise the character-select flow through the real scene transition.
	arena.queue_free()
	await _frames(2)
	var select = load("res://scenes/CharacterSelect.tscn").instantiate()
	root.add_child(select)
	current_scene = select
	select._select_for_player(2, 0)
	select._select_for_player(3, 1)
	select._toggle_ready(0)
	_check(select.start_button.disabled, "Both players must ready before the match")
	select._toggle_ready(1)
	_check(not select.start_button.disabled, "Both ready must enable start")
	select._start_match()
	# Selection fades out before changing scenes. Bound the wait so a broken
	# transition reports a failure instead of accessing missing fighter nodes.
	for i in 60:
		await _frames(1)
		if is_instance_valid(current_scene) and current_scene.has_node("Player1"):
			break
	if not is_instance_valid(current_scene) or not current_scene.has_node("Player1"):
		_check(false, "Starting a ready match must reach the arena")
		quit(1)
		return
	_check(current_scene.get_node("Player1").character_profile.id == "sab", "P1 character must reach the match")
	_check(current_scene.get_node("Player2").character_profile.id == "bib", "P2 character must reach the match")
	print("STYLE_COMBO_TEST: ALL PASS" if failures.is_empty() else "STYLE_COMBO_TEST: %d FAILURES" % failures.size())
	quit(0 if failures.is_empty() else 1)
