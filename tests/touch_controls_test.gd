extends SceneTree
## Touch controls regression: buttons drive the same p1_*/p2_* input
## actions a keyboard would, a lone touch player gets edge-to-edge layout,
## and local 2P gets a per-side split without crossing the midline.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var setup: Node = root.get_node("MatchSetup")
	var settings: Node = root.get_node("Settings")

	# A lone touch player (vs AI) spans the full width: movement lands well
	# into the left half, attacks well into the right half.
	setup.vs_ai = true
	var solo := preload("res://scripts/touch_controls.gd").new()
	root.add_child(solo)
	await process_frame
	var solo_buttons: Array[Node] = solo.find_children("*", "Button", false, false)
	check(solo_buttons.size() == 6, "A lone touch player gets exactly 6 buttons (move x3, action x3)")
	var solo_left_x: Array[float] = []
	var solo_right_x: Array[float] = []
	for b in solo_buttons:
		var center_x: float = b.position.x + b.size.x * 0.5
		if center_x < 480.0:
			solo_left_x.append(center_x)
		else:
			solo_right_x.append(center_x)
	check(solo_left_x.size() == 3 and solo_right_x.size() == 3, "Movement and actions land on opposite halves for a lone touch player")
	solo.queue_free()
	await process_frame

	# Local 2P splits the screen: every P1 button stays left of center,
	# every P2 button stays right of it, so thumbs never collide.
	setup.vs_ai = false
	var duo := preload("res://scripts/touch_controls.gd").new()
	root.add_child(duo)
	await process_frame
	var duo_buttons: Array[Node] = duo.find_children("*", "Button", false, false)
	check(duo_buttons.size() == 12, "Local 2P gets 6 buttons per player")
	var all_left := true
	var all_right := true
	for i in duo_buttons.size():
		var center_x: float = duo_buttons[i].position.x + duo_buttons[i].size.x * 0.5
		if i < 6 and center_x >= 480.0:
			all_left = false
		if i >= 6 and center_x < 480.0:
			all_right = false
	check(all_left, "Every P1 touch button stays in the left half in local 2P")
	check(all_right, "Every P2 touch button stays in the right half in local 2P")

	# Pressing a button drives the real input action, exactly like a key —
	# P1's jump button is the 3rd built (see _build_player's call order).
	check(not Input.is_action_pressed("p1_jump"), "p1_jump starts unpressed")
	duo_buttons[2].button_down.emit()
	check(Input.is_action_pressed("p1_jump"), "Pressing the touch button presses the real action")
	duo_buttons[2].button_up.emit()
	check(not Input.is_action_pressed("p1_jump"), "Releasing the touch button releases the real action")
	duo.queue_free()
	await process_frame

	# Real integration: arena.gd should add touch controls itself when the
	# setting is on, and hide them while the move guide covers the same area.
	settings.touch_controls = true
	var arena: Node = load("res://scenes/Arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var live: Node = arena.find_children("*", "", false, false).filter(
		func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("touch_controls.gd")
	).front()
	check(live != null, "arena.gd adds touch controls itself when Settings.touch_controls is on")
	if live != null:
		check(live.visible, "Touch controls are visible while the move guide is closed")
		arena._toggle_move_guide()
		live._process(0.0)
		check(not live.visible, "Touch controls hide while the move guide covers the same area")
		arena._toggle_move_guide()
	settings.touch_controls = false

	print("TOUCH_CONTROLS_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
