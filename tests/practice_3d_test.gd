extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func run() -> void:
	root.get_node("MatchSetup").vs_ai = true
	root.get_node("Settings").touch_controls = false
	var arena = load("res://scenes/Practice3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await frames(10)
	var p = arena.player1
	check(p.controls_enabled and not arena.player2.controls_enabled, "Practice enables player and keeps dummy passive")
	check(arena.ai_controller == null and root.get_node("MatchSetup").vs_ai, "Practice preserves match settings without spawning AI")
	p.body.position.x = -3.5
	arena.player2.body.position.x = 3.5
	Input.action_press("p1_3d_right")
	await frames(3)
	Input.action_release("p1_3d_right")
	await frames(3)
	Input.action_press("p1_3d_right")
	await frames(18)
	check(p.running and p.dash_run_held and p.state == p.State.WALK, "Held forward double-tap continues running after dash")
	check(p.body.velocity.x > p.move_speed * p.WALK_SPEED_RATIO / p.UNITS, "Run travels faster than walk")
	Input.action_release("p1_3d_right")
	await frames(15)
	check(not p.running and not p.dash_run_held and absf(p.body.velocity.x) < 0.01, "Releasing forward stops the run")
	Input.action_press("p1_3d_left")
	Input.action_press("p1_3d_run")
	await frames(15)
	check(not p.running, "Run modifier cannot sprint backward")
	Input.action_release("p1_3d_left")
	Input.action_release("p1_3d_run")
	arena._end_round(1)
	await frames(3)
	check(p.health == p.max_health and not arena.player2.controls_enabled and arena.round_active, "Knockout resets practice and retains passive dummy")
	check(arena.timer_label.text == "--" and arena.time_remaining > 9900, "Practice has no countdown")
	print("PRACTICE_3D_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
