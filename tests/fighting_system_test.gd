extends SceneTree
const MOTION := preload("res://scripts/motion_input.gd")
var arena: Node
var p1: Node
var p2: Node
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func reset() -> void:
	for prefix in ["p1_", "p2_"]:
		for action in ["left", "right", "block", "punch", "kick"]:
			Input.action_release(prefix + action)
	arena._begin_round(0)
	arena.intro_timer = 0.0
	arena._hide_banner()
	p1.position = Vector2(400, 450)
	p2.position = Vector2(458, 450)
	await frames(3)
	p1.set_physics_process(false)
	p2.set_physics_process(false)

func roll(direction: String) -> void:
	Input.action_press("p1_block")
	await frames(1)
	Input.action_press("p1_" + direction)
	await frames(1)
	Input.action_release("p1_block")
	await frames(1)
	Input.action_press("p1_kick")
	await frames(1)
	Input.action_release("p1_kick")
	Input.action_release("p1_" + direction)

func _run() -> void:
	var motion := MOTION.new()
	motion.record(2, 0.0)
	motion.record(3, 0.1)
	motion.record(6, 0.2)
	check(motion.consume(0.25) == "drive", "Quarter-circle forward is recognized")
	check(motion.consume(0.26).is_empty(), "One motion cannot trigger twice")
	motion.reset()
	motion.record(2, 0.0)
	motion.record(1, 0.1)
	motion.record(4, 0.2)
	check(motion.consume(0.7).is_empty(), "Old motions expire")
	motion.reset()
	motion.record(2, 0.0)
	motion.record(6, 0.1)
	check(motion.consume(0.2).is_empty(), "Skipping the diagonal is not a quarter-circle")
	arena = load("res://scenes/Arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_process(false)
	p1 = arena.player1
	p2 = arena.player2
	p1.apply_character(1)
	p2.apply_character(5)
	await reset()
	p2.position.x = 800
	p1.set_physics_process(true)
	await roll("right")
	check(p1.current_move.name == p1.available_moves().drive.name, "Real right-facing motion starts the command move")
	await reset()
	p1.position.x = 600
	p2.position.x = 200
	p1.facing = -1
	p1.set_physics_process(true)
	await roll("left")
	check(p1.current_move.name == p1.available_moves().drive.name, "Motion mirrors when facing left")
	await reset()
	p2.position.x = 800
	p1.set_physics_process(true)
	await roll("left")
	check(p1.current_move.name == p1.available_moves().breaker.name, "Quarter-circle back starts the other ender")
	# Real input, collisions and held guard expose any gap in the command combo.
	await reset()
	p1.set_physics_process(true)
	p2.set_physics_process(true)
	Input.action_press("p1_punch")
	await frames(1)
	Input.action_release("p1_punch")
	for i in 30:
		if p1.combo_hits == 1:
			break
		await frames(1)
	Input.action_press("p2_block")
	Input.action_press("p1_punch")
	await frames(1)
	Input.action_release("p1_punch")
	for i in 30:
		if p1.combo_hits == 2:
			break
		await frames(1)
	await roll("right")
	for i in 40:
		if p1.combo_hits == 3:
			break
		await frames(1)
	check(p1.combo_hits == 3 and p1.current_move.name == p1.available_moves().drive.name, "Real inputs produce a gapless three-hit command combo")
	check(p1.combo_damage == 100 - p2.health, "Command combo display matches actual scaled damage")
	# A held light button must not produce automatic follow-ups.
	await reset()
	p1.set_physics_process(true)
	p2.set_physics_process(true)
	Input.action_press("p1_punch")
	await frames(40)
	check(p1.combo_hits == 1 and p1.state == p1.State.IDLE, "Holding light does not auto-combo")
	# A late press cannot cancel the remaining recovery.
	await reset()
	p1._start_style_move("cross")
	p1.attack_connected = true
	p1.attack_timer = p1.attack_startup() + p1.attack_active_time() + 0.11
	p1._buffered_action = "kick"
	p1._buffer_remaining = 0.13
	p1._process_attack(0.001)
	check(p1.current_move.name == p1.available_moves().cross.name, "Cancel window closes before recovery ends")
	# A confirmed jab can cancel into a buffered motion ender, but a whiff cannot.
	await reset()
	p1._start_style_move("jab")
	p1.attack_timer = p1.attack_startup() + p1.attack_active_time()
	p1._buffered_action = "kick"
	p1._buffered_move = "drive"
	p1._buffer_remaining = 0.13
	p1._process_attack(0.001)
	check(p1.current_move.name != p1.available_moves().drive.name, "Whiff cannot special-cancel")
	p1.attack_connected = true
	p1._process_attack(0.001)
	check(p1.current_move.name == p1.available_moves().drive.name, "Hit confirm permits motion ender")
	# Counter hit and recovery punish are distinct and give accurate feedback.
	await reset()
	p1._start_style_move("jab")
	p2._start_style_move("breaker")
	p2.take_hit(10, 0, 1, p1)
	check(p2.health == 88 and p1.combat_notice == "COUNTER HIT", "Startup counter adds 20 percent damage")
	check(is_equal_approx(p2.stun_timer, p1.current_move.hitstun + 0.1), "Counter adds six stun frames")
	await reset()
	p1._start_style_move("jab")
	p2._start_style_move("breaker")
	p2.attack_timer = p2.attack_startup() + p2.attack_active_time()
	p2.take_hit(10, 0, 1, p1)
	check(p2.health == 90 and p1.combat_notice == "PUNISH", "Recovery punish is labeled without counter bonus")
	p2.take_hit(10, 0, 1, p1)
	check(p2.health == 81, "Uninterrupted second hit scales to 85 percent, rounded")
	p2.state = p2.State.IDLE
	p2.stun_timer = 0.0
	p2.take_hit(10, 0, 1, p1)
	check(p2.health == 71, "Escaping hitstun resets scaling")
	await reset()
	p1._start_style_move("breaker")
	p2.state = p2.State.BLOCK
	p2.block_hold_time = 1.0
	p2.take_hit(10, 0, 1, p1, "kick")
	check(is_equal_approx(p2.stun_timer, p1.current_move.blockstun), "Blockstun comes from move data")
	check(p2.stun_timer < p1.current_move.recovery, "Blocked command ender leaves punishable recovery")
	p1.motion_input.record(2, 0.0)
	p1._buffered_move = "drive"
	p1.reset_for_new_round()
	check(p1.motion_input.history.is_empty() and p1._buffered_move.is_empty(), "Round reset clears commands")
	print("FIGHTING_SYSTEM_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
