extends TextureRect
## Render the actual playable mesh, avoiding a portrait/model mismatch.
var fighter: Node
var camera: Camera3D
var index := 0
var facing_left := false
var closeup := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 320) if not closeup else Vector2i(144, 144)
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
	camera.position = Vector3(100, height + 15, 230)
	camera.look_at(Vector3(0, height, 0))
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

func show_fighter(value: int) -> void:
	index = value
	if fighter != null:
		fighter.apply_character(value)
		fighter.apply_style(load("res://resources/styles/action.tres"))
		fighter._update_animation()
