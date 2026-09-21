extends SceneTree
var failures: Array[String] = []
var arena: Node
var p1: Node
var p2: Node

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func reset_fighters(a := Vector3(-1, 0.02, 0), b := Vector3(1, 0.02, 0)) -> void:
	for player in [1, 2]:
		for suffix in ["left", "right", "near", "far", "jump", "block", "punch", "kick", "run"]:
			Input.action_release("p%d_3d_%s" % [player, suffix])
	p1.reset_for_new_round()
	p2.reset_for_new_round()
	p1.body.position = a
	p2.body.position = b
	p1._last_tap_time = -999
	p2._last_tap_time = -999
	await frames(6)

func run() -> void:
	root.get_node("MatchSetup").vs_ai = false
	root.get_node("Settings").touch_controls = false
	arena = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	p1 = arena.player1
	p2 = arena.player2
	arena.intro_timer = 0
	arena._hide_banner()
	await frames(10)
	check(p1.body is CharacterBody3D and p1._is_grounded(), "Fighter uses a grounded 3D physics body")
	check(p1.visual.world_root == p1.pivot and p1.visual.viewport_3d == null, "Characters render in the shared 3D world")
	var start: Vector3 = p1.body.position
	Input.action_press("p1_3d_far")
	await frames(25)
	Input.action_release("p1_3d_far")
	check(p1.body.position.z < start.z - 0.5, "Depth movement travels across the arena")
	await reset_fighters(Vector3(-3, 0.02, 0), Vector3(3, 0.02, 0))
	Input.action_press("p1_3d_right")
	await frames(30)
	var straight: float = Vector2(p1.body.position.x + 3, p1.body.position.z).length()
	await reset_fighters(Vector3(-3, 0.02, 0), Vector3(3, 0.02, 0))
	Input.action_press("p1_3d_right")
	Input.action_press("p1_3d_near")
	await frames(30)
	var diagonal: float = Vector2(p1.body.position.x + 3, p1.body.position.z).length()
	check(absf(straight - diagonal) < 0.08, "Diagonal movement has the same speed as straight movement")
	await reset_fighters()
	Input.action_press("p1_3d_jump")
	await frames(1)
	Input.action_release("p1_3d_jump")
	await frames(15)
	check(p1.body.position.y > 0.7, "Jump lifts the 3D body off the ground")
	await frames(65)
	check(p1._is_grounded() and absf(p1.body.position.y) < 0.03, "Gravity returns the fighter to the floor")
	await reset_fighters(Vector3(-0.44, 0.02, 0), Vector3(0.44, 0.02, 0))
	p1._start_style_move("jab")
	await frames(10)
	check(p2.health < 100, "A 3D strike damages an overlapping opponent")
	var first_health: int = p2.health
	await frames(6)
	check(p2.health == first_health, "Active frames cannot hit the same rival twice")
	await reset_fighters(Vector3(-0.44, 0.02, 0), Vector3(0.44, 0.02, 1.3))
	# Commit the strike to +X while the rival is offset along Z.
	p1.forward = Vector3.RIGHT
	p1._start_style_move("jab")
	await frames(18)
	check(p2.health == 100, "A strike misses a sidestepping rival outside its 3D volume")
	await reset_fighters(Vector3(-0.44, 0.02, 0), Vector3(0.44, 0.02, 0))
	Input.action_press("p2_3d_block")
	await frames(12)
	p1._start_style_move("jab")
	await frames(12)
	check(p2.health >= 98 and p2.health < 100, "Guard applies chip damage using the existing combat rules")
	await reset_fighters(Vector3(-0.2, 0.02, 0), Vector3(0.2, 0.02, 0))
	await frames(8)
	check(p1.body.position.distance_to(p2.body.position) >= 0.63, "Circular pushboxes separate the fighters")
	await reset_fighters(Vector3(0, 2.5, 0), Vector3(0, 0.02, 0))
	await frames(85)
	check(p1._is_grounded() and p1.body.position.y < 0.03, "Landing above a rival returns to the floor instead of standing on their head")
	await reset_fighters(Vector3(6.6, 0.02, 0), Vector3(0, 0.02, 0))
	Input.action_press("p1_3d_right")
	Input.action_press("p1_3d_run")
	await frames(50)
	check(p1.body.position.x < 6.8, "Solid 3D arena walls stop running fighters")
	await reset_fighters()
	arena._toggle_move_guide()
	var paused_position: Vector3 = p1.body.position
	Input.action_press("p1_3d_far")
	await frames(15)
	check(p1.body.position.is_equal_approx(paused_position), "Move guide pauses the 3D simulation")
	arena._toggle_move_guide()
	await reset_fighters(Vector3(-2, 0.02, 1), Vector3(2, 0.02, -1))
	var ai: Node = load("res://scripts/ai_controller_3d.gd").new()
	ai.fighter = p2
	ai.opponent = p1
	p2.ai_controlled = true
	arena.add_child(ai)
	var initial_distance: float = p1._opponent_distance(p2)
	await frames(180)
	check(p1._opponent_distance(p2) < initial_distance - 50, "AI approaches a rival across both floor axes")
	check(p2.body.position.z > -0.8, "AI tracks depth instead of walking along a 2D line")
	ai.queue_free()
	await frames(1)
	p2.ai_controlled = false
	await reset_fighters()
	arena._end_round(1)
	arena._begin_round(1)
	arena.intro_timer = 0
	arena._hide_banner()
	await frames(6)
	check(p1.health == 100 and p2.health == 100 and arena.round_index == 1, "Round transition resets health and 3D positions")
	check(p1.body.position.distance_to(p1.spawn_position) < 0.04, "New round restores the 3D spawn")
	await reset_fighters(Vector3(-6.5, 0.02, -4.5), Vector3(6.5, 0.02, 4.5))
	await frames(90)
	var screen_size := root.get_visible_rect().size
	for fighter in [p1, p2]:
		var head_point: Vector2 = arena.camera_3d.unproject_position(fighter.body.position + Vector3.UP * 1.9)
		var foot_point: Vector2 = arena.camera_3d.unproject_position(fighter.body.position)
		check(head_point.y > screen_size.y * 0.18 and foot_point.y < screen_size.y * 0.89 and foot_point.x > screen_size.x * 0.04 and foot_point.x < screen_size.x * 0.96, "Camera keeps distant fighters between the HUD panels")
	for i in 7:
		p1.apply_character(i)
		await frames(2)
		check(p1.visual._profile_id == p1.character_profile.id, "Roster profile updates the real 3D mesh")
	p1.apply_character(0)
	await reset_fighters(Vector3(-0.9, 0.02, 0), Vector3(0.9, 0.02, 0))
	if "--capture" in OS.get_cmdline_user_args():
		await frames(20)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/arena-3d-review.png")
	print("ARENA_3D_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
