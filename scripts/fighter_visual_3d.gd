extends "res://scripts/fighter_visual.gd"
## Real lit meshes rendered into a transparent viewport. The existing combat
## plane and pose clock remain authoritative while character art moves to 3D.
# Set by a caller that already owns a shared Node3D/viewport/camera (e.g. to
# put both fighters in one lit scene). Left null, this node builds its own
# private viewport/camera/lights instead, unchanged from the original setup.
var world_root: Node3D
var viewport_3d: SubViewport
var model: Node3D
var parts: Dictionary = {}
var materials: Dictionary = {}
var _profile_id: String = ""
var _outfit: String = "gi"
var _build: float = 1.0
var _hair_style: String = "swept"
var _signature: String = ""
var _turn_rotation: float = 0.0
var _turn_initialized: bool = false

func _ready() -> void:
	# Dedicated/headless simulations need poses and collision, not GPU meshes.
	# Rendering is exercised separately with a real graphics driver.
	if DisplayServer.get_name() == "headless" and world_root == null:
		return
	if world_root != null:
		model = Node3D.new()
		world_root.add_child(model)
	else:
		viewport_3d = SubViewport.new()
		viewport_3d.size = Vector2i(320, 320)
		viewport_3d.transparent_bg = true
		viewport_3d.own_world_3d = true
		viewport_3d.msaa_3d = Viewport.MSAA_4X
		viewport_3d.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		add_child(viewport_3d)
		model = Node3D.new()
		viewport_3d.add_child(model)
		# A fixed 3/4, slightly elevated angle (still orthogonal, so scale stays
		# constant regardless of depth) reads as real 3D instead of a flat front
		# elevation. Facing is turned by rotating the model (see sync_pose/
		# _process), so this same camera covers both directions correctly.
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 176.0
		var cam_angle := deg_to_rad(17.0)
		var cam_height := 20.0
		camera.position = Vector3(sin(cam_angle) * 240.0, cam_height, cos(cam_angle) * 240.0)
		camera.far = 500.0
		viewport_3d.add_child(camera)
		camera.look_at(Vector3(0, cam_height * 0.35, 0), Vector3.UP)
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
	for key in ["skin", "cloth", "dark", "accent", "hair", "wrap", "team", "mouth", "eye_white"]:
		var surface_material := StandardMaterial3D.new()
		surface_material.roughness = 0.92
		# A cheap rim light along every edge gives the low-poly rig a lit,
		# "real 3D game" silhouette instead of looking like a flat cutout.
		surface_material.rim_enabled = false
		surface_material.rim = 0.32
		surface_material.rim_tint = 0.45
		materials[key] = surface_material
	materials.dark.albedo_color = Color("1c2331")
	materials.wrap.albedo_color = Color("e6e2d8")
	materials.eye_white.albedo_color = Color("f2ede4")
	materials.eye_white.rim_enabled = false
	# Skin reads as a glossy, rim-glowing "action figure" at this roughness;
	# knocking the shine down and quieting its rim is what separates a face
	# from a plastic mannequin head. Hair keeps a touch more shine (healthier
	# look); everything else keeps the punchier stylized default above.
	materials.skin.roughness = 0.85
	materials.skin.rim = 0.14
	materials.skin.rim_tint = 0.25
	materials.hair.roughness = 0.9
	# Mouths tinted from the character's own skin (see _update_profile) read
	# as a closed, human mouth line; a flat black bar reads as a gash.
	materials.mouth.roughness = 0.75
	materials.mouth.rim_enabled = false
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

func _mesh(key: String, mesh: Mesh, surface_material: String) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = materials[surface_material]
	model.add_child(part)
	parts[key] = part
	return part

func _sphere(key: String, size: Vector3, surface_material: String) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 22
	mesh.rings = 11
	_mesh(key, mesh, surface_material).scale = size

func _box(key: String, size: Vector3, surface_material: String) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh(key, mesh, surface_material)

func _bone(key: String, radius: float, surface_material: String) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.82
	mesh.bottom_radius = radius
	mesh.height = 30.0
	mesh.radial_segments = 10
	_mesh(key, mesh, surface_material)

