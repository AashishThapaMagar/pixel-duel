extends Node3D
## Detailed image scenery with a world-space stone floor and real fighter shadows.
const ART_ROOT := "res://assets/backgrounds/nepal_illustrated/"
const ROUNDS := [
	{"name": "HERITAGE COURTYARD", "night": false, "detail": "DAY / Weathered brick, carved timber and a mountain pagoda", "image": "../nepal_retro/courtyard-day.png"},
	{"name": "LANTERN COURTYARD", "night": true, "detail": "NIGHT / Brick temples, carved windows and warm lanterns", "image": "courtyard-night.png"},
	{"name": "TERRACE VALLEY", "night": false, "detail": "DAY / Green terraces, village homes and rhododendrons", "image": "terrace-day.png"},
	{"name": "MOONLIT HERITAGE", "night": true, "detail": "FINAL NIGHT / A hilltop stupa beneath the Himalayas", "image": "heritage-night.png"}
]
static var textures: Dictionary = {}
var content: Node3D
var environment: WorldEnvironment
var sun: DirectionalLight3D
var current_round := -1
var night := false
var elapsed := 0.0
var backdrop: MeshInstance3D
var backdrop_material: ShaderMaterial
var floor_material: ShaderMaterial

func _ready() -> void:
	environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)

func _texture(filename: String) -> Texture2D:
	if not textures.has(filename):
		# Use imported resources in exported builds; raw PNGs support first launch
		# from a checkout before the editor has imported the new artwork.
		if ResourceLoader.exists(ART_ROOT + filename, "Texture2D"):
			textures[filename] = load(ART_ROOT + filename)
			return textures[filename]
		# Runtime loading also works before the editor's first asset import.
		var pixels := Image.load_from_file(ART_ROOT + filename)
		if pixels == null or pixels.is_empty():
			push_error("Missing Nepal stage image: " + filename)
			return null
		pixels.generate_mipmaps()
		textures[filename] = ImageTexture.create_from_image(pixels)
	return textures[filename]

func show_round(index: int) -> void:
	index = clampi(index, 0, ROUNDS.size() - 1)
	if index == current_round:
		return
	current_round = index
	night = ROUNDS[index].night
	if content != null:
		remove_child(content)
		content.queue_free()
	content = Node3D.new()
	content.name = "HeritageScenery"
	add_child(content)
	elapsed = 0
	_lighting()
	_backdrop()
	_floor()
	if night:
		# Off-screen warm fill matches the lamps in the illustrated scenery.
		for side in [-1, 1]:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(side * 6.5, 2.2, -0.5)
			lamp.light_color = Color("ffc68a")
			lamp.light_energy = 0.7
			lamp.omni_range = 9
			content.add_child(lamp)

func animate(delta: float) -> void:
	elapsed += delta

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or backdrop == null:
		return
	var size := get_viewport().get_visible_rect().size
	# A real camera-facing quad avoids renderer/version-specific clip depth.
	# Keep it behind combat and fit it to the camera's actual projection.
	var distance := 50.0
	var top_left := camera.project_position(Vector2.ZERO, distance)
	var top_right := camera.project_position(Vector2(size.x, 0), distance)
	var bottom_left := camera.project_position(Vector2(0, size.y), distance)
	backdrop.global_transform = Transform3D(camera.global_basis, camera.global_position - camera.global_basis.z * distance)
	backdrop.scale = Vector3(top_left.distance_to(top_right) / 2.0, top_left.distance_to(bottom_left) / 2.0, 1)
	backdrop_material.set_shader_parameter("view_aspect", size.x / maxf(size.y, 1))
	# Fixed scenery framing keeps the painted horizon steady during footwork.
	backdrop_material.set_shader_parameter("pan", Vector2(0, 0.10 if current_round == 0 else 0.0))

func _lighting() -> void:
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101b2b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("a7b7d3") if night else Color("d9e2eb")
	environment.environment.ambient_light_energy = 0.48 if night else 0.38
	sun.rotation_degrees = Vector3(-38, -28, 0)
	sun.light_color = Color("b5c7e8") if night else Color("ffe4c4")
	sun.light_energy = 0.36 if night else 0.72
	if current_round == 0:
		environment.environment.ambient_light_color = Color("c5c8ce")
		environment.environment.ambient_light_energy = 0.48
		sun.light_color = Color("f3eee5")
		sun.light_energy = 0.55

func _backdrop() -> void:
	backdrop = MeshInstance3D.new()
	backdrop.name = "IllustratedScenery"
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	backdrop.mesh = quad
	backdrop.extra_cull_margin = 100
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D scenery : source_color, filter_linear_mipmap;
uniform float image_aspect = 1.777;
uniform float view_aspect = 1.777;
uniform vec2 pan = vec2(0.0);
void fragment() {
 vec2 uv = UV - vec2(0.5);
 if (view_aspect > image_aspect) { uv.y *= image_aspect / view_aspect; }
 else { uv.x *= view_aspect / image_aspect; }
 // Bound the crop before sampling: never stretch an edge texel into a band.
 vec2 span = vec2(abs(pan.y) > 0.05 ? 0.78 : 0.94);
 uv *= span;
 vec2 safe_pan = clamp(pan, -(vec2(1.0) - span) * 0.5, (vec2(1.0) - span) * 0.5);
 uv += vec2(0.5) + safe_pan;
 ALBEDO = texture(scenery, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
}"""
	backdrop_material = ShaderMaterial.new()
	backdrop_material.shader = shader
	var picture := _texture(ROUNDS[current_round].image)
	if picture == null:
		return
	backdrop_material.set_shader_parameter("scenery", picture)
	backdrop_material.set_shader_parameter("image_aspect", float(picture.get_width()) / picture.get_height())
	backdrop.material_override = backdrop_material
	content.add_child(backdrop)

func _floor() -> void:
	var node := MeshInstance3D.new()
	node.name = "TexturedStoneCourt"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(18, 16)
	node.mesh = mesh
	node.position = Vector3(0, 0.012, 1)
	content.add_child(node)
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D paving : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float paving_scale = 3.0;
uniform float stone_contrast = 1.0;
uniform vec2 join_depth = vec2(-5.0, -3.0);
varying vec3 world_point;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 stone_uv = world_point.xz / paving_scale;
 vec3 stone = texture(paving, stone_uv).rgb;
 // Dust softens the joints to match the distant courtyard's worn paving.
 stone = mix(vec3(0.36, 0.33, 0.29), stone, stone_contrast);
 ALBEDO = stone * tint;
 ROUGHNESS = 0.9;
 // Softly join the lit 3D foreground to the illustrated distant paving.
 ALPHA = smoothstep(join_depth.x, join_depth.y, world_point.z) * (1.0 - smoothstep(6.7, 8.8, abs(world_point.x)));
}
"""
	floor_material = ShaderMaterial.new()
	floor_material.shader = shader
	floor_material.set_shader_parameter("paving", _texture("../nepal_realistic/stone-floor.png" if current_round == 0 else "stone-floor.png"))
	floor_material.set_shader_parameter("tint", Color("827e86") if night else Color("b4a99b"))
	if current_round == 0:
		floor_material.set_shader_parameter("tint", Color("cac5c0"))
		floor_material.set_shader_parameter("paving_scale", 1.65)
		floor_material.set_shader_parameter("stone_contrast", 0.68)
		floor_material.set_shader_parameter("join_depth", Vector2(-3.0, -1.5))
	node.material_override = floor_material
