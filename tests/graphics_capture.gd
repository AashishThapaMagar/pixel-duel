extends SceneTree
## Rendered review of the arena visuals: every round at rest, a landed hit
## with its impact effects, a dash afterimage and the knockout flash.
## Needs a display (no --headless); images go to .godot/graphics-*.png.
##
##   godot --path . --fixed-fps 60 -s res://tests/graphics_capture.gd
var arena: Node
var p1: Node
var p2: Node

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/graphics-%s.png" % name)
	print("captured %s at %.1fs" % [name, Time.get_ticks_msec() / 1000.0])

## Straight into the fight: no banner, no "FIGHT!" callout and no fade
## from the previous round, so the scenery is clear for review.
func start_round(index: int) -> void:
	arena._begin_round(index)
	arena.intro_timer = 0
	arena.banner.visible = false
	arena._hide_banner()
	if arena.nepal_stage.fade != null:
		arena.nepal_stage.fade.modulate.a = 0.0
	await frames(1)

func place(a: Vector3, b: Vector3) -> void:
	for player in [1, 2]:
		for suffix in ["left", "right", "near", "far", "jump", "block", "punch", "kick", "run"]:
			Input.action_release("p%d_3d_%s" % [player, suffix])
	p1.reset_for_new_round()
	p2.reset_for_new_round()
	p1.body.position = a
	p2.body.position = b
	await frames(6)

func run() -> void:
	root.get_node("MatchSetup").vs_ai = false
	root.get_node("Settings").touch_controls = false
	var setup: Node = root.get_node("MatchSetup")
	setup.selected_fighters[0] = 0
	setup.selected_fighters[1] = 1
	arena = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	p1 = arena.player1
	p2 = arena.player2
	for index in 4:
		await start_round(index)
		await place(Vector3(-1.0, 0.02, 0), Vector3(1.0, 0.02, 0))
		await frames(16)
		await snap("round-%d" % (index + 1))
	await start_round(1)
	await place(Vector3(-0.44, 0.02, 0), Vector3(0.44, 0.02, 0))
	await frames(12)
	p1._start_style_move("kick")
	for i in 40:
		await frames(1)
		if p2.health < 100:
			break
	await frames(2)
	await snap("hit")
	await frames(6)
	await snap("hit-after")
	await place(Vector3(-2.5, 0.02, 0), Vector3(2.0, 0.02, 0))
	await frames(10)
	p1._start_style_move("kick")
	await frames(9)
	await snap("kick")
	await place(Vector3(-0.44, 0.02, 0), Vector3(0.44, 0.02, 0))
	p2.health = 4
	await frames(10)
	p1._start_style_move("kick")
	for i in 40:
		await frames(1)
		if p2.state == p2.State.KO:
			break
	await frames(3)
	await snap("ko")
	await frames(30)
	await snap("ko-after")
	quit(0)
