extends "res://scripts/fighter_visual.gd"
## Real lit meshes rendered into a transparent viewport. The existing combat
## plane and pose clock remain authoritative while character art moves to 3D.
var viewport_3d: SubViewport
var model: Node3D
var parts: Dictionary = {}
var materials: Dictionary = {}
var _profile_id: String = ""
var _outfit: String = "gi"
var _build: float = 1.0
var _hair_style: String = "swept"

func _ready() -> void:
	# Dedicated/headless simulations need poses and collision, not GPU meshes.
	# Rendering is exercised separately with a real graphics driver.
	if DisplayServer.get_name() == "headless":
		return
	viewport_3d = SubViewport.new()
	viewport_3d.size = Vector2i(320, 320)
	viewport_3d.transparent_bg = true
	viewport_3d.own_world_3d = true
	viewport_3d.msaa_3d = Viewport.MSAA_4X
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport_3d)
	model = Node3D.new()
	viewport_3d.add_child(model)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 176.0
	camera.position = Vector3(0, 0, 240)
	camera.far = 500.0
	viewport_3d.add_child(camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bdc9e5")
	environment.environment.ambient_light_energy = 0.45
	viewport_3d.add_child(environment)
	_light(Vector3(-30, -35, 0), Color("fff0da"), 1.15)
	_light(Vector3(-15, 140, 0), Color("83bdfc"), 0.8)
	var sprite := Sprite2D.new()
	sprite.texture = viewport_3d.get_texture()
	sprite.position = Vector2(0, -64)
	sprite.scale = Vector2.ONE * (176.0 / 320.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	for key in ["skin", "cloth", "dark", "accent", "hair", "wrap", "team"]:
		var material := StandardMaterial3D.new()
		material.roughness = 0.8
		materials[key] = material
	materials.dark.albedo_color = Color("1c2331")
	materials.wrap.albedo_color = Color("e6e2d8")
	_build_model()
	if fighter != null:
		_update_profile()
	_update_model()

func _light(angles: Vector3, color: Color, energy: float) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = angles
	light.light_color = color
	light.light_energy = energy
	viewport_3d.add_child(light)

func _mesh(key: String, mesh: Mesh, material: String) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = materials[material]
	model.add_child(part)
	parts[key] = part
	return part

func _sphere(key: String, size: Vector3, material: String) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	_mesh(key, mesh, material).scale = size

func _box(key: String, size: Vector3, material: String) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh(key, mesh, material)

func _bone(key: String, radius: float, material: String) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = 30.0
	mesh.radial_segments = 12
	mesh.rings = 4
	_mesh(key, mesh, material)

func _build_model() -> void:
	for side in ["rear", "lead"]:
		_bone(side + "_thigh", 7.6, "cloth")
		_bone(side + "_shin", 5.0, "cloth")
		_sphere(side + "_knee", Vector3(5.6, 5.8, 5.6), "cloth")
		_sphere(side + "_boot", Vector3(10, 4.8, 6.5), "dark")
		_box(side + "_sole", Vector3(18, 2, 12), "wrap")
		_bone(side + "_upper", 5.5, "skin")
		_bone(side + "_forearm", 4.4, "skin")
		_sphere(side + "_shoulder", Vector3(7, 7, 7), "skin")
		_sphere(side + "_elbow", Vector3(4.8, 4.8, 4.8), "skin")
		_sphere(side + "_hand", Vector3(6, 6.7, 6), "skin")
		_bone(side + "_wrap", 4.9, "wrap")
	var torso := CylinderMesh.new()
	torso.top_radius = 15.0
	torso.bottom_radius = 10.5
	torso.height = 33.0
	torso.radial_segments = 12
	_mesh("torso", torso, "cloth").scale.z = 0.62
	_sphere("hips", Vector3(13, 9, 8), "cloth")
	_bone("neck", 4.5, "skin")
	_sphere("head", Vector3(9.0, 11.5, 8.5), "skin")
	_sphere("jaw", Vector3(7.1, 6, 7.0), "skin")
	_sphere("ear", Vector3(2.2, 3.1, 2), "skin")
	_sphere("nose", Vector3(2.7, 2.4, 2.7), "skin")
	_sphere("hair", Vector3(9.7, 5.3, 9), "hair")
	_bone("braid", 3.0, "hair")
	_box("crest", Vector3(5, 8, 13), "hair")
	_box("headband", Vector3(18, 3.0, 16.6), "accent")
	_box("eye", Vector3(2.8, 1.3, 1), "dark")
	_box("brow", Vector3(4.0, 1.2, 1), "hair")
	_box("mouth", Vector3(3.5, 0.8, 1), "dark")
	_box("belt", Vector3(25, 4, 17), "dark")
	_box("belt_tail", Vector3(3, 16, 1.5), "accent")
	_box("lapel_a", Vector3(3, 31, 1.5), "wrap")
	_box("lapel_b", Vector3(3, 22, 1.5), "wrap")
	_box("chest_mark", Vector3(8, 4, 1.5), "accent")
	_box("player_mark", Vector3(4, 7, 1.5), "team")

func sync_pose(owner_fighter: Node) -> void:
	super.sync_pose(owner_fighter)
	if model != null:
		_update_profile()
		_update_model()

func _update_profile() -> void:
	var profile: Dictionary = fighter.character_profile
	if _profile_id == str(profile.id):
		return
	_profile_id = profile.id
	_outfit = profile.outfit
	_hair_style = profile.hair_style
	_build = profile.build
	materials.skin.albedo_color = profile.skin
	materials.cloth.albedo_color = profile.color
	materials.accent.albedo_color = profile.accent
	materials.hair.albedo_color = profile.hair
	materials.team.albedo_color = Color("58a9ff") if fighter.player_id == 1 else Color("ff6868")
	parts.braid.visible = _hair_style == "braid"
	parts.crest.visible = _hair_style == "crest"
	parts.headband.visible = _outfit in ["gi", "shorts"]
	parts.lapel_a.visible = _outfit == "gi"
	parts.lapel_b.visible = _outfit == "gi"
	parts.belt_tail.visible = _outfit == "gi"
	parts.chest_mark.visible = _outfit != "gi"
	for side in ["rear", "lead"]:
		parts[side + "_shin"].material_override = materials.skin if _outfit == "shorts" else materials.cloth
		parts[side + "_knee"].material_override = materials.skin if _outfit == "shorts" else materials.cloth
		parts[side + "_upper"].material_override = materials.cloth if _outfit == "suit" else materials.skin

func _process(delta: float) -> void:
	super._process(delta)
	if model != null and fighter != null:
		_update_model()

func _point(point: Vector2, depth: float = 0.0) -> Vector3:
	return Vector3(point.x, -point.y - 64.0, depth)

func _place_bone(key: String, a: Vector3, b: Vector3, thickness: float = 1.0) -> void:
	var part: MeshInstance3D = parts[key]
	var direction := b - a
	part.position = (a + b) * 0.5
	part.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))
	part.scale = Vector3(thickness, maxf(direction.length(), 0.1) / 30.0, thickness)

