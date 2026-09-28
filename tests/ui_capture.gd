extends SceneTree
## Rendered review of the menus and match presentation: title screen,
## Records, Settings, Fight Options, Controls, fighter select with a random
## spin, the match-opening VS clash, the round call, the input display and
## a PERFECT round. Needs a display; images go to .godot/ui-*.png.
##
##   godot --path . --fixed-fps 60 -s res://tests/ui_capture.gd
func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await process_frame

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/ui-%s.png" % name)
	print("captured ", name)

func run() -> void:
	root.get_node("Settings").touch_controls = false
	root.get_node("Settings").input_display = true
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(40)
	# "--match" skips the option pages and goes straight to the fight.
	var quick := "--match" in OS.get_cmdline_user_args()
	if not quick:
		await snap("title")
	for page in ([] if quick else ["_show_records", "_show_settings", "_show_fight_options", "_show_controls", "_show_graphics"]):
		menu.call(page)
		await frames(20)
		await snap(page.trim_prefix("_show_"))
		menu._close_modal()
		await frames(2)
	menu._choose_home_mode("local")
	menu._start_fight()
	await create_timer(1.3).timeout
	var select: Node = current_scene
	await frames(12)
	select._roulette(0)
	await frames(14)
	await snap("select-spin")
	await create_timer(2.0).timeout
	select._toggle_ready(1)
	await frames(6)
	await snap("select")
	select._start_match()
	await create_timer(0.55).timeout
	await frames(2)
	await snap("clash")
	await create_timer(1.6).timeout
	await snap("round-call")
	var arena: Node = current_scene
	arena.intro_timer = 0
	arena._hide_banner()
	arena.player2.body.position = Vector3(0.5, 0.02, 0)
	arena.player1.body.position = Vector3(-0.5, 0.02, 0)
	for action in ["p1_3d_right", "p1_3d_punch", "p1_3d_kick", "p2_3d_left", "p2_3d_block"]:
		Input.action_press(action)
		await frames(1)
		Input.action_release(action)
		await frames(3)
	arena.player2.health = 3
	arena.player1._start_style_move("kick")
	for i in 60:
		await frames(1)
		if arena.result_label.visible:
			break
	await frames(30)
	await snap("perfect")
	# Play the match out to the results card.
	for round_no in 3:
		arena._begin_round(round_no + 1)
		arena.intro_timer = 0
		arena._hide_banner()
		arena.player2.body.position = Vector3(0.5, 0.02, 0)
		arena.player1.body.position = Vector3(-0.5, 0.02, 0)
		await frames(6)
		arena.player2.health = 3
		arena.player1._start_style_move("kick")
		for i in 60:
			await frames(1)
			if arena.result_label.visible:
				break
		if round_no == 0:
			await frames(4)
			await snap("ko")
		await frames(20)
	await frames(50)
	await snap("results")
	quit(0)
