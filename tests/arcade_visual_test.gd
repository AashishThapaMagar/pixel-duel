extends SceneTree
## Render the actual match sprites, including chroma key, at gameplay scale.
var fighters: Array[Node] = []
var elapsed := 0.0
var captured := 0
var label: Label

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	root.size = Vector2i(1400, 600)
	root.content_scale_size = Vector2i(1400, 600)
	var canvas := Node2D.new()
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("192733")
	background.size = Vector2(1400, 600)
	canvas.add_child(background)
	var floor_line := Line2D.new()
	floor_line.points = PackedVector2Array([Vector2(0, 400), Vector2(1400, 400)])
	floor_line.default_color = Color("718795")
	floor_line.width = 2
	canvas.add_child(floor_line)
	label = Label.new()
	label.position = Vector2(30, 455)
	label.add_theme_font_size_override("font_size", 24)
	canvas.add_child(label)
	for i in 7:
		var fighter: Node = load("res://scenes/Player.tscn").instantiate()
		canvas.add_child(fighter)
		fighter.set_physics_process(false)
		fighter.apply_character(i)
		fighter.apply_style(load("res://resources/styles/action.tres"))
		fighter.position = Vector2(100 + i * 200, 400)
		fighter.reset_for_new_round()
		fighter.scale = Vector2.ONE * 1.4
		fighters.append(fighter)
		var name_label := Label.new()
		name_label.text = fighter.character_profile.name
		name_label.position = Vector2(65 + i * 200, 130)
		canvas.add_child(name_label)

func _process(delta: float) -> bool:
	if fighters.is_empty():
		return false
	elapsed += delta
	var stage := mini(3, int(elapsed / 2.0))
	label.text = ["WALK / complete sprite poses", "RETREAT / facing opponent", "RUN / separate motion", "GUARD / immediate stop"][stage]
	for i in fighters.size():
		var fighter: Node = fighters[i]
		fighter.state = fighter.State.IDLE if stage == 3 else fighter.State.WALK
		fighter.running = stage == 2
		fighter.velocity.x = 0.0 if stage == 3 else (260.0 if stage == 2 else (-122.0 if stage == 1 else 169.0))
		fighter.position.x += fighter.velocity.x * delta
		fighter.combat_time += delta
		fighter._update_animation()
		# Keep columns readable while the real renderer samples actual travel.
		fighter.visual.position.x = (100 + i * 200 - fighter.position.x) / fighter.scale.x
	if "--capture" in OS.get_cmdline_user_args() and elapsed >= 0.25 + captured * 0.25:
		root.get_texture().get_image().save_png("res://.godot/arcade-preview-%02d.png" % captured)
		captured += 1
	if elapsed >= 8.0:
		quit()
	return false