func _update_model() -> void:
	if pose.is_empty():
		return
	var hip := pose[0]
	var chest := pose[1]
	var head := pose[2]
	for i in 2:
		var side := "rear" if i == 0 else "lead"
		var depth := -6.0 if i == 0 else 7.0
		var leg_root := hip + Vector2(-6 if i == 0 else 6, 0)
		var ankle := leg_root + (pose[5 + i] - leg_root).limit_length(59.9)
		var knee := _joint(leg_root, ankle, 30.0, -1.0)
		_place_bone(side + "_thigh", _point(leg_root, depth), _point(knee, depth), _build)
		_place_bone(side + "_shin", _point(knee, depth), _point(ankle, depth), _build)
		parts[side + "_knee"].position = _point(knee, depth)
		parts[side + "_boot"].position = _point(ankle + Vector2(3, 1), depth)
		parts[side + "_sole"].position = _point(ankle + Vector2(3, 5), depth)
		var shoulder := chest + Vector2(-9 if i == 0 else 10, 0)
		if fighter != null and fighter.state == fighter.State.PUNCH and fighter.attack_variant in ["cross", "rear_hook", "uppercut", "overhand"]:
			# Turn the rear shoulder into the foreground for rear-hand strikes.
			depth = 9.0 if i == 0 else -5.0
		var hand := shoulder + (pose[3 + i] - shoulder).limit_length(49.9)
		var elbow := _joint(shoulder, hand, 25.0, 1.0)
		_place_bone(side + "_upper", _point(shoulder, depth), _point(elbow, depth), _build)
		_place_bone(side + "_forearm", _point(elbow, depth), _point(hand, depth), _build)
		_place_bone(side + "_wrap", _point(hand.lerp(elbow, 0.26), depth), _point(hand, depth), _build)
		parts[side + "_shoulder"].position = _point(shoulder, depth)
		parts[side + "_elbow"].position = _point(elbow, depth)
		parts[side + "_hand"].position = _point(hand, depth)
		var gloves: bool = fighter != null and fighter.current_style != null and fighter.current_style.kicks_disabled
		parts[side + "_hand"].scale = Vector3(7.5, 8.2, 7.2) if gloves else Vector3(5.8, 6.7, 5.8)
		parts[side + "_hand"].material_override = materials.cloth if gloves else materials.skin
	parts.torso.position = _point((chest + hip) * 0.5)
	parts.torso.rotation.z = -(chest - hip).angle() - PI * 0.5
	parts.torso.scale = Vector3(_build, 1.0, 0.62 * _build)
	parts.hips.position = _point(hip)
	_place_bone("neck", _point(chest + Vector2(0, -4)), _point(head + Vector2(-1, 5)))
	parts.head.position = _point(head)
	parts.jaw.position = _point(head + Vector2(1, 5), 1)
	parts.ear.position = _point(head + Vector2(-5, 1), 8)
	parts.nose.position = _point(head + Vector2(9, 1), 3.5)
	parts.hair.position = _point(head + Vector2(-1, -9))
	parts.hair.scale.y = 3.0 if _hair_style == "crop" else 5.3
	parts.crest.position = _point(head + Vector2(0, -14))
	_place_bone("braid", _point(head + Vector2(-7, -6), -4), _point(head + Vector2(-13, 20), -4))
	parts.headband.position = _point(head + Vector2(0, -5))
	parts.eye.position = _point(head + Vector2(5, -1), 7.7)
	parts.brow.position = _point(head + Vector2(5, -3), 7.8)
	parts.brow.rotation.z = -0.12
	parts.mouth.position = _point(head + Vector2(6, 6), 6.8)
	parts.belt.position = _point(hip + Vector2(0, -1))
	parts.belt_tail.position = _point(hip + Vector2(5, 8), 8.5)
	parts.belt_tail.rotation.z = 0.2
	parts.lapel_a.position = _point(chest + Vector2(-2, 11), 9.1)
	parts.lapel_a.rotation.z = -0.35
	parts.lapel_b.position = _point(chest + Vector2(2, 6), 9.2)
	parts.lapel_b.rotation.z = 0.45
	parts.chest_mark.position = _point(chest + Vector2(3, 10), 9.2)
	parts.player_mark.position = _point(chest + Vector2(-9, 9), 8.9)

func _draw() -> void:
	# The inherited 2D drawing is replaced by the viewport's 3D render.
	pass
