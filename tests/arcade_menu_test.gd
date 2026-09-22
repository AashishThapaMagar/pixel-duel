extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	await create_timer(0.3).timeout

func snap(filename: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")

func run() -> void:
	var setup: Node = root.get_node("MatchSetup")
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await settle()
	menu._choose_home_mode("local")
	check(menu.play_button.has_focus(), "Start has keyboard focus")
	await snap("arcade-main-menu")
	menu._start_fight()
	await settle()
	var select: Node = current_scene
	check(select.cards.size() == 7, "All seven roster cards exist")
	for card in select.cards:
		check(card.position.x >= 0 and card.position.x + card.size.x <= 960, "Every roster card fits on screen")
	select._select_for_player(2, 0)
	select._select_for_player(5, 1)
	check(select.names[0].text == "SAB" and select.names[1].text == "SUP", "Large portraits match each selection")
	check(select.portraits[0].fighter.character_profile.id == "sab", "Preview renders the actual selected fighter")
	check(select.start_button.disabled, "Both local players must confirm")
	select._toggle_ready(0)
	select._toggle_ready(1)
	await settle()
	await snap("arcade-character-select")
	select._start_match()
	await settle()
	check(current_scene.player1.character_profile.id == "sab" and current_scene.player2.character_profile.id == "sup", "Selections reach the match")
	for mode in ["ai", "arcade", "story"]:
		change_scene_to_file("res://scenes/MainMenu.tscn")
		await settle()
		current_scene._choose_home_mode(mode)
		current_scene._start_fight()
		await settle()
		select = current_scene
		check(select.ready_players[1], "Computer is ready in " + mode)
		select._select_for_player(3, 0)
		select._toggle_ready(0)
		select._start_match()
		await settle()
		check(current_scene.get_script().resource_path.ends_with("story_dialogue.gd") if mode == "story" else current_scene.get_script().resource_path.ends_with("arena_3d.gd"), "Correct scene after selecting " + mode)
	print("ARCADE_MENU_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
