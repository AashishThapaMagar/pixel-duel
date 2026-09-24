extends SceneTree
## Measures the walk itself, not just that movement happens: a planted sole has
## to hold its ground while the body travels over it, the knee must never hit
## the rig's fixed leg length, and the cycle has to ramp in and out of the
## guard stance instead of snapping on at the WALK threshold.
var failures: Array[String] = []
var arena: Node
var p1: Node
var p2: Node

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

# World position of one ankle along the travel axis: the travel the visible
# pose was built from, plus that ankle's offset inside the pose.
func sole(travelled: float, side: int) -> float:
	return travelled + p1.visual.pose[5 + side].x

# How far the ankle sits from the hip it hangs off. fighter_visual clamps this
# to 59.9 when it draws, so anything at that limit is a leg dragged straight
# and skating instead of stepping.
func leg_span(fighter: Node, side: int) -> float:
	var pose: Array = fighter.visual.pose
	var root: Vector2 = pose[0] + Vector2(-6 if side == 0 else 6, 0)
	return root.distance_to(pose[5 + side])

# Clear the strip so a measured walk is never cut short by the rival's pushbox
# or the edge of the lane.
func runway(start: float, rival: float) -> void:
	p1.body.position = Vector3(start, 0.02, 0)
	p2.body.position = Vector3(rival, 0.02, 0)
	await frames(2)

# Samples one rendered frame at a time: how far the planted sole slips against
# the ground the body covered, how straight the legs get, and how much ground
# one whole cycle spans. Only full-stride frames count, so a fighter still
# ramping up to speed cannot flatter the numbers.
#
# SceneTree.process_frame is emitted before the nodes run their own _process,
# so the pose readable here was built from the position the fighter held on the
# previous pass. Pairing each pose with that position is what makes a sole's
# world placement mean anything; reading the newer position against the older
# pose just measures the off-by-one.
func measure(count: int) -> Dictionary:
	var result := {"slide": 0.0, "span": 0.0, "pop": 0.0, "stride": 0.0, "pace": 0.0, "samples": 0}
	var pending: float = p1.global_position.x
	var posed_from := pending
	var previous := [sole(posed_from, 0), sole(posed_from, 1)]
	var last_phase: float = p1.visual.gait_phase
	var cycles := 0.0
	var distance := 0.0
	for i in count:
		await physics_frame
		await process_frame
		var previous_travel := posed_from
		posed_from = pending
		pending = p1.global_position.x
		var covered: float = posed_from - previous_travel
		var current := [sole(posed_from, 0), sole(posed_from, 1)]
		var step: float = p1.visual.gait_phase - last_phase
		last_phase = p1.visual.gait_phase
		if step > 0.5:
			step -= 1.0
		elif step < -0.5:
			step += 1.0
		if p1.visual.gait_weight < 0.95 or absf(covered) < 0.5:
			previous = current
			continue
		result.samples += 1
		cycles += absf(step)
		distance += absf(covered)
		result.pace = maxf(result.pace, absf(p1.visual.gait_speed))
		# At every instant at least one foot is planted, so the smaller of the
		# two sole movements is the planted one's slide.
		var slide: float = minf(absf(current[0] - previous[0]), absf(current[1] - previous[1]))
		result.slide = maxf(result.slide, slide / absf(covered))
		for side in 2:
			result.pop = maxf(result.pop, absf(current[side] - previous[side]) - absf(covered))
			result.span = maxf(result.span, leg_span(p1, side))
		previous = current
	# Ground covered per full cycle. Matching the stride the gait is built
	# around is the same statement as the planted foot never slipping, made
	# over a whole stretch of walking instead of frame by frame.
	result.stride = distance / maxf(cycles, 0.001)
	return result

# Saves one rendered frame at each eighth of a stride, so the cycle can be
# read as a flipbook rather than as numbers.
func capture_cycle() -> void:
	await runway(-3.9, 4.2)
	Input.action_press("p1_3d_right")
	await frames(20)
	for shot in 8:
		var target := fposmod(p1.visual.gait_phase + 0.125, 1.0)
		while absf(fposmod(p1.visual.gait_phase - target + 0.5, 1.0) - 0.5) > 0.03:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/walk-cycle-%d.png" % shot)
	Input.action_release("p1_3d_right")