func _build_model() -> void:
	for side in ["rear", "lead"]:
		_bone(side + "_thigh", 7.6, "cloth")
		_bone(side + "_shin", 5.0, "cloth")
		_sphere(side + "_knee", Vector3(5.6, 5.8, 5.6), "cloth")
		_sphere(side + "_boot", Vector3(10, 4.8, 6.5), "dark")
		_box(side + "_sole", Vector3(18, 2, 12), "wrap")
		_bone(side + "_upper", 5.5, "skin")
		_bone(side + "_forearm", 4.4, "skin")
		_sphere(side + "_shoulder", Vector3(5.8, 5.8, 5.8), "skin")
		_sphere(side + "_elbow", Vector3(4.8, 4.8, 4.8), "skin")
		_sphere(side + "_hand", Vector3(6, 6.7, 6), "skin")
		_bone(side + "_wrap", 4.9, "wrap")
		_box(side + "_anklet", Vector3(11, 2.6, 8), "accent")
	var torso := CylinderMesh.new()
	torso.top_radius = 15.0
	torso.bottom_radius = 10.5
	torso.height = 33.0
	torso.radial_segments = 12
	_mesh("torso", torso, "cloth").scale.z = 0.62
	_sphere("hips", Vector3(13, 9, 8), "cloth")
	_bone("neck", 4.5, "skin")
	# Rounder and a touch shorter than before: the previous head/jaw pairing
	# (tall egg-shaped skull + narrow chin) read as an alien mannequin more
	# than a stylized human. A fuller jaw under a rounder skull is a more
	# forgiving base for a face to sit on.
	_sphere("head", Vector3(9.0, 10.7, 8.7), "skin")
	_sphere("jaw", Vector3(7.4, 6.6, 7.3), "skin")
	_sphere("ear", Vector3(2.2, 3.1, 2), "skin")
	_sphere("nose", Vector3(2.7, 2.4, 2.7), "skin")
	# More coverage (was leaving a lot of bare, shiny scalp exposed) and
	# hangs a bit lower over the forehead.
	_sphere("hair", Vector3(9.2, 5.0, 8.8), "hair")
	_bone("braid", 3.0, "hair")
	_box("crest", Vector3(5, 8, 13), "hair")
	_box("headband", Vector3(18, 3.0, 16.6), "accent")
	# A pale sclera sitting just behind the pupil is what reads as an eye
	# instead of a flat dark slit; see _update_model for how they're paired.
	_sphere("eye_white", Vector3(2.4, 1.1, 0.35), "eye_white")
	_box("eye", Vector3(1.4, 1.4, 0.8), "dark")
	_box("brow", Vector3(4.6, 1.5, 1), "hair")
	# Tinted from the fighter's own skin in _update_profile, not flat black —
	# a solid black bar reads as a gash rather than a closed mouth.
	_box("mouth", Vector3(3.6, 1.0, 1), "mouth")
	_box("belt", Vector3(25, 4, 17), "dark")
	_box("belt_tail", Vector3(3, 16, 1.5), "accent")
	_box("lapel_a", Vector3(3, 31, 1.5), "wrap")
	_box("lapel_b", Vector3(3, 22, 1.5), "wrap")
	_box("chest_mark", Vector3(8, 4, 1.5), "accent")
	_box("player_mark", Vector3(4, 7, 1.5), "team")
	# One-off signature accessories (see fighter_roster.gd PROFILES.signature)
	# that keep fighters sharing an outfit archetype visually distinct.
	_box("shades", Vector3(15, 3.4, 2.2), "dark")
	# Wider than the torso so its edges peek out past the shoulders instead
	# of hiding fully behind the body from the 3/4 camera angle.
	_box("cape", Vector3(40, 54, 1.8), "cloth")
	# A free camera can see either side of the fighter's head and uniform.
	for key in ["eye_white", "eye", "brow", "mouth", "ear", "lapel_a", "lapel_b", "chest_mark", "player_mark", "shades"]:
		var far_part: MeshInstance3D = parts[key].duplicate()
		model.add_child(far_part)
		parts[key + "_far"] = far_part

