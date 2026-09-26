extends SceneTree
var failures: Array[String] = []
var capture: bool = false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func settle() -> void:
	await create_timer(0.4).timeout

func screenshot(filename: String) -> void:
	if capture and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")

func _run() -> void:
	root.get_node("Settings").touch_controls = false
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await settle()
	check(menu.play_button.has_focus(), "Play receives initial keyboard focus")
	check(menu.get_node('GameTitle').text == 'WHO WON?', 'New title is displayed')
	check(menu.find_children('*', 'CharacterBody2D', true, false).is_empty(), 'Menu contains no character previews')
	for state in ['font_color', 'font_hover_color', 'font_pressed_color', 'font_focus_color']:
		check(menu.play_button.get_theme_color(state).get_luminance() > 0.3, 'Start text stays bright over the dark title background in ' + state)
	await screenshot("ui-home")
	menu._show_settings()
	await settle()
	check(menu.modal.visible, "Settings opens")
	check(menu.play_button.focus_mode == Control.FOCUS_NONE, "Dialog keeps focus away from background")
	await screenshot("ui-settings")
	menu._close_modal()
	await process_frame
	check(menu.play_button.has_focus(), "Closing dialog restores focus")
	menu._show_guide()
	await settle()
	await screenshot("ui-guide")
	menu._close_modal()
	await process_frame
	root.get_node("MatchSetup").selected_fighters.assign([2, 3])
	menu.play_button.pressed.emit()
	await create_timer(1.2).timeout
	# Play now routes through the full roster screen instead of jumping straight to the arena.
	var selection: Node = current_scene
	check(selection.cards.size() == 7, "Start opens the complete roster")
	selection.ready_players.assign([true, true])
	selection._start_match()
	await settle()
	var arena := current_scene
	check(arena.get_script().resource_path.ends_with("arena_3d.gd"), "Start enters arena")
	check(arena.player1.character_profile.name == "BALLAS" and arena.player2.character_profile.name == "BIB", "Direct play preserves selected fighters")
	var hud := arena.get_child(arena.get_child_count() - 1)
	check(hud.damage_bars[0].size == arena.health_bar1.size, "Damage trail matches health bar dimensions")
	await screenshot("ui-intro")
	arena.intro_timer = 0.0
	arena._hide_banner()
	arena.player1.set_physics_process(false)
	arena.player2.set_physics_process(false)
	arena.player2.take_hit(35, 0, 1)
	await settle()
	check(arena.health_bar2.value == arena.player2.health, "HUD tracks damage")
	await screenshot("ui-match")
	var timer_before: float = arena.time_remaining
	arena._toggle_move_guide()
	await settle()
	check(is_equal_approx(arena.time_remaining, timer_before), "Move guide pauses the round timer")
	await screenshot("ui-moves")
	arena._toggle_move_guide()
	arena._end_round(1)
	await settle()
	await screenshot("ui-results")
	check(not hud.result_panel.visible and arena.result_label.visible, "Round end shows only the winner callout, no panel")
	await create_timer(arena.ROUND_PAUSE + 0.4).timeout
	await settle()
	check(arena.round_index == 1, "Next round starts by itself after the callout")
	check(arena.health_bar2.value == arena.player2.max_health, "New round resets health")
	check(arena.timer_label.text == "99", "New round resets displayed timer")
	arena._begin_round(3)
	arena.intro_timer = 0.0
	arena._hide_banner()
	arena.round_wins = [1, 1]
	arena._end_round(0)
	check(arena.result_label.text == "MATCH DRAW", "Tied match has a draw result")
	hud.next_button.pressed.emit()
	await settle()
	check(arena.round_index == 0 and not arena.match_over, "Rematch starts fresh")
	print("UI FLOW: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
