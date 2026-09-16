extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	var setup: Node = root.get_node("MatchSetup")
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for mode in ["story", "arcade", "ai", "local"]:
		menu.home_modes[mode].pressed.emit()
		check(setup.story == (mode == "story"), "Home cards select the correct story state")
		check(setup.vs_ai == (mode != "local"), "Home cards select correct opponent control")
	menu._show_fight_options()
	var pickers: Array[Node] = menu.modal_content.find_children("*", "OptionButton", true, false)
	pickers[0].item_selected.emit(2)
	pickers[1].item_selected.emit(0)
	check(setup.ai_difficulty == 2 and setup.round_seconds == 60, "Options controls store selected rules")
	menu._close_modal()
	menu._start_fight()
	await create_timer(0.4).timeout
	var arena: Node = current_scene
	check(arena.time_remaining == 60 and arena.timer_label.text == "60", "Selected timer reaches the actual match")
	arena.set_process(false)
	arena.intro_timer = 0.0
	arena._hide_banner()
	arena.player2.set_physics_process(false)
	var fighter: Node = arena.player1
	var visual: Node = fighter.visual
	fighter.set_physics_process(false)
	visual.set_process(false)
	# Alternating legs, planted feet and retreat are covered by locomotion_test.gd.
	# Exercise held inputs and physics, not just visual flags.
	fighter.reset_for_new_round()
	fighter.position = Vector2(200, 450)
	arena.player2.position = Vector2(850, 450)
	fighter.set_physics_process(true)
	for i in 5:
		await physics_frame
		await process_frame
	Input.action_press("p1_right")
	for i in 10:
		await physics_frame
		await process_frame
	var walk_speed: float = absf(fighter.velocity.x)
	check(not fighter.running and walk_speed > 50, "Movement alone walks")
	Input.action_press("p1_run")
	for i in 10:
		await physics_frame
		await process_frame
	check(fighter.running and absf(fighter.velocity.x) > walk_speed * 1.4, "Held run input produces a genuinely faster run")
	Input.action_release("p1_run")
	Input.action_release("p1_right")
	for i in 5:
		await physics_frame
		await process_frame
	check(not fighter.running and fighter.state == fighter.State.IDLE, "Release returns to idle cleanly")
	setup.camera_shake = false
	arena.combat_effects.add_impact(Vector2(400, 360), false, true)
	arena.combat_effects._process(0.01)
	check(arena.get_node("Camera2D").offset == Vector2.ZERO, "Shake toggle disables impact camera motion")
	setup.camera_shake = true
	setup.round_seconds = 99
	setup.ai_difficulty = 1
	print("MENU_WALK_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