func run() -> void:
	root.get_node("MatchSetup").vs_ai = false
	root.get_node("Settings").touch_controls = false
	arena = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	p1 = arena.player1
	p2 = arena.player2
	arena.intro_timer = 0
	arena._hide_banner()
	await frames(10)
	check(p1.visual.gait_weight < 0.05, "A standing fighter shows no stride")
	var resting_span := leg_span(p1, 1)

	await runway(-3.6, 4.2)
	Input.action_press("p1_3d_right")
	await frames(16)
	check(p1.state == p1.State.WALK, "Holding forward walks")
	check(p1.visual.gait_weight > 0.9, "The stride is fully faded in at walking speed")
	check(p1.visual.gait_speed > 0.0, "Walking forward runs the cycle forwards")
	var walk: Dictionary = await measure(60)
	print("walk: %s" % walk)
	check(walk.samples > 30, "Measured a steady stretch of walking")
	check(walk.slide < 0.3, "The planted sole holds its ground (worst slide %.2f of the distance covered)" % walk.slide)
	check(walk.span < 59.5, "The stride never drags a leg out to its full length (worst span %.1f)" % walk.span)
	check(walk.pop < 14.0, "No frame jumps a foot beyond a swinging step (worst %.1f)" % walk.pop)
	check(absf(walk.stride - 2.0 * p1.visual.STEP_REACH / 0.68) < 5.0, "A walk cycle covers exactly the stride it is built around (%.1f units)" % walk.stride)
	check(walk.pace / walk.stride < 3.4, "Cadence stays in step with the ground speed (%.2f cycles/s)" % (walk.pace / walk.stride))
	Input.action_release("p1_3d_right")
	await frames(20)

	await runway(-3.9, 4.2)
	Input.action_press("p1_3d_right")
	Input.action_press("p1_3d_run")
	await frames(16)
	var sprint: Dictionary = await measure(40)
	print("run: %s / run_mix %.2f / reach %.1f" % [sprint, p1.visual._run_mix, p1.visual._reach])
	check(sprint.samples > 15, "Measured a steady stretch of running")
	check(sprint.pace > walk.pace * 1.2, "A run covers ground faster than a walk")
	check(sprint.slide < 0.35, "A run plants its soles too (worst slide %.2f)" % sprint.slide)
	check(sprint.span < 59.5, "A running stride stays inside the leg's length (worst span %.1f)" % sprint.span)
	Input.action_release("p1_3d_run")

	Input.action_release("p1_3d_right")
	await frames(3)
	# Braking is near-instant; the stride is not, or stopping would pop the
	# legs straight out of a step and into the guard stance.
	check(p1.state != p1.State.WALK and p1.visual.gait_weight > 0.3, "The stride eases out of a stop instead of snapping off")
	await frames(40)
	check(p1.visual.gait_weight < 0.05, "A stopped fighter settles back into the guard stance")
	check(absf(leg_span(p1, 1) - resting_span) < 2.0, "The guard stance returns to its original width")

	# Retreating: the rival stays just ahead, so backing away has the whole
	# strip behind it.
	await runway(3.4, 4.24)
	Input.action_press("p1_3d_left")
	await frames(16)
	check(p1.visual.gait_speed < 0.0, "Backing away runs the cycle in reverse")
	var retreat: Dictionary = await measure(40)
	print("retreat: %s" % retreat)
	check(retreat.samples > 15, "Measured a steady stretch of backing away")
	check(retreat.slide < 0.35, "A backstep plants its soles too (worst slide %.2f)" % retreat.slide)
	Input.action_release("p1_3d_left")
	await frames(20)

	# Walking into a wall must not run the legs in place.
	p1.body.position.x = 4.2
	Input.action_press("p1_3d_right")
	await frames(40)
	check(p1.visual.gait_weight < 0.2, "Blocked movement stops the cycle instead of running in place")
	Input.action_release("p1_3d_right")

	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await capture_cycle()
	if failures.is_empty():
		print("WALK_CYCLE_TEST: ALL PASS")
	else:
		print("WALK_CYCLE_TEST: %d FAILURE(S)" % failures.size())
		for failure in failures:
			print(" - " + failure)
	quit(0 if failures.is_empty() else 1)
