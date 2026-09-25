extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func run() -> void:
	root.get_node("Settings").touch_controls = true
	root.get_node("MatchSetup").vs_ai = false
	var arena: Node = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var touch: Control
	for child in arena.get_children():
		if child.get_script() == load("res://scripts/touch_controls_3d.gd"):
			touch = child
	check(touch != null, "Touch input remains available when enabled")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	touch._input(tap)
	check(touch.using_touch, "Touch activates on-screen controls")
	Input.action_press("p1_3d_punch")
	var keyboard := InputEventKey.new()
	keyboard.pressed = true
	keyboard.physical_keycode = KEY_A
	touch._input(keyboard)
	check(not touch.using_touch and not Input.is_action_pressed("p1_3d_punch"), "Keyboard hides touch controls and releases held actions")
	var nights := 0
	for index in 4:
		arena._begin_round(index)
		arena.intro_timer = 0
		arena._hide_banner()
		arena.player1.body.position = Vector3(-1.0, 0.02, 0)
		arena.player2.body.position = Vector3(1.0, 0.02, 0)
		await frames(45)
		var stage: Node = arena.nepal_stage
		if stage.night:
			nights += 1
		check(stage.current_round == index, "Round transition switches the 3D scenery")
		check(stage.find_children("HeritageScenery", "Node3D", false, false).size() == 1, "Only the active scenery stays in the world")
		check(arena.player1._is_grounded(), "Scenery change keeps the solid arena floor")
		check(stage.sky_material.get_shader_parameter("top_color") != null and stage.floor_material.get_shader_parameter("pattern") == 5, "Each arena has its own sky and a modelled flagstone floor")
		check(stage.content.get_child_count() > 100, "Each round builds a modelled 3D arena")
		if index == 3:
			check(stage.night and stage.ROUNDS[index].name == "MOONLIT STUPA", "Final round is the moonlit stupa arena")
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/nepal-round-%d.png" % (index + 1))
	check(nights == 2, "Exactly two day rounds and two night rounds")
	arena._toggle_move_guide()
	var clock_before: float = arena.nepal_stage.elapsed
	await frames(5)
	check(is_equal_approx(clock_before, arena.nepal_stage.elapsed), "Move guide pauses the stage clock")
	arena._toggle_move_guide()
	arena._begin_round(0)
	check(not arena.nepal_stage.night, "Rematch returns to the daytime opening")
	# A versus arena choice holds every round in that arena.
	var setup: Node = root.get_node("MatchSetup")
	setup.stage_choice = 2
	arena.fixed_stage = arena._resolve_stage()
	for index in [0, 3]:
		arena._begin_round(index)
		check(arena.nepal_stage.current_round == 2, "Chosen versus arena is used for every round")
	setup.arcade = true
	check(arena._resolve_stage() == -1, "Arcade always plays the four-arena journey")
	setup.arcade = false
	setup.stage_choice = setup.JOURNEY_STAGE
	var select: Node = load("res://scenes/CharacterSelect.tscn").instantiate()
	root.add_child(select)
	await frames(2)
	check(select.arena_label != null and select.arena_label.text == "ALL 4 ARENAS", "Versus fighter select offers the arena picker, defaulting to the journey")
	select._cycle_stage(-1)
	check(setup.stage_choice == setup.RANDOM_STAGE and select.arena_label.text == "RANDOM ARENA", "Arena picker wraps to random")
	select._cycle_stage(-1)
	check(setup.stage_choice == 3 and select.backdrop.stage.current_round == 3, "Picking an arena shows it live behind the roster")
	setup.stage_choice = setup.JOURNEY_STAGE
	print("NEPAL_JOURNEY_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
