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
	var setup: Node = root.get_node("MatchSetup")
	setup.vs_ai = false
	setup.story = false
	setup.arcade = false
	var arena: Node = load("res://scenes/Arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.intro_timer = 0
	arena._hide_banner()
	arena.set_process(false)
	await frames(5)
	var p1: Node = arena.player1
	var p2: Node = arena.player2
	p1.set_physics_process(false)
	p2.set_physics_process(false)
	p1.visual.set_process(false)
	p2.visual.set_process(false)
	p1.position.x = 300
	p2.position.x = 650
	for i in 7:
		p1.apply_character(i)
		var gait: Node = p1.visual.gait
		check(gait.meshes.size() == 3, "Character changes replace the rig without leaving old body parts")
		for mesh in gait.meshes:
			check(mesh.texture == p1.visual.sheet, "Every moving body part uses the same fighter's illustrated artwork")
		var stride: float = gait.cycle_length(false)
		gait.sample(0.1, false, stride)
		var planted: Vector2 = gait.feet[0]
		var shoulder_before: Vector2 = gait.meshes[2].polygon[0]
		gait.sample(0.1 + 1.0 / stride, false, stride)
		check(absf(gait.feet[0].x + 1 - planted.x) < 0.01 and gait.feet[0].y == planted.y, "Support foot remains planted as the body moves")
		check(gait.meshes[2].polygon[0].distance_to(shoulder_before) > 0.001, "Shoulders shift with each step while the support foot stays planted")
		gait.sample(0.3, false, stride)
		check(gait.feet[1].y < gait.ankles[1].y and gait.feet[0].y == gait.ankles[0].y, "Front foot recovers while rear foot supports the body")
		gait.sample(0.8, false, stride)
		check(gait.feet[0].y < gait.ankles[0].y and gait.feet[1].y == gait.ankles[1].y, "Rear foot recovers while front foot supports the body")
		for phase in [0.0, 0.25, 0.5, 0.75]:
			p1.state = p1.State.WALK
			p1.visual.walk_phase = phase
			p1._update_animation()
			gait.sample(phase, false, stride)
			check(p1.visual.gait.visible and not p1.visual.sprite.visible, "Walking uses articulated legs rather than a standing sprite")
			check(gait.feet[0].x < gait.feet[1].x, "Walking retains combat stance instead of crossing the legs")
			var seam := Vector2(gait.split_x, lerpf(gait.waist,gait.crotch,0.7))
			check(gait.deform(seam,0).distance_to(gait.deform(seam,1)) < 0.01, "Pelvis seam stays closed through the stride")
			for side in 2:
				var shoe: Vector2 = gait.ankles[side] + Vector2(0,5)
				var expected_shoe: Vector2 = gait.feet[side] + Vector2(0,5).rotated(gait.foot_angles[side])
				check(gait.deform(shoe,side).distance_to(expected_shoe) < 0.01, "Illustrated shoe follows the foot through its recovery roll")
			if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless" and i in [0, 2]:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/legs-%d-%d.png" % [i, roundi(phase * 4)])
	# Real retreat input: stay facing rival, don't run backwards even with run held.
	p1.apply_character(0)
	p1.reset_for_new_round()
	p1.facing = 1
	p1.set_physics_process(true)
	Input.action_press("p1_left")
	Input.action_press("p1_run")
	await frames(10)
	check(p1.velocity.x < 0 and p1.facing == 1 and p1.visual.scale.x == 1, "Retreat never turns the fighter's back to the rival")
	check(not p1.running, "Run modifier does not turn retreat into a backwards sprint")
	p1.take_hit(10, 0, -1, p2)
	check(p1.state == p1.State.BLOCKSTUN and p1.health > 90, "Holding back guards incoming strikes")
	Input.action_release("p1_left")
	Input.action_release("p1_run")
	p1.reset_for_new_round()
	p1.position.x = 300
	Input.action_press("p1_right")
	Input.action_press("p1_run")
	await frames(10)
	check(p1.running and p1.velocity.x > 200, "Forward held-run remains available")
	Input.action_release("p1_right")
	Input.action_release("p1_run")
	print("LOCOMOTION_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
