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
	# The seven illustrated backdrops behind the legacy 2D arena: every entry
	# names a real texture, and the selection wraps in both directions.
	for i in 7:
		var data: Dictionary = CATALOG.arena(i)
		check(not str(data.name).is_empty() and ResourceLoader.exists(data.texture), "Arena %d has a name and artwork" % (i + 1))
	var count: int = CATALOG.ARENAS.size()
	check(CATALOG.arena(posmod(-1, count)).name == CATALOG.arena(6).name, "Previous wraps to the seventh arena")
	check(CATALOG.arena(posmod(7, count)).name == CATALOG.arena(0).name, "Next wraps to the first arena")
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
		var ambience: Node2D = arena.get_node("ArenaAmbience")
		check(ambience.get_index() > arena.background.get_index() and ambience.get_index() < arena.player1.get_index(), "Scenery renders between painting and fighters")
		var before: Vector2 = ambience.bird_position(0)
		await settle()
		check(not ambience.bird_position(0).is_equal_approx(before), "Birds move over time in every arena")
		check(not ambience.hiker_position(0.2).is_equal_approx(ambience.hiker_position(0.8)), "Tourists have a traversable route")
		arena._toggle_move_guide()
		var paused_time: float = ambience.elapsed
		await settle()
		check(is_equal_approx(ambience.elapsed, paused_time), "Move guide pauses scenery")
		arena._toggle_move_guide()
		await save_view("arena-%02d" % (i + 1))
		arena.queue_free()
		await process_frame
	setup.selected_arena = 0
	print("ARENA_GALLERY_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
