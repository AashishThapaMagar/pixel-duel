extends TextureRect
## Render the actual playable mesh, avoiding a portrait/model mismatch.
var fighter: Node
var camera: Camera3D
var index := 0
var facing_left := false
var closeup := false
## Tekken-style head-and-shoulders shot from three-quarters front.
var bust := false
## Where the bust camera looks; follows the animated fighter's head bone,
## since stances crouch or lean the head well away from a fixed height.
var bust_target := Vector3(0, 104, 0)
var bust_tracking := false
## Full-body showcase for the big select-screen frames: a wider render, the
## fighter larger and set off-centre toward the outside edge.
var hero := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 320) if not (closeup or bust) else Vector2i(200, 200)
	if hero:
		viewport.size = Vector2i(544, 336)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	texture = viewport.get_texture()
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6c6e6")
	environment.environment.ambient_light_energy = 0.65
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -30, 0)
	key.light_color = Color("ffe5ce")
	key.light_energy = 1.0
	world.add_child(key)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 62 if closeup else 145
	camera.far = 600
	world.add_child(camera)
	var height := 94.0 if closeup else 66.0
	# Mirrored for the right-hand preview so that fighter is seen from the front.
	camera.position = Vector3(-100 if facing_left else 100, height + 15, 230)
	camera.look_at(Vector3(0, height, 0))
	if hero:
		# Three-quarters front with headroom above the tallest stance; the
		# view slides so the fighter stands on the inner side of the frame.
		camera.size = 128
		camera.position = Vector3(-190 if facing_left else 190, 72, 160)
		camera.look_at(Vector3(0, 60, 0))
		camera.h_offset = -40.0 if facing_left else 40.0
	if bust:
		# Swing round to face the fighter, a little off-centre and just above
		# eye level, as on an arcade select screen.
		camera.size = 37
		var turn := deg_to_rad(30.0)
		var facing := -1.0 if facing_left else 1.0
		camera.position = Vector3(facing * cos(turn) * 230, 114, sin(turn) * 230)
		camera.look_at(Vector3(0, 104, 0))
		# Cool rim light from behind carves the face out of the background.
		var rim := DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-15, 150 if not facing_left else -150, 0)
		rim.light_color = Color("b9a4ff")
		rim.light_energy = 0.9
		world.add_child(rim)
	camera.current = true
	fighter = load("res://scenes/Player.tscn").instantiate()
	var previous: Node = fighter.get_node("Visual")
	fighter.remove_child(previous)
	previous.free()
	var visual := preload("res://scripts/fighter_visual_3d.gd").new()
	visual.name = "Visual"
	var rig := Node3D.new()
	rig.rotation.y = PI if facing_left else 0.0
	world.add_child(rig)
	visual.world_root = rig
	fighter.add_child(visual)
	fighter.set_physics_process(false)
	viewport.add_child(fighter)
	fighter.controls_enabled = false
	fighter.collision_layer = 0
	fighter.hurtbox.collision_layer = 0
	show_fighter(index)

func _process(_delta: float) -> void:
	if not bust or fighter == null or camera == null:
		return
	var animated = fighter.get_node("Visual").animated
	if not animated.active or animated.skeleton == null:
		return
	var head: int = animated.skeleton.find_bone("mixamorig_Head")
	if head < 0:
		return
	var at: Vector3 = animated.skeleton.global_transform * animated.skeleton.get_bone_global_pose(head).origin
	# Frame the face slightly above centre, with the shoulders below.
	var goal := at + Vector3(0, -5, 0)
	bust_target = goal if not bust_tracking else bust_target.lerp(goal, 0.15)
	bust_tracking = true
	var turn := deg_to_rad(30.0)
	var facing := -1.0 if facing_left else 1.0
	camera.position = bust_target + Vector3(facing * cos(turn) * 230, 10, sin(turn) * 230)
	camera.look_at(bust_target)

func show_fighter(value: int) -> void:
	bust_tracking = false
	index = value
	if fighter != null:
		fighter.apply_character(value)
		fighter.apply_style(load("res://resources/styles/action.tres"))
		fighter._update_animation()
		if bust:
			_clear_guard()

## Busts frame head and shoulders; the raised guard would cover the chin.
func _clear_guard() -> void:
	var visual: Node = fighter.get_node("Visual")
	if visual.parts.is_empty():
		return
	for side in ["rear", "lead"]:
		for part in ["_forearm", "_hand", "_wrap", "_elbow"]:
			visual.parts[side + part].visible = false
