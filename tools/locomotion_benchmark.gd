extends SceneTree
## CPU microbenchmark, not an FPS or input-to-display latency measurement.
## godot --headless --path . -s res://tools/locomotion_benchmark.gd
const SAMPLES := 180

func _initialize() -> void:
	call_deferred("run")

func stats(values: Array[float]) -> Dictionary:
	values.sort()
	var total := 0.0
	for value in values:
		total += value
	return {"mean_ms": total / values.size(), "p50_ms": values[values.size() / 2],
		"p95_ms": values[int(values.size() * 0.95)], "max_ms": values[-1]}

func run() -> void:
	var fighter: Node = load("res://scenes/Player.tscn").instantiate()
	root.add_child(fighter)
	fighter.set_physics_process(false)
	fighter.visual.set_process(false)
	fighter.apply_style(load("res://resources/styles/action.tres"))
	var results := {"engine": Engine.get_version_info().string, "samples_per_case": SAMPLES,
		"scope": "CPU wall time of explicit calls, headless; excludes GPU/presentation/input-device latency", "fighters": {}}
	for character in 7:
		fighter.apply_character(character)
		fighter.state = fighter.State.WALK
		fighter.velocity.x = fighter.move_speed * fighter.WALK_SPEED_RATIO
		var visual: Node = fighter.visual
		var legacy_gait: Node = load("res://scripts/fighter_locomotion.gd").new()
		root.add_child(legacy_gait)
		var character_id: String = fighter.character_profile.id
		var original: Dictionary = load("res://scripts/fighter_sprite_regions.gd").DATA[character_id]
		var texture := ImageTexture.create_from_image(Image.load_from_file("res://assets/sprites/fighter/nepali/" + character_id + ".png"))
		legacy_gait.configure(texture, original.frames[1], character_id, visual.render_height, original.standing_height)
		var gait_times: Array[float] = []
		var frame_times: Array[float] = []
		var update_times: Array[float] = []
		var stride: float = legacy_gait.cycle_length(false)
		for sample in SAMPLES + 20:
			var phase := fposmod(float(sample) / 60.0, 1.0)
			var started := Time.get_ticks_usec()
			legacy_gait.sample(phase, false, stride, 1.0)
			var gait_ms := float(Time.get_ticks_usec() - started) / 1000.0
			started = Time.get_ticks_usec()
			visual._set_frame(2 + sample % 2)
			var frame_ms := float(Time.get_ticks_usec() - started) / 1000.0
			started = Time.get_ticks_usec()
			fighter.position.x += fighter.velocity.x / 60.0
			fighter.combat_time += 1.0 / 60.0
			fighter._update_animation()
			visual._process(1.0 / 60.0)
			var update_ms := float(Time.get_ticks_usec() - started) / 1000.0
			if sample >= 20:
				gait_times.append(gait_ms)
				frame_times.append(frame_ms)
				update_times.append(update_ms)
		results.fighters[fighter.character_profile.id] = {"one_mesh_sample": stats(gait_times),
			"one_atlas_frame": stats(frame_times), "physics_sync_plus_render_update": stats(update_times)}
		legacy_gait.queue_free()
	var file := FileAccess.open("res://.godot/locomotion-benchmark.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	print(JSON.stringify(results))
	quit()