func sync_pose(owner_fighter: Node) -> void:
	super.sync_pose(owner_fighter)
	if model == null:
		return
	# The base class mirrors facing with a 2D horizontal flip of the whole
	# node; that would mirror our baked 3D render into physically wrong
	# lighting. Undo it here and turn the actual model in _process instead,
	# so the correct side of the character catches the lights either way.
	scale.x = 1.0
	var target_turn := 0.0 if fighter.facing >= 0 else PI
	if not _turn_initialized:
		_turn_rotation = target_turn
		_turn_initialized = true
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
	_signature = profile.get("signature", "")
	materials.skin.albedo_color = profile.skin
	materials.cloth.albedo_color = profile.color.darkened(0.16)
	materials.accent.albedo_color = profile.accent.darkened(0.12)
	materials.hair.albedo_color = profile.hair
	materials.mouth.albedo_color = profile.skin.darkened(0.45)
	materials.team.albedo_color = Color("58a9ff") if fighter.player_id == 1 else Color("ff6868")
	parts.braid.visible = _hair_style == "braid"
	parts.crest.visible = _hair_style == "crest"
	parts.headband.visible = _outfit in ["gi", "shorts"] or _signature == "headband"
	parts.lapel_a.visible = _outfit == "gi"
	parts.lapel_b.visible = _outfit == "gi"
	parts.belt_tail.visible = _outfit == "gi"
	parts.chest_mark.visible = _outfit != "gi"
	parts.shades.visible = _signature == "shades"
	parts.cape.visible = _signature == "cape"
	for side in ["rear", "lead"]:
		parts[side + "_shoulder"].material_override = materials.cloth if _outfit in ["suit", "keeper", "gi"] else materials.skin
		parts[side + "_shin"].material_override = materials.skin if _outfit == "shorts" else materials.cloth
		parts[side + "_knee"].material_override = materials.skin if _outfit == "shorts" else materials.cloth
		parts[side + "_upper"].material_override = materials.cloth if _outfit in ["suit", "keeper"] else materials.skin
		parts[side + "_forearm"].material_override = materials.cloth if _outfit == "keeper" else materials.skin
		parts[side + "_anklet"].visible = _signature == "anklets"

func _process(delta: float) -> void:
	super._process(delta)
	if model == null or fighter == null or fighter.combat_paused or fighter.hitstop_remaining > 0.0:
		return
	scale.x = 1.0
	var target_turn := 0.0 if fighter.facing >= 0 else PI
	_turn_rotation = lerp_angle(_turn_rotation, target_turn, 1.0 - exp(-16.0 * delta))
	model.rotation.y = _turn_rotation if world_root == null else 0.0
	if world_root != null:
		# In a shared world the model sits flat in that scene's own facing
		# convention (turning is handled by the caller); this node's 2D
		# `rotation` (hit reactions, etc.) is carried over as a Z-spin instead.
		model.rotation.z = -rotation
	_update_model()

