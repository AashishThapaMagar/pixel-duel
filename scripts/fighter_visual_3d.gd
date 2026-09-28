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
var likeness := preload("res://scripts/fighter_likeness.gd").new()
## Skinned, animated model used instead of the procedural rig for fighters
## that have one (see fighter_models.gd).
var animated := preload("res://scripts/fighter_animated.gd").new()

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
	for key in ["skin", "cloth", "pants", "dark", "accent", "hair", "wrap", "team", "mouth", "eye_white", "shoe", "sole", "under"]:
		var surface_material := StandardMaterial3D.new()
		surface_material.roughness = 0.92
		# A soft rim along every edge lifts the silhouette off dark
		# architecture the way stage back-light does, without the glossy
		# "action figure" look a strong rim gives.
		surface_material.rim_enabled = true
		surface_material.rim = 0.16
		surface_material.rim_tint = 0.6
		surface_material.metallic_specular = 0.22
		materials[key] = surface_material
	materials.dark.albedo_color = Color("1c2331")
	materials.wrap.albedo_color = Color("e6e2d8")
	materials.eye_white.albedo_color = Color("f2ede4")
	materials.sole.albedo_color = Color("ece7dc")
	materials.eye_white.rim_enabled = false
	# Cloth: a fine woven grain in the normal map and a matte finish. The
	# grain is generated once (no texture files) and laid on in object
	# space, so it follows every limb whichever way the rig bends.
	for key in ["cloth", "pants", "accent", "wrap", "under", "team"]:
		materials[key].normal_enabled = true
		materials[key].normal_texture = _weave()
		materials[key].normal_scale = 0.28
		materials[key].uv1_triplanar = true
		materials[key].uv1_scale = Vector3.ONE * 0.14
		materials[key].roughness = 0.9
	# Skin: matte, with just enough specular to catch the key light on the
	# brow, shoulders and knuckles; a quiet rim keeps a face from reading as
	# a plastic mannequin head. Hair and leather shoes keep a touch of sheen.
	materials.skin.roughness = 0.78
	materials.skin.metallic_specular = 0.3
	materials.skin.rim = 0.1
	materials.skin.rim_tint = 0.4
	materials.hair.roughness = 0.72
	materials.hair.metallic_specular = 0.45
	materials.shoe.roughness = 0.55
	materials.shoe.metallic_specular = 0.5
	materials.dark.roughness = 0.6
	materials.dark.metallic_specular = 0.4
	# Mouths tinted from the character's own skin (see _update_profile) read
	# as a closed, human mouth line; a flat black bar reads as a gash.
	materials.mouth.roughness = 0.75
	materials.mouth.rim_enabled = false
	_build_model()
	if fighter != null:
		_update_profile()
	_update_model()

## One shared woven-cloth normal map for every fighter, built from noise
## the first time it is needed.
static var weave_texture: Texture2D
static func _weave() -> Texture2D:
	if weave_texture == null:
		var noise := FastNoiseLite.new()
		noise.seed = 7
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		noise.frequency = 0.3
		noise.fractal_octaves = 2
		var texture := NoiseTexture2D.new()
		texture.width = 128
		texture.height = 128
		texture.seamless = true
		texture.as_normal_map = true
		texture.bump_strength = 4.0
		texture.noise = noise
		weave_texture = texture
	return weave_texture

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
	mesh.radial_segments = 32
	mesh.rings = 16
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
	mesh.radial_segments = 18
	_mesh(key, mesh, surface_material)

