extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func key(menu: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = code
	menu._input(event)

func run() -> void:
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	check(menu.play_button.has_focus(), "Menu is immediately ready for keyboard input")
	check(menu.home_modes.size() == 4, "Menu lists exactly four fight modes")
	menu._choose_home_mode("arcade")
	key(menu, KEY_RIGHT)
	check(menu._selected_mode() == "story", "Right arrow selects the next mode")
	key(menu, KEY_LEFT)
	check(menu._selected_mode() == "arcade", "Left arrow selects the previous mode")
	menu._show_settings()
	key(menu, KEY_RIGHT)
	check(menu._selected_mode() == "arcade", "Modal isolates mode navigation")
	menu._close_modal()
	menu.home_modes.story.pressed.emit()
	menu.home_modes.local.pressed.emit()
	check(menu._selected_mode() == "story", "Repeated clicks cannot change the chosen mode")
	await create_timer(0.35).timeout
	check(menu.backdrop.opening > 0 and menu.backdrop.opening < 1, "Transition wipe animates before scene change")
	await create_timer(0.9).timeout
	check(current_scene.get_script().resource_path.ends_with("character_select.gd"), "Mode leads to character selection")
	change_scene_to_file("res://scenes/MainMenu.tscn")
	await process_frame
	await process_frame
	menu = current_scene
	key(menu, KEY_ENTER)
	check(menu.transitioning, "Enter starts the mode immediately without an entrance intro")
	print("DOOR_MENU_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