func _point(point: Vector2, depth: float = 0.0) -> Vector3:
	return Vector3(point.x, -point.y - (64.0 if world_root == null else 0.0), depth)

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
	var head: Vector2 = chest + (pose[2] - chest) * 0.84
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
		parts[side + "_anklet"].position = _point(ankle + Vector2(3, -6), depth)
		var shoulder := chest + Vector2(-9 if i == 0 else 10, 0)
		if fighter != null and fighter.state == fighter.State.PUNCH and fighter.attack_variant in ["cross", "rear_hook", "uppercut", "overhand"]:
			# Turn the rear shoulder into the foreground for rear-hand strikes.
			depth = 9.0 if i == 0 else -5.0
		var hand := shoulder + (pose[3 + i] - shoulder).limit_length(49.9)
		var elbow := _joint(shoulder, hand, 25.0, -1.0 if hand.x < shoulder.x else 1.0)
		_place_bone(side + "_upper", _point(shoulder, depth), _point(elbow, depth), _build)
		_place_bone(side + "_forearm", _point(elbow, depth), _point(hand, depth), _build)
		_place_bone(side + "_wrap", _point(hand.lerp(elbow, 0.26), depth), _point(hand, depth), _build * (1.55 if _signature == "wraps" else 1.0))
		parts[side + "_shoulder"].position = _point(shoulder, depth)
		parts[side + "_elbow"].position = _point(elbow, depth)
		parts[side + "_hand"].position = _point(hand, depth)
		var gloves: bool = _outfit == "keeper" or (fighter != null and fighter.current_style != null and fighter.current_style.kicks_disabled)
		parts[side + "_hand"].scale = Vector3(6.0, 6.7, 5.5) if gloves else Vector3(4.8, 5.6, 4.5)
		parts[side + "_hand"].material_override = materials.accent if gloves else materials.skin
	parts.torso.position = _point((chest + hip) * 0.5)
	parts.torso.rotation.z = -(chest - hip).angle() - PI * 0.5
	parts.torso.scale = Vector3(_build, 1.0, 0.62 * _build)
	parts.hips.position = _point(hip)
	_place_bone("neck", _point(chest + Vector2(0, -4)), _point(head + Vector2(-1, 5)))
	parts.head.position = _point(head)
	parts.jaw.position = _point(head + Vector2(1, 5), 1)
	parts.ear.position = _point(head + Vector2(-5, 1), 8)
	parts.nose.position = _point(head + Vector2(9, 1), 0)
	parts.hair.position = _point(head + Vector2(-1, -9))
	parts.hair.scale.y = 3.0 if _hair_style == "crop" else 5.3
	parts.crest.position = _point(head + Vector2(0, -14))
	_place_bone("braid", _point(head + Vector2(-7, -6), -4), _point(head + Vector2(-13, 20), -4))
	parts.headband.position = _point(head + Vector2(0, -5))
	parts.eye_white.position = _point(head + Vector2(5, -1), 7.3)
	parts.eye.position = _point(head + Vector2(5, -1), 7.9)
	parts.brow.position = _point(head + Vector2(5, -3), 8.0)
	parts.brow.rotation.z = -0.12
	parts.mouth.position = _point(head + Vector2(6, 6), 8.0)
	parts.shades.position = _point(head + Vector2(5, -2), 8.2)
	# Head details follow the neck during dives and inverted cartwheel poses.
	var head_angle := -(head - chest).angle() - PI * 0.5
	var pivot := _point(head)
	var head_basis := Basis(Vector3.BACK, head_angle)
	for key in ["head", "jaw", "ear", "nose", "hair", "crest", "headband", "eye_white", "eye", "brow", "mouth", "shades"]:
		parts[key].position = pivot + head_basis * (parts[key].position - pivot)
		parts[key].rotation.z = head_angle + (-0.12 if key == "brow" else 0.0)
	parts.belt.position = _point(hip + Vector2(0, -1))
	parts.belt_tail.position = _point(hip + Vector2(5, 8), 8.5)
	parts.belt_tail.rotation.z = 0.2
	parts.lapel_a.position = _point(chest + Vector2(-2, 11), 9.1)
	parts.lapel_a.rotation.z = -0.35
	parts.lapel_b.position = _point(chest + Vector2(2, 6), 9.2)
	parts.lapel_b.rotation.z = 0.45
	parts.chest_mark.position = _point(chest + Vector2(3, 10), 9.2)
	parts.player_mark.position = _point(chest + Vector2(-9, 9), 8.9)
	parts.cape.position = _point((chest + hip) * 0.5 + Vector2(0, -4), -9.0)
	parts.cape.rotation.z = parts.torso.rotation.z
	parts.cape.scale = Vector3(_build, 1.0, 1.0)
	for key in ["eye_white", "eye", "brow", "mouth", "ear", "lapel_a", "lapel_b", "chest_mark", "player_mark", "shades"]:
		var near_part: MeshInstance3D = parts[key]
		var far_part: MeshInstance3D = parts[key + "_far"]
		far_part.transform = near_part.transform
		far_part.position.z = -near_part.position.z
		far_part.visible = near_part.visible

func _draw() -> void:
	# The inherited 2D drawing is replaced by the viewport's 3D render.
	pass