func _build_model() -> void:
	for side in ["rear", "lead"]:
		_bone(side + "_thigh", 8.4, "cloth")
		_bone(side + "_shin", 5.8, "cloth")
		_sphere(side + "_knee", Vector3(6.6, 6.8, 6.6), "cloth")
		# Baggy martial trousers balloon over the shin and gather at the boot.
		_sphere(side + "_calf", Vector3.ONE, "pants")
		_sphere(side + "_boot", Vector3(12, 6.4, 8), "shoe")
		_box(side + "_sole", Vector3(21, 2.8, 13), "sole")
		_bone(side + "_upper", 6.4, "skin")
		_bone(side + "_forearm", 5.3, "skin")
		_sphere(side + "_shoulder", Vector3(7.8, 7.4, 7.8), "skin")
		_sphere(side + "_elbow", Vector3(5.4, 5.4, 5.4), "skin")
		_sphere(side + "_hand", Vector3(6, 6.7, 6), "skin")
		_bone(side + "_wrap", 5.8, "wrap")
		_box(side + "_anklet", Vector3(11, 2.6, 8), "accent")
		_sphere(side + "_bicep", Vector3.ONE, "skin")
		_sphere(side + "_trouser", Vector3.ONE, "pants")
		_box(side + "_boot_trim", Vector3(16, 1.6, 13.4), "accent")
		_sphere(side + "_kneepad", Vector3(6.2, 6.2, 1.9), "dark")
	var torso := CylinderMesh.new()
	torso.top_radius = 17.0
	torso.bottom_radius = 11.5
	torso.height = 33.0
	torso.radial_segments = 24
	_mesh("torso", torso, "cloth").scale.z = 0.62
	_sphere("hips", Vector3(13, 9, 10), "cloth")
	# Pecs and traps give the broad, heroic arcade-fighter upper body.
	_sphere("chest_bulk", Vector3.ONE, "cloth")
	_sphere("traps", Vector3.ONE, "skin")
	_bone("neck", 5.6, "skin")
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
	materials.pants.albedo_color = Color("292932") if profile.id in ["abhi", "sup", "anant"] else profile.color.darkened(0.24)
	materials.accent.albedo_color = profile.accent.darkened(0.12)
	materials.hair.albedo_color = profile.hair
	materials.mouth.albedo_color = profile.skin.darkened(0.45)
	materials.team.albedo_color = Color("58a9ff") if fighter.player_id == 1 else Color("ff6868")
	materials.wrap.albedo_color = profile.get("wrap", Color("d6cdb8"))
	materials.shoe.albedo_color = profile.get("shoe", Color("2a2531"))
	materials.under.albedo_color = profile.get("under", Color("1d1c22"))
	parts.torso.material_override = materials.cloth
	parts.chest_bulk.material_override = materials.cloth
	parts.traps.material_override = materials.cloth if _outfit in ["suit", "gi"] else materials.skin
	parts.head.scale = Vector3(9.8, 10.7, 9.2) if profile.id == "sab" else Vector3(9.0, 10.7, 8.7)
	parts.jaw.scale = Vector3(8.2, 6.6, 8.0) if profile.id == "sab" else Vector3(7.4, 6.6, 7.3)
	parts.braid.visible = _hair_style == "braid"
	parts.crest.visible = _hair_style == "crest"
	parts.headband.visible = false
	parts.lapel_a.visible = false
	parts.lapel_b.visible = false
	parts.belt_tail.visible = false
	parts.chest_mark.visible = false
	parts.shades.visible = false
	parts.cape.visible = false
	for side in ["rear", "lead"]:
		parts[side + "_thigh"].material_override = materials.pants
		parts[side + "_bicep"].material_override = materials.cloth if _outfit in ["suit", "keeper", "gi"] else materials.skin
		parts[side + "_kneepad"].visible = profile.id == "ish"
		parts[side + "_shoulder"].material_override = materials.cloth if _outfit in ["suit", "keeper", "gi"] else materials.skin
		parts[side + "_shin"].material_override = materials.pants
		parts[side + "_knee"].material_override = materials.pants
		parts[side + "_upper"].material_override = materials.cloth if _outfit in ["suit", "keeper", "gi"] else materials.skin
		parts[side + "_forearm"].material_override = materials.cloth if _outfit in ["suit", "gi"] else materials.skin
		parts[side + "_anklet"].visible = _signature == "anklets"
	likeness.configure(self, profile)
	animated.configure(self, profile)

