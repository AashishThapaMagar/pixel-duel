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
		# Pin both fighters back to their starting spots before each character's
		# pass: earlier passes drift p1.position.x, and reset_for_new_round()'s
		# _update_facing() would otherwise flip facing once drift crosses p2.
		p1.position.x = 300
		p2.position.x = 650
		p1.reset_for_new_round()
		var visual: Node = p1.visual
		check(visual.get_child_count() == 2, "A fighter renders one standing sprite plus the leg-deformation gait mesh")
		check(visual.sprite.visible and not visual.gait.visible, "Standing shows the authored sprite, not the gait mesh")
		p1.state = p1.State.WALK
		p1.velocity.x = 169
		p1.position.x += 2
		p1.combat_time += 1.0 / 60.0
		p1._update_animation()
		check(visual.gait.visible and not visual.sprite.visible, "Walking swaps to the deformed-leg mesh, hiding the authored sprite")
		check(visual.walk_phase == 0.0, "The first movement update enters on contact, not mid-step")
		var seen_phases := {}
		for tick in 90:
			p1.position.x += 2
			p1.combat_time += 1.0 / 60.0
			p1._update_animation()
			seen_phases[snappedf(visual.walk_phase, 0.01)] = true
			var before: float = visual.walk_phase
			visual._process(1.0 / 144.0)
			p1._update_animation()
			check(visual.walk_phase == before, "Extra rendering or sync calls cannot advance the combat animation clock")
		check(seen_phases.size() > 8, "Movement advances the gait phase continuously, not in a handful of steps")
		var phase_before_duplicate: float = visual.walk_phase
		p1.position.x += 2
		p1._update_animation()
		check(visual.walk_phase == phase_before_duplicate, "Same-clock movement waits for the authoritative sample")
		p1.combat_time += 1.0 / 60.0
		p1._update_animation()
		check(visual.walk_phase != phase_before_duplicate, "A duplicate sync cannot discard unsampled displacement")
		var held_phase: float = visual.walk_phase
		p1.combat_time += 0.1
		p1._update_animation()
		check(visual.walk_phase == held_phase, "A blocked body cannot keep cycling its feet")
		p1.state = p1.State.IDLE
		p1._update_animation()
		check(visual.sprite.visible and not visual.gait.visible, "Stopping returns to the standing sprite without waiting for a fade")
		p1.state = p1.State.WALK
		p1.velocity.x = -122
		p1.position.x -= 15
		p1.combat_time += 1.0 / 60.0
		p1._update_animation()
		check(visual.walk_phase == 0.0, "Retreat starts on contact without consuming earlier displacement")
		p1.state = p1.State.WALK
		p1.running = true
		p1.position.x += 4
		p1.combat_time += 1.0 / 60.0
		p1._update_animation()
		check(visual.locomotion_running, "Held run engages the faster gait")
		# A full stride's worth of travel must bring the phase back to (near) 0,
		# in both walk and run, without ever reversing mid-step.
		for running in [false, true]:
			p1.state = p1.State.IDLE
			p1._update_animation()
			p1.state = p1.State.WALK
			p1.running = running
			p1.velocity.x = 260 if running else 169
			p1._update_animation()
			var stride: float = visual.gait.cycle_length(running)
			var previous_phase: float = visual.walk_phase
			for step in 40:
				p1.position.x += stride / 40.0 + 0.05
				p1.combat_time += 1.0 / 60.0
				p1._update_animation()
				var advanced := fposmod(visual.walk_phase - previous_phase, 1.0)
				check(advanced < 0.2, "Chronological, non-reversing gait phase %s run=%s step=%d phase=%f" % [visual.loaded_id, running, step, visual.walk_phase])
				previous_phase = visual.walk_phase
		var phase_before_switch: float = visual.walk_phase
		p1.running = false
		p1._update_animation()
		check(visual.walk_phase == phase_before_switch, "Changing run to walk preserves the supporting leg phase")
		check(not visual.sprite.is_playing(), "Render-time autoplay cannot advance the standing sprite")
	# Real retreat input: stay facing rival, don't run backwards even with run held.
	p1.position.x = 300
	p2.position.x = 650
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
