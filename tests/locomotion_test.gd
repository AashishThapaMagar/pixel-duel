extends SceneTree
## Locomotion on the current fighter renderer (fighter_visual.gd, which the
## 3D rig extends): the gait cycle turns with the ground covered, never
## with a clock, so a blocked body stops stepping; speed shapes the stride
## into a run; standing still fades the stride out; and retreat stays a
## guarded walk facing the rival, with run held or not.
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

## One combat tick of walking: the body moves, the fighter syncs its visual
## (as the physics step does), then a rendered frame passes.
func tick(p1: Node, visual: Node, distance: float) -> void:
	p1.position.x += distance
	p1.combat_time += 1.0 / 60.0
	p1._update_animation()
	visual._process(1.0 / 60.0)

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
	for i in 7:
		p1.apply_character(i)
		p1.position.x = 300
		p2.position.x = 650
		p1.reset_for_new_round()
		var visual: Node = p1.visual
		visual.reset_pose()
		p1._update_animation()
		visual._process(1.0 / 60.0)
		check(visual.gait_weight < 0.05, "Standing has no stride")
		p1.state = p1.State.WALK
		p1.velocity.x = 169
		var seen := {}
		var previous: float = visual.gait_phase
		var reversed := false
		for step in 60:
			tick(p1, visual, 2.8)
			seen[snappedf(visual.gait_phase, 0.01)] = true
			if fposmod(visual.gait_phase - previous, 1.0) > 0.2:
				reversed = true
			previous = visual.gait_phase
		check(seen.size() > 8, "Walking advances the gait cycle continuously (%s)" % p1.character_profile.id)
		check(not reversed, "The gait cycle never reverses mid-step (%s)" % p1.character_profile.id)
		check(visual.gait_weight > 0.5, "A moving body strides")
		var held: float = visual.gait_phase
		for step in 12:
			tick(p1, visual, 0.0)
		check(is_equal_approx(visual.gait_phase, held), "A blocked body cannot keep cycling its feet")
		var extra: float = visual.gait_phase
		visual._process(1.0 / 144.0)
		visual._process(1.0 / 144.0)
		check(is_equal_approx(visual.gait_phase, extra), "Extra rendered frames cannot advance the combat gait")
		var walk_mix: float = visual._run_mix
		p1.running = true
		for step in 40:
			tick(p1, visual, 4.6)
		check(visual._run_mix > walk_mix + 0.3 and visual._run_mix > 0.5, "Held run engages the faster, longer stride (%s)" % p1.character_profile.id)
		p1.running = false
		p1.state = p1.State.IDLE
		for step in 40:
			tick(p1, visual, 0.0)
		check(visual.gait_weight < 0.05, "Stopping fades the stride out")
	# Real retreat input: stay facing the rival, never run backwards.
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