func _process(delta: float) -> void:
	super._process(delta)
	if model == null or fighter == null or fighter.combat_paused or fighter.hitstop_remaining > 0.0:
		# Hit-stop: the pose freezes on the frame of contact while the
		# struck fighter shudders in place, which is what sells the weight
		# of the blow. Longer freezes (kicks) shudder harder.
		if model != null and fighter != null and fighter.hitstop_remaining > 0.0 and fighter.state in [fighter.State.HITSTUN, fighter.State.BLOCKSTUN, fighter.State.KO]:
			var amplitude: float = 0.6 + 14.0 * fighter.hitstop_remaining
			model.position.x = sin(Time.get_ticks_msec() * 0.095) * amplitude
		# Still called so the animated model freezes with the fight.
		animated.update(delta)
		return
	model.position.x = move_toward(model.position.x, 0.0, delta * 120.0)
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
	animated.update(delta)

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
		var thigh: MeshInstance3D = parts[side + "_thigh"]
		parts[side + "_trouser"].transform = thigh.transform
		parts[side + "_trouser"].scale = Vector3(9.4 * _build, 17.0, 9.0 * _build)
		parts[side + "_calf"].transform = parts[side + "_shin"].transform
		parts[side + "_calf"].position = _point(knee.lerp(ankle, 0.55), depth)
		parts[side + "_calf"].scale = Vector3(7.6 * _build, 14.0, 7.6 * _build)
		parts[side + "_knee"].position = _point(knee, depth)
		parts[side + "_boot"].position = _point(ankle + Vector2(3, 1), depth)
		parts[side + "_sole"].position = _point(ankle + Vector2(3, 5), depth)
		parts[side + "_boot_trim"].position = _point(ankle + Vector2(3, 3), depth)
		parts[side + "_kneepad"].position = _point(knee, depth + (5.0 if i == 1 else -5.0))
		parts[side + "_anklet"].position = _point(ankle + Vector2(3, -6), depth)
		var shoulder := chest + Vector2(-9 if i == 0 else 10, 0)
		if fighter != null and fighter.state == fighter.State.PUNCH and fighter.attack_variant in ["cross", "rear_hook", "uppercut", "overhand"]:
			# Turn the rear shoulder into the foreground for rear-hand strikes.
			depth = 9.0 if i == 0 else -5.0
		var hand := shoulder + (pose[3 + i] - shoulder).limit_length(49.9)
		var elbow := _joint(shoulder, hand, 25.0, -1.0 if hand.x < shoulder.x else 1.0)
		_place_bone(side + "_upper", _point(shoulder, depth), _point(elbow, depth), _build)
		parts[side + "_bicep"].transform = parts[side + "_upper"].transform
		parts[side + "_bicep"].scale = Vector3(7.4 * _build, 12.0, 7.0 * _build)
		_place_bone(side + "_forearm", _point(elbow, depth), _point(hand, depth), _build)
		_place_bone(side + "_wrap", _point(hand.lerp(elbow, 0.26), depth), _point(hand, depth), _build * (1.55 if _signature == "wraps" else 1.0))
		parts[side + "_shoulder"].position = _point(shoulder, depth)
		parts[side + "_elbow"].position = _point(elbow, depth)
		parts[side + "_hand"].position = _point(hand, depth)
		# Every fighter wears open-finger combat gloves, as on the concept sheet.
		parts[side + "_hand"].scale = Vector3(6.4, 6.8, 6.0) * clampf(_build, 0.95, 1.12)
		parts[side + "_hand"].material_override = materials.dark
	parts.torso.position = _point((chest + hip) * 0.5)
	parts.torso.rotation.z = -(chest - hip).angle() - PI * 0.5
	parts.torso.scale = Vector3(_build, 1.0, 0.8 * _build)
	parts.chest_bulk.position = _point(chest + (hip - chest) * 0.22)
	parts.chest_bulk.rotation.z = parts.torso.rotation.z
	parts.chest_bulk.scale = Vector3(15.5 * _build, 11.0, 13.2 * _build)
	parts.traps.position = _point(chest + Vector2(-2, -3))
	parts.traps.rotation.z = parts.torso.rotation.z
	parts.traps.scale = Vector3(10.0 * _build, 5.5, 12.0 * _build)
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
	likeness.update()

func _draw() -> void:
	# The inherited 2D drawing is replaced by the viewport's 3D render.
	pass
