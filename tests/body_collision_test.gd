extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(960, 80)
	collider.shape = shape
	floor_body.position = Vector2(480, 490)
	floor_body.add_child(collider)
	world.add_child(floor_body)
	var scene := load("res://scenes/Player.tscn") as PackedScene
	var p1 = scene.instantiate()
	var p2 = scene.instantiate()
	p2.player_id = 2
	world.add_child(p1)
	world.add_child(p2)
	p1.opponent = p2
	p2.opponent = p1
	p1.controls_enabled = false
	p2.controls_enabled = false
	# Reproduce landing directly on a rival's head, in both player orders.
	for falling in [p1, p2]:
		var standing = p2 if falling == p1 else p1
		falling.position = Vector2(480, 250)
		standing.position = Vector2(480, 450)
		falling.velocity = Vector2.ZERO
		standing.velocity = Vector2.ZERO
		await frames(75)
		check(falling.is_on_floor() and absf(falling.position.y - 450.0) < 0.2, "Falling fighter lands on the arena floor, not a rival")
		check(absf(standing.position.y - 450.0) < 0.2, "Contact never lifts the standing fighter")
		check(absf(p1.position.x - p2.position.x) >= 37.9, "Landing separates the fighters sideways")
	for edge in [34.0, 926.0]:
		p1.position = Vector2(edge, 450)
		p2.position = Vector2(edge, 450)
		await frames(4)
		check(absf(p1.position.x - p2.position.x) >= 37.9, "Corner contact leaves no body overlap")
		check(p1.position.x >= 34 and p1.position.x <= 926 and p2.position.x >= 34 and p2.position.x <= 926, "Pushboxes keep both fighters inside the arena")
	p1.position = Vector2(430, 290)
	p2.position = Vector2(480, 450)
	p1.state = p1.State.JUMP
	p1.velocity = Vector2(260, -300)
	p1.controls_enabled = true
	await frames(20)
	check(p1.position.x > p2.position.x and not p1.is_on_floor(), "A jump can cross above an opponent")
	await frames(75)
	check(p1.is_on_floor() and absf(p1.position.y - 450) < 0.2, "Jump-over returns to the arena floor")
	print("BODY_COLLISION_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
