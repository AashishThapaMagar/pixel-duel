extends SceneTree
const CATALOG := preload("res://scripts/arena_catalog.gd")
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
	await create_timer(0.35).timeout

func save_view(filename: String) -> void:
	if capture and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")

func _run() -> void:
	check(CATALOG.ARENAS.size() == 7, "Exactly seven illustrated arenas are selectable")
	var setup: Node = root.get_node("MatchSetup")
	setup.vs_ai = false
	setup.selected_arena = 0
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu._show_match_setup()
	await settle()
	await save_view("arena-picker")
	menu._cycle_arena(-1)
	check(setup.selected_arena == 6, "Previous wraps to the seventh arena")
	menu._cycle_arena(1)
	check(setup.selected_arena == 0, "Next wraps to the first arena")
	for i in 7:
		var data: Dictionary = CATALOG.arena(i)
		check(menu.arena_name_label.text == data.name, "Picker shows " + data.name)
		check(menu.arena_preview.texture != null and menu.arena_preview.texture.resource_path == data.texture, "Preview matches " + data.name)
		menu._cycle_arena(1)
	# Use the actual Fight button inside the modal, not the main menu shortcut.
	for child in menu.modal_content.get_children():
		if child is Button and child.text == "FIGHT  /  ENTER":
			child.pressed.emit()
			break
	await settle()
	check(current_scene != menu and current_scene.has_node("Player1"), "Fight starts the selected arena from Match Setup")
	current_scene.queue_free()
	await process_frame
	for i in 7:
		setup.selected_arena = i
		var arena: Node = load("res://scenes/Arena.tscn").instantiate()
		root.add_child(arena)
		current_scene = arena
		arena.intro_timer = 0.0
		arena._hide_banner()
		await settle()
		check(arena.background.texture.resource_path == CATALOG.arena(i).texture, "Match loads the selected artwork")
		check((arena.background.texture.get_size() * arena.background.scale).is_equal_approx(Vector2(960, 540)), "Artwork fills the game canvas")
		check(arena.player1.is_on_floor() and arena.player2.is_on_floor(), "Fighters stand on the unchanged collision floor")
		check(not arena.get_node("Ground/GroundVisual").visible, "Legacy floor does not cover the illustrated terrace")
		await save_view("arena-%02d" % (i + 1))
		arena.queue_free()
		await process_frame
	setup.selected_arena = 0
	print("ARENA_GALLERY_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
