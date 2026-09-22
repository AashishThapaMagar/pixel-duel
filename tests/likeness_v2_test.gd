extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	root.size = Vector2i(1400, 440)
	root.content_scale_size = Vector2i(1400, 440)
	var canvas := Control.new()
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("18212e")
	background.size = Vector2(1400, 440)
	canvas.add_child(background)
	var ids := [3, 4, 1, 0, 6, 2, 5]
	for slot in ids.size():
		var portrait := preload("res://scripts/roster_portrait.gd").new()
		portrait.index = ids[slot]
		portrait.position = Vector2(slot * 200, 20)
		portrait.size = Vector2(200, 360)
		canvas.add_child(portrait)
		var fighter: Node = portrait.fighter
		var visual: Node = fighter.get_node("Visual")
		await process_frame
		check(visual.likeness.root.get_parent() == visual.model, "Likeness rig belongs to playable model")
		check(visual.likeness.profile.id == fighter.character_profile.id, "Correct costume after selection")
		var count: int = visual.model.get_child_count()
		portrait.show_fighter((ids[slot] + 1) % 7)
		portrait.show_fighter(ids[slot])
		check(visual.model.get_child_count() == count, "Switching fighters does not accumulate costume rigs")
		fighter.state = fighter.State.PUNCH
		fighter.attack_timer = fighter.attack_startup()
		visual.sync_pose(fighter)
		check(visual.likeness.head.position.is_equal_approx(visual.parts.head.position), "Face follows active strike")
		fighter.combat_paused = true
		var frozen: Transform3D = visual.likeness.tails[0].transform
		visual._process(0.1)
		check(visual.likeness.tails[0].transform.is_equal_approx(frozen), "Pause freezes costume motion")
		fighter.combat_paused = false
		fighter.hitstop_remaining = 0.1
		visual._process(0.1)
		check(visual.likeness.tails[0].transform.is_equal_approx(frozen), "Hit-stop freezes costume motion")
		fighter.hitstop_remaining = 0
		fighter.state = fighter.State.IDLE
		visual.reset_pose()
		visual.sync_pose(fighter)
		var label := Label.new()
		label.text = fighter.character_profile.name
		label.position = Vector2(slot * 200, 390)
		label.size.x = 200
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		canvas.add_child(label)
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/likeness-v2-lineup.png")
	print("LIKENESS_V2_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
