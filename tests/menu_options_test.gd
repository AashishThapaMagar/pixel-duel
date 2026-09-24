extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func capture(label: String) -> void:
	await create_timer(0.35).timeout
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/option-" + label + ".png")
func run() -> void:
	var setup = root.get_node("MatchSetup")
	for mode in ["local", "ai", "arcade", "story"]:
		setup.story = mode == "story"
		setup.arcade = mode in ["arcade", "story"]
		setup.vs_ai = mode != "local"
		var select = load("res://scenes/CharacterSelect.tscn").instantiate()
		root.add_child(select)
		current_scene = select
		check(select.mode_id == mode, "Mode chooses its own presentation")
		if mode == "ai":
			select._select_for_player(4, 1)
			check(select.ready_players[1], "Changing CPU rival keeps CPU ready")
			select.difficulty_picker.item_selected.emit(2)
			check(setup.ai_difficulty == 2, "CPU challenge stores chosen difficulty")
			select._toggle_ready(0)
			check(not select.start_button.disabled, "Human confirmation enables CPU challenge")
		if setup.arcade:
			var opponent: int = select.selections[1]
			select._select_for_player(5, 1)
			check(select.selections[1] == opponent, "Campaign opponent cannot be overridden")
			select._toggle_ready(0)
			check(select.editing_player == 0, "Campaign keeps editing the human fighter")
		await capture(mode)
		select.queue_free()
		await process_frame
	setup.ai_difficulty = 1
	print("MENU_OPTIONS_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
