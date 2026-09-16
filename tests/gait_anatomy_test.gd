extends SceneTree
## Checks anatomy across the whole roster, not just one attractive gait frame.
const ROSTER := preload("res://scripts/fighter_roster.gd")
const PHASE_SAMPLES := 32
const BONE_TOLERANCE := 0.4
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func check_rest(gait: Node, character: String) -> void:
	# Releasing movement must return exactly to the authored body proportions,
	# regardless of which foot was lifted or whether the player was running.
	for running in [false, true]:
		for phase in [0.0, 0.23, 0.57, 0.91]:
			gait.sample(phase, running, gait.cycle_length(running), 0.0)
			for part in gait.meshes.size():
				check(gait.meshes[part].polygon == gait.rest_vertices[part],
					"%s: stopping restores original mesh %d (phase %.2f, run %s)" % [character, part, phase, running])
			# Bone lengths alone miss a knee flipping to the other IK solution.
			gait.sample(phase, running, gait.cycle_length(running), 0.01)
			for side in 2:
				check(gait.knees[side].distance_to(gait.rest_knees[side]) < 0.5,
					"%s: starting or stopping must not flip knee %d" % [character, side])
				var largest_jump := 0.0
				for vertex in gait.rest_vertices[side].size():
					largest_jump = maxf(largest_jump, gait.meshes[side].polygon[vertex].distance_to(gait.rest_vertices[side][vertex]))
				check(largest_jump < 1.0, "%s: leg artwork stays continuous at rest (%.2f px)" % [character, largest_jump])

func check_cycle(gait: Node, character: String, mode: String) -> void:
	var running := mode == "run"
	var retreat := mode == "retreat"
	var stride: float = gait.cycle_length(running)
	check(stride > 0.0, "%s / %s: stride must advance the gait" % [character, mode])
	var greatest_thigh_error := 0.0
	var greatest_shin_error := 0.0
	var greatest_floor_intrusion := 0.0
	var greatest_hip_drop := 0.0
	var minimum_foot_gap := INF
	var lifts: Array[float] = [0.0, 0.0]
	for frame in PHASE_SAMPLES:
		var phase := float(frame) / float(PHASE_SAMPLES)
		gait.sample(phase, running, stride, 1.0, retreat)
		greatest_hip_drop = maxf(greatest_hip_drop,gait.body_shift.y)
		minimum_foot_gap = minf(minimum_foot_gap, gait.feet[1].x - gait.feet[0].x)
		for side in 2:
			var thigh: float = gait.hips[side].distance_to(gait.rest_knees[side])
			var shin: float = gait.rest_knees[side].distance_to(gait.ankles[side])
			var animated_thigh: float = gait.posed_hips[side].distance_to(gait.knees[side])
			var animated_shin: float = gait.knees[side].distance_to(gait.feet[side])
			greatest_thigh_error = maxf(greatest_thigh_error, absf(animated_thigh - thigh))
			greatest_shin_error = maxf(greatest_shin_error, absf(animated_shin - shin))
			greatest_floor_intrusion = maxf(greatest_floor_intrusion, gait.feet[side].y - gait.ankles[side].y)
			lifts[side] = maxf(lifts[side], gait.ankles[side].y - gait.feet[side].y)
	var label := "%s / %s" % [character, mode]
	check(greatest_thigh_error <= BONE_TOLERANCE,
		"%s: thighs keep their original lengths (max error %.3f px)" % [label, greatest_thigh_error])
	check(greatest_shin_error <= BONE_TOLERANCE,
		"%s: shins reach their shoes without stretching (max error %.3f px)" % [label, greatest_shin_error])
	check(greatest_floor_intrusion <= 0.01,
		"%s: feet remain above their contact plane (intrusion %.3f px)" % [label, greatest_floor_intrusion])
	if not running:
		check(greatest_hip_drop < gait.height * 0.07,
			"%s: steps do not collapse into squats (hip drop %.2f px)" % [label, greatest_hip_drop])
		check(minimum_foot_gap > 0.0,
			"%s: combat steps preserve rear/front stance order (minimum gap %.3f px)" % [label, minimum_foot_gap])
	for side in 2:
		check(lifts[side] > 1.0,
			"%s: leg %d leaves the floor during recovery (max lift %.3f px)" % [label, side, lifts[side]])
	check_foot_plants(gait, character, running, retreat)

func check_foot_plants(gait: Node, character: String, running: bool, retreat: bool) -> void:
	# Phase advances with distance traveled in either direction; the backstep
	# target reverses the foot motion while the fighter still faces the rival.
	var stride: float = gait.cycle_length(running)
	var world_travel := -1.0 if retreat else 1.0
	var planted_samples := 0
	var greatest_slip := 0.0
	for frame in PHASE_SAMPLES:
		var phase := float(frame) / float(PHASE_SAMPLES)
		gait.sample(phase, running, stride, 1.0, retreat)
		var before: Array[Vector2] = [gait.feet[0], gait.feet[1]]
		gait.sample(fposmod(phase + 1.0 / stride, 1.0), running, stride, 1.0, retreat)
		for side in 2:
			if absf(before[side].y - gait.ankles[side].y) > 0.0001:
				continue
			if absf(gait.feet[side].y - gait.ankles[side].y) > 0.0001:
				continue
			planted_samples += 1
			greatest_slip = maxf(greatest_slip, absf(gait.feet[side].x + world_travel - before[side].x))
	var label := "%s / %s" % [character, "retreat" if retreat else ("run" if running else "walk")]
	check(planted_samples > 10, "%s: contact checks cover both legs over the cycle" % label)
	check(greatest_slip <= 0.001,
		"%s: supporting feet stay planted as the fighter travels (max slip %.5f px)" % [label, greatest_slip])

func run() -> void:
	var fighter: Node = load("res://scenes/Player.tscn").instantiate()
	root.add_child(fighter)
	fighter.set_physics_process(false)
	fighter.apply_style(load("res://resources/styles/action.tres"))
	fighter.visual.set_process(false)
	for character_index in 7:
		fighter.apply_character(character_index)
		var character: String = ROSTER.profile(character_index).id
		# Archived deformation experiment: never instantiated by live fighters.
		var gait: Node = load("res://scripts/fighter_locomotion.gd").new()
		root.add_child(gait)
		var data: Dictionary = load("res://scripts/fighter_sprite_regions.gd").DATA[character]
		var texture := ImageTexture.create_from_image(Image.load_from_file("res://assets/sprites/fighter/nepali/" + character + ".png"))
		gait.configure(texture, data.frames[1], character, fighter.visual.render_height, data.standing_height)
		check_rest(gait, character)
		for mode in ["walk", "run", "retreat"]:
			check_cycle(gait, character, mode)
		gait.queue_free()
	print("GAIT_ANATOMY_TEST: ", "ALL PASS (7 fighters, 3 gaits, 32 phases)" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
