extends Node3D
## Four supplied Kathmandu-valley GLB arenas, dressed with live lighting,
## weathered materials, atmospheric skies and animated practical details.
## Procedural construction helpers remain below for future scenery edits.
const ROUNDS := [
	{"name": "HERITAGE SQUARE", "night": true, "detail": "NIGHT / Temple lamps light the carved square and its three-tier pagoda"},
	{"name": "LANTERN SQUARE", "night": true, "detail": "NIGHT / Paper lanterns glow across the old square"},
	{"name": "TERRACE OVERLOOK", "night": false, "detail": "SUNSET / Terraced hills and the Himalaya turning gold"},
	{"name": "MOONLIT STUPA", "night": true, "detail": "FINAL NIGHT / Prayer flags stream from a white stupa"},
]
const ARENA_MODELS := [
	"res://assets/arenas/models/heritage-square.glb",
	"res://assets/arenas/models/lantern-square.glb",
	"res://assets/arenas/models/terrace-overlook.glb",
	"res://assets/arenas/models/moonlit-stupa.glb",
]
## Decode the source GLB with the running engine, not another version's
## binary import cache. Cache packed scenes for menu/round reuse.
static var arena_cache: Dictionary = {}
const PHOTO_SURFACE := preload("res://scripts/arena_photo_surface.gdshader")
const HIMALAYA := preload("res://scripts/himalaya_backdrop.gd")
## Sculpted Meshy props (tools/prepare_meshy_props.py) that replace the
## arena model's block-built landmarks, per round. Missing files keep the
## original pieces.
const PROPS := {
	0: "res://assets/arenas/props/heritage/",
}
## Photo-scanned surfaces from Poly Haven (CC0), in assets/arenas/textures/:
## kind -> [texture folder, metres per repeat, tint, normal strength, saturation].
const PHOTO_TEXTURES := {
	"wall_brick": ["red_bricks_04", 2.5, Color(1.25, 0.95, 0.82), 1.0, 1.35],
	"paving_brick": ["red_brick", 1.4, Color(1.1, 0.92, 0.84), 0.8, 1.15],
	"roof": ["roof_09", 3.2, Color(1.05, 0.9, 0.82), 1.0, 1.15],
	"wood": ["weathered_brown_planks", 1.8, Color(0.78, 0.5, 0.34), 0.9, 1.4],
	"plaster": ["painted_plaster_wall", 2.0, Color(1.05, 0.98, 0.86), 0.8, 1.0],
	"stone": ["medieval_blocks_03", 2.0, Color(0.95, 0.93, 0.9), 1.0, 0.9],
	"whitewash": ["white_plaster_02", 1.5, Color(1.08, 1.08, 1.06), 0.6, 0.7],
}
static var photo_materials: Dictionary = {}
const IMPORTED_SURFACE := preload("res://scripts/arena_surface.gdshader")
## Five traditional prayer-flag colours, in their customary order.
const FLAG_COLORS := [Color("2f6fc4"), Color("f1ede2"), Color("c8342c"), Color("2f8f4e"), Color("e6b62f")]
## Per-round ambient life: [kind, colour, amount]. The squares keep their
## air clear: floating motes read as stray pixels over a real scene. Only
## the finale keeps its sky lanterns, rising far behind the stupa.
const AMBIENCE := [
	["none", Color.WHITE, 0],
	["none", Color.WHITE, 0],
	["none", Color.WHITE, 0],
	["sky_lanterns", Color(1.0, 0.66, 0.3, 0.95), 16],
]
## Sky and light per round: [sky top, horizon, sun colour, sun energy,
## ambient colour, ambient energy, sun pitch, sun yaw, mountain tint].
const MOODS := [
	[Color("050a1c"), Color("22305a"), Color("c4d3ff"), 0.42, Color("4b5684"), 0.36, -38.0, -40.0, Color(0.42, 0.47, 0.68)],
	[Color("070b1c"), Color("1d2442"), Color("9fb4ec"), 0.36, Color("5b6690"), 0.4, -40.0, 30.0, Color(0.32, 0.36, 0.55)],
	[Color("46558f"), Color("f4a45e"), Color("ffb070"), 1.05, Color("c79a86"), 0.4, -16.0, 28.0, Color(1.0, 0.78, 0.62)],
	[Color("050817"), Color("18223e"), Color("b7c8f5"), 0.36, Color("5d6a96"), 0.32, -35.0, -25.0, Color(0.36, 0.42, 0.62)],
]
## Finishing grade per round (arena_grade.gdshader): [shadow tint,
## highlight tint, saturation, contrast, vignette, exposure, glow intensity,
## glow threshold]. Night squares lean teal in the darks and amber in the
## lamplight; the sunset warms everything; the stupa finale is cold and clean.
const GRADES := [
	[Color(0.86, 0.92, 1.08), Color(1.06, 0.98, 0.9), 1.12, 1.08, 0.34, 1.05, 1.1, 0.72],
	[Color(0.84, 0.9, 1.1), Color(1.08, 0.97, 0.86), 1.16, 1.1, 0.36, 1.05, 1.25, 0.68],
	[Color(0.94, 0.9, 1.0), Color(1.08, 1.0, 0.9), 1.18, 1.06, 0.28, 1.12, 0.7, 0.95],
	[Color(0.86, 0.92, 1.12), Color(0.98, 1.0, 1.06), 1.02, 1.12, 0.4, 1.0, 1.15, 0.7],
]
const GRADE_SHADER := preload("res://scripts/arena_grade.gdshader")
const SURFACE_SHADER := """shader_type spatial;
// World-space procedural surfaces: 0 brick, 1 cut stone, 2 roof tiles,
// 3 plaster, 4 timber, 5 flagstone, 6 carved lattice.
uniform int pattern = 0;
uniform vec3 base_color : source_color = vec3(0.6, 0.3, 0.2);
uniform vec3 joint_color : source_color = vec3(0.3, 0.26, 0.22);
uniform float scale = 1.0;
// Rain on the flagstones: puddles in the low slabs at night.
uniform float wetness = 0.0;
varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec3 an = abs(wn);
	vec2 uv = an.y > max(an.x, an.z) ? wp.xz : (an.x > an.z ? vec2(wp.z, wp.y) : wp.xy);
	uv /= scale;
	vec3 col = base_color;
	float rough = 0.88;
	float spec = 0.3;
	float grime = noise(uv * 1.3) * 0.18 + noise(uv * 7.0) * 0.08;
	if (pattern == 0) {
		vec2 b = uv / vec2(0.23, 0.075);
		b.x += mod(floor(b.y), 2.0) * 0.5;
		vec2 f = fract(b);
		float face = step(0.05, f.x) * step(0.12, f.y);
		col = mix(joint_color, base_color * (0.78 + 0.4 * hash(floor(b))), face);
	} else if (pattern == 1) {
		vec2 b = uv / vec2(0.6, 0.3);
		b.x += mod(floor(b.y), 2.0) * 0.5;
		vec2 f = fract(b);
		float face = step(0.02, f.x) * step(0.04, f.y);
		col = mix(joint_color, base_color * (0.86 + 0.22 * hash(floor(b))), face);
	} else if (pattern == 2) {
		vec2 b = uv / vec2(0.16, 0.11);
		b.x += mod(floor(b.y), 2.0) * 0.5;
		vec2 f = fract(b);
		col = base_color * (0.62 + 0.5 * f.y) * (0.85 + 0.25 * hash(floor(b)));
		col = mix(joint_color, col, step(0.06, f.x));
		rough = 0.7;
	} else if (pattern == 3) {
		col = base_color * (0.92 + noise(uv * 3.0) * 0.12);
	} else if (pattern == 4) {
		col = base_color * (0.8 + 0.25 * noise(vec2(uv.x * 40.0, uv.y * 2.0)));
		rough = 0.75;
	} else if (pattern == 5) {
		vec2 b = uv / vec2(0.9, 0.62);
		b.x += mod(floor(b.y), 2.0) * 0.37;
		vec2 f = fract(b);
		vec2 edge = min(f, 1.0 - f);
		float face = smoothstep(0.008, 0.023, edge.x) * smoothstep(0.012, 0.03, edge.y);
		float grain = noise(uv * 65.0);
		float veins = smoothstep(0.46, 0.54, noise(uv * 3.8 + noise(uv * 12.0)));
		// Each slab gets its own shade and a warm or cool cast, so no two
		// neighbouring stones read as copies.
		vec3 slab_tint = mix(vec3(1.05, 1.0, 0.93), vec3(0.94, 0.98, 1.05), hash(floor(b) + 17.3));
		col = mix(joint_color, base_color * slab_tint * (0.72 + 0.32 * hash(floor(b))) * (0.86 + grain * 0.18 + veins * 0.08), face);
		rough = mix(0.94, 0.66 + grain * 0.16, face);
		// Standing water darkens the low slabs into mirrors for the lamps;
		// the rest of the dais is merely damp.
		float puddle = smoothstep(0.52, 0.7, noise(uv * 0.55 + 3.1)) * wetness * face;
		col *= 1.0 - puddle * 0.45 - wetness * 0.08;
		rough = mix(rough, 0.08, puddle) - wetness * 0.12;
		spec = mix(0.32, 0.65, puddle);
	} else if (pattern == 6) {
		vec2 b = uv / 0.09;
		vec2 f = abs(fract(b) - 0.5);
		float lattice = step(0.36, max(f.x, f.y)) + step(0.46, f.x + f.y);
		col = mix(joint_color, base_color, clamp(lattice, 0.0, 1.0));
	}
	ALBEDO = col * (1.0 - grime * 0.6);
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	SPECULAR = spec;
}
"""
const SKY_SHADER := """shader_type sky;
uniform vec3 top_color : source_color;
uniform vec3 horizon_color : source_color;
uniform vec3 sun_color : source_color;
uniform vec3 sun_dir = vec3(0.0, 0.5, -1.0);
uniform float disc = 0.9994;
uniform float stars = 0.0;
// 1 at night: the disc becomes a moon with a soft halo instead of a sun.
uniform float moon = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float hash3(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
void sky() {
	float y = EYEDIR.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(-0.02, 0.55, y));
	// A warm band just above the horizon: dust and city glow at night, the
	// afterglow at sunset.
	col += horizon_color * 0.35 * exp(-max(y, 0.0) * 9.0) * (1.0 - stars * 0.5);
	vec3 s = normalize(sun_dir);
	float d = dot(EYEDIR, s);
	if (moon > 0.5) {
		// Crescent-lit moon: a bright disc with a soft, cool halo.
		float body = smoothstep(disc, disc + 0.0004, d);
		vec3 shade_dir = normalize(s + vec3(0.45, 0.2, 0.0));
		float phase = smoothstep(disc - 0.0015, disc + 0.0015, dot(EYEDIR, shade_dir));
		col += sun_color * body * (0.55 + 0.45 * (1.0 - phase));
		col += sun_color * 0.18 * pow(max(d, 0.0), 220.0);
		col += sun_color * 0.05 * pow(max(d, 0.0), 24.0);
	} else {
		col += sun_color * smoothstep(disc, disc + 0.0003, d) * 2.5;
		col += sun_color * 0.5 * pow(max(d, 0.0), 18.0);
		col += sun_color * 0.22 * pow(max(d, 0.0), 4.0);
	}
	vec2 cloud_uv = EYEDIR.xz / max(y + 0.18, 0.08) * 2.2 + vec2(TIME * 0.006, 0.0);
	float cloud = noise(cloud_uv) * 0.57 + noise(cloud_uv * 2.1) * 0.28 + noise(cloud_uv * 4.3) * 0.15;
	float cover = smoothstep(0.51, 0.75, cloud) * smoothstep(0.0, 0.18, y);
	// Clouds catch the light on their sunward side.
	float lit = 0.3 + 0.5 * max(d, 0.0);
	col = mix(col, mix(horizon_color, sun_color, lit), cover * (0.58 - stars * 0.3));
	if (stars > 0.0) {
		vec3 cell = floor(EYEDIR * 260.0);
		float h = hash3(cell);
		float twinkle = 0.7 + 0.3 * sin(TIME * (1.5 + h * 3.0) + h * 40.0);
		float bright = step(0.9968, h) * (0.4 + 0.6 * fract(h * 71.0)) * twinkle;
		vec3 star_tint = mix(vec3(0.85, 0.9, 1.0), vec3(1.0, 0.92, 0.8), fract(h * 13.0));
		// The Milky Way: a faint tilted band of finer stars and dust.
		float band = exp(-pow(dot(EYEDIR, normalize(vec3(0.6, 0.35, -0.7))) * 4.0, 2.0));
		float dust = noise(EYEDIR.xz * 9.0 + EYEDIR.y * 5.0) * band;
		col += star_tint * bright * stars * smoothstep(0.02, 0.25, y) * (1.0 - cover);
		col += vec3(0.5, 0.55, 0.75) * dust * 0.08 * stars * smoothstep(0.05, 0.4, y);
	}
	COLOR = col;
}
"""
var content: Node3D
var environment: WorldEnvironment
var sun: DirectionalLight3D
var current_round := -1
var night := false
var elapsed := 0.0
## The fighting dais surface; tests and previews use it to confirm a
## textured, solid floor exists for every round.
var floor_material: ShaderMaterial
var sky_material: ShaderMaterial
var surface_shader: Shader
var materials: Dictionary = {}
## Prayer-flag pivots; flutter samples the stage clock so the move-guide
## pause (which stops animate()) also freezes them.
var flags: Array[Node3D] = []
var lamp_lights: Array[OmniLight3D] = []
var lanterns: Array[Node3D] = []
## How many separate scenery meshes were merged into shared batches for the
## current round (see _batch_static); the arena's piece count, for tests.
var batched_pieces := 0
var fade: ColorRect
## Full-screen finishing pass (arena_grade.gdshader), drawn under the HUD.
var grade: ShaderMaterial
var grade_rect: ColorRect
var punch_level := 0.0
var flash_level := 0.0
var drain_level := 0.0
## Shadow-casting key light over the dais; the sun handles the daytime.
var key_light: SpotLight3D

func _ready() -> void:
	environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	add_child(environment)
	sky_material = ShaderMaterial.new()
	sky_material.shader = Shader.new()
	sky_material.shader.code = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.sky = sky
	# ACES keeps saturated lamplight and costume colours from clipping to
	# white the way the plain filmic curve did; exposure is set per round.
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.environment.tonemap_white = 6.0
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	# One shadow pass, not four cascades: every pass redraws both fighters,
	# and rigged fighters are the dearest thing on screen. The single map
	# covers the dais and the near square at the full 4096 atlas; the far
	# square and houses go unshadowed, which the lamps and haze hide.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 18.0
	sun.directional_shadow_fade_start = 0.8
	sun.shadow_blur = 1.1
	sun.shadow_normal_bias = 1.6
	add_child(sun)
	_grade()
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		settings.graphics_changed.connect(_apply_graphics)
		_apply_graphics()
	surface_shader = Shader.new()
	surface_shader.code = SURFACE_SHADER

func show_round(index: int) -> void:
	index = clampi(index, 0, ROUNDS.size() - 1)
	if index == current_round:
		return
	current_round = index
	night = ROUNDS[index].night
	var changing := content != null
	if content != null:
		remove_child(content)
		content.queue_free()
	flags.clear()
	lamp_lights.clear()
	lanterns.clear()
	content = Node3D.new()
	content.name = "HeritageScenery"
	add_child(content)
	elapsed = 0
	_lighting()
	_import_arena(index)
	if PROPS.has(index) and ResourceLoader.exists(PROPS[index] + "pagoda.glb"):
		_dress_heritage(PROPS[index])
	content.add_child(HIMALAYA.build(MOODS[index][1], night, index == 2))
	_fight_lighting()
	_arena_inlay()
	_batch_static()
	_ambience()
	if changing:
		_fade_in()

## Imported scenes already include the plaza, dais, flags and practical
## lamps. Keep their transforms intact: the solid fighting floor is y=0.
func _import_arena(index: int) -> void:
	var settings := get_node_or_null("/root/Settings")
	built_detailed = settings == null or settings.detailed_textures
	var packed := _load_arena_model(index)
	if packed == null or not packed.can_instantiate():
		_build_fallback(index)
		return
	var model := packed.instantiate() as Node3D
	model.name = "ArenaModel"
	model.set_meta("source_glb", ARENA_MODELS[index])
	content.add_child(model)
	floor_material = _surface("dais", 5, Color("8a8071"), Color("463f37"))
	floor_material.set_shader_parameter("wetness", 0.75 if night else 0.12)
	var polished: Dictionary = {}
	for node in model.find_children("*", "", true, false):
		if node is OmniLight3D:
			# glTF stores candela; Godot's non-physical renderer uses energy.
			node.light_energy = (0.95 if node.position.y > 2.0 else 1.1) if night else 0.35
			node.set_meta("base", node.light_energy)
			lamp_lights.append(node)
		elif node is MeshInstance3D:
			var bounds: AABB = node.mesh.get_aabb()
			# Identify the supplied dais geometrically, independent of exporter names.
			# Older glTF decoders pad bounds by roughly 0.00001 units.
			if bounds.size.distance_to(Vector3(12.2, 0.12, 3.8)) < 0.001:
				node.material_override = floor_material
				continue
			for surface in node.mesh.get_surface_count():
				var original: Material = node.get_active_material(surface)
				# The models' flat vertex-coloured ridge strips are replaced by
				# the generated Himalaya backdrop (see himalaya_backdrop.gd).
				if node.mesh is ArrayMesh and node.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR and bounds.size.x > 100.0:
					node.visible = false
					break
				if original is StandardMaterial3D and original.emission_enabled:
					var paper: StandardMaterial3D = original.duplicate()
					paper.emission = paper.albedo_color
					paper.emission_energy_multiplier = 0.65
					node.set_surface_override_material(surface, paper)
				if original is StandardMaterial3D and original.albedo_texture != null and not original.emission_enabled:
					var kind := _surface_kind(original.albedo_texture, bounds)
					if not kind.is_empty():
						if built_detailed:
							node.set_surface_override_material(surface, _photo_material(kind))
							continue
					if not polished.has(original):
						var finish := ShaderMaterial.new()
						finish.shader = IMPORTED_SURFACE
						finish.set_shader_parameter("color_texture", original.albedo_texture)
						finish.set_shader_parameter("tint", original.albedo_color)
						finish.set_shader_parameter("roughness", original.roughness)
						finish.set_shader_parameter("wetness", 0.65 if night else 0.15)
						polished[original] = finish
					node.set_surface_override_material(surface, polished[original])
			# The exports preserve the cloth/lantern hanger pivots.
			if node.get_parent() is Node3D and node.get_parent().get_parent() != model and node.get_parent().get_child_count() <= 3:
				var pivot: Node3D = node.get_parent()
				if bounds.size.z < 0.01 and bounds.size.x < 0.5 and bounds.size.y < 0.7 and not flags.has(pivot):
					flags.append(pivot)
				elif index == 1 and bounds.size.distance_to(Vector3(0.26, 0.3, 0.26)) < 0.001 and not lanterns.has(pivot):
					lanterns.append(pivot)
					_lantern_halo(pivot)

## Which photo surface replaces a baked pattern texture, recognised by its
## average colour (the exporter bakes one flat pattern per surface type).
## Returns "" for textures kept as they are (carved lattice, gilt roofs).
static var _kind_cache: Dictionary = {}
func _surface_kind(texture: Texture2D, bounds: AABB) -> String:
	var kind: String
	if _kind_cache.has(texture):
		kind = _kind_cache[texture]
	else:
		var image := texture.get_image()
		if image == null:
			return ""
		image = image.duplicate()
		if image.is_compressed():
			image.decompress()
		image.resize(1, 1, Image.INTERPOLATE_BILINEAR)
		var c := image.get_pixel(0, 0)
		var lum := 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
		if lum < 0.14 or (c.r > 0.6 and c.g > 0.45 and c.b < 0.35 and c.r - c.b > 0.35):
			kind = ""
		elif lum > 0.82:
			kind = "whitewash"
		elif absf(c.r - c.g) < 0.07 and absf(c.g - c.b) < 0.09 and lum > 0.3:
			kind = "stone"
		elif c.r > 0.7 and c.g > 0.65 and c.b > 0.5:
			kind = "plaster"
		elif c.r > c.g * 1.5 and lum > 0.3:
			kind = "brick"
		elif c.r > c.g * 1.7:
			kind = "roof"
		else:
			kind = "wood"
		_kind_cache[texture] = kind
	# The plaza is one huge flat slab; walls and plinths get the older brick.
	if kind == "brick":
		kind = "paving_brick" if bounds.size.y < 0.5 and bounds.size.x > 20.0 else "wall_brick"
	return kind

## Settings' shadow level drives the sun; switching arena textures
## rebuilds the current round so the change shows immediately.
var built_detailed := true
func _apply_graphics() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings == null or sun == null:
		return
	sun.shadow_enabled = settings.shadows > 0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 18.0 if settings.shadows == 2 else 14.0
	if key_light != null:
		key_light.shadow_enabled = _key_shadow()
	if environment != null and current_round >= 0:
		environment.environment.glow_enabled = _effects_level() > 0
		grade_rect.visible = _effects_level() > 0
	if settings.detailed_textures != built_detailed and current_round >= 0:
		var round_index := current_round
		current_round = -1
		show_round(round_index)

## The night key light's shadow is a whole extra scene pass, so only the
## HIGH shadow setting pays for it; the contact blobs ground the fighters
## on MEDIUM and LOW.
func _key_shadow() -> bool:
	var settings := get_node_or_null("/root/Settings")
	return settings == null or settings.shadows == 2

func _photo_material(kind: String) -> ShaderMaterial:
	var key := kind + ("_night" if night else "_day")
	if photo_materials.has(key):
		return photo_materials[key]
	var spec: Array = PHOTO_TEXTURES[kind]
	var folder := "res://assets/arenas/textures/%s/%s_" % [spec[0], spec[0]]
	var material := ShaderMaterial.new()
	material.shader = PHOTO_SURFACE
	material.set_shader_parameter("albedo_map", load(folder + "diff_1k.jpg"))
	material.set_shader_parameter("normal_map", load(folder + "nor_gl_1k.jpg"))
	material.set_shader_parameter("roughness_map", load(folder + "rough_1k.jpg"))
	material.set_shader_parameter("world_size", spec[1])
	material.set_shader_parameter("tint", spec[2])
	material.set_shader_parameter("normal_strength", spec[3])
	material.set_shader_parameter("saturation", spec[4])
	material.set_shader_parameter("wetness", 0.65 if night and kind in ["paving_brick", "stone"] else 0.0)
	photo_materials[key] = material
	return material

static func _load_arena_model(index: int) -> PackedScene:
	var path: String = ARENA_MODELS[index]
	if arena_cache.has(path):
		return arena_cache[path]
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var result := document.append_from_file(path, state)
	if result != OK:
		push_warning("Could not decode arena %s (%s); using procedural scenery." % [path, error_string(result)])
		return null
	var model := document.generate_scene(state)
	if model == null:
		push_warning("Arena %s has no scene; using procedural scenery." % path)
		return null
	var packed := PackedScene.new()
	result = packed.pack(model)
	model.free()
	if result != OK:
		push_warning("Could not cache arena %s; using procedural scenery." % path)
		return null
	arena_cache[path] = packed
	return packed

## Asset failures must still leave a visible floor and complete arena.
func _build_fallback(index: int) -> void:
	_ground()
	_houses()
	match index:
		0, 1:
			_pagoda(Vector3(0, -0.12, -24))
			for side in [-1.0, 1.0]:
				_shikhara(Vector3(side * 8.2, -0.12, -19.5))
		2:
			_overlook()
		3:
			_stupa(Vector3(0, -0.12, -25))
	if index == 1:
		_lantern_strings()
	elif index != 3:
		_flag_line(Vector3(-6.4, 3.7, -4.6), Vector3(6.4, 3.7, -4.6), 0.55, 35)
		_flag_poles(6.4, 3.7, -4.6)
	_butter_lamps()

## A small soft halo works in Compatibility without full-screen bloom.
func _lantern_halo(parent: Node3D) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	var glow := ShaderMaterial.new()
	glow.shader = preload("res://scripts/lantern_glow.gdshader")
	var sprite := _piece(quad, Vector3(0, -0.22, 0), glow, parent)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Broad, low-energy fill separates silhouettes from dark architecture.
## These lights stay outside the fighting lane and never change collision.
func _fight_lighting() -> void:
	var fill := OmniLight3D.new()
	fill.name = "FighterFill"
	fill.position = Vector3(0, 4, 3)
	fill.omni_range = 13
	fill.light_color = Color("b8d9ff") if night else Color("fff0d6")
	fill.light_energy = 0.7 if night else 0.35
	content.add_child(fill)
	var rim := OmniLight3D.new()
	rim.name = "FighterRim"
	rim.position = Vector3(0, 3.4, -3)
	rim.omni_range = 10
	rim.light_color = Color("ffb46e") if current_round in [1, 2] else Color("a0cfff")
	rim.light_energy = 1.1 if night else 0.6
	content.add_child(rim)
	# A shadow-casting key light over the dais. At night the moon's shadows
	# are too faint to ground the fighters, so a warm (cold, for the stupa)
	# spot from high in front does it; by day the sun already does.
	key_light = null
	if night:
		key_light = SpotLight3D.new()
		key_light.name = "DaisKey"
		key_light.position = Vector3(1.5, 6.5, 4.5)
		key_light.look_at_from_position(key_light.position, Vector3(0, 0.9, 0), Vector3.UP)
		key_light.spot_range = 14.0
		key_light.spot_angle = 42.0
		key_light.spot_attenuation = 0.9
		key_light.light_color = Color("ffc98a") if current_round in [0, 1] else Color("b9cdf5")
		key_light.set_meta("base", 1.35 if current_round in [0, 1] else 1.1)
		key_light.light_energy = key_light.get_meta("base")
		key_light.shadow_enabled = _key_shadow()
		key_light.shadow_blur = 1.5
		key_light.shadow_normal_bias = 1.4
		content.add_child(key_light)
	if night:
		for side in [-1.0, 1.0]:
			var wash := OmniLight3D.new()
			wash.position = Vector3(side * 7.5, 3.5, -17)
			wash.omni_range = 15
			wash.light_color = Color("ffaf68") if current_round in [0, 1] else Color("adc7ff")
			wash.light_energy = 1.25
			content.add_child(wash)

## Merges every static scenery mesh that shares a material (and vertex
## layout and shadow setting) into one mesh, the way shipped games bake
## their arenas: ~600 separately drawn bricks, beams, steps and lamps become
## a couple of dozen draws, which is what integrated GPUs choke on. Pieces
## that move (flag and lantern pivots), lights, particles and the shared
## Himalayan backdrop stay as they are. World-space shaders are unaffected
## because merged vertices keep their world positions.
func _batch_static() -> void:
	batched_pieces = 0
	if not is_inside_tree() or content == null:
		return
	var moving := {}
	for pivot in flags:
		moving[pivot] = true
	for pivot in lanterns:
		moving[pivot] = true
	var to_content := content.global_transform.affine_inverse()
	var groups := {}
	var merged: Array[Node] = []
	for node in content.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null or not node.is_visible_in_tree() or _moves_or_shared(node, moving):
			continue
		var parts := []
		for surface in node.mesh.get_surface_count():
			if node.mesh is ArrayMesh and node.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				parts.clear()
				break
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var layout := "%d%d%d%d" % [int(arrays[Mesh.ARRAY_COLOR] != null), int(arrays[Mesh.ARRAY_TEX_UV] != null),
				int(arrays[Mesh.ARRAY_TEX_UV2] != null), int(arrays[Mesh.ARRAY_TANGENT] != null)]
			parts.append([node.get_active_material(surface), layout, surface])
		if parts.is_empty():
			continue
		var place: Transform3D = to_content * node.global_transform
		for part in parts:
			var key := [part[0], part[1], node.cast_shadow]
			if not groups.has(key):
				groups[key] = []
			groups[key].append([node.mesh, part[2], place])
		merged.append(node)
	for key in groups:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for piece in groups[key]:
			tool.append_from(piece[0], piece[1], piece[2])
		var batch := MeshInstance3D.new()
		batch.name = "Batched"
		batch.mesh = tool.commit()
		batch.material_override = key[0]
		batch.cast_shadow = key[2]
		content.add_child(batch)
	for node in merged:
		node.get_parent().remove_child(node)
		node.queue_free()
	batched_pieces = merged.size()

func _moves_or_shared(node: Node, moving: Dictionary) -> bool:
	var parent := node.get_parent()
	while parent != null and parent != content:
		if moving.has(parent) or parent.name == "HimalayaBackdrop":
			return true
		parent = parent.get_parent()
	return false

## Thin brass inlays make the usable lane legible without floating UI.
func _arena_inlay() -> void:
	var brass := _flat("inlay", Color("bc9855"), 0.08, 0.65)
	for side in [-1.0, 1.0]:
		_box(Vector3(11.7, 0.004, 0.018), Vector3(0, 0.003, side * 1.75), brass)
		_box(Vector3(0.018, 0.004, 3.5), Vector3(side * 5.85, 0.003, 0), brass)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.71
	ring.outer_radius = 0.73
	ring.rings = 64
	ring.ring_segments = 8
	var seal := _piece(ring, Vector3(0, 0.004, 0), brass)
	seal.scale.y = 0.12

func animate(delta: float) -> void:
	elapsed += delta
	if punch_level > 0.0 or flash_level > 0.0 or drain_level > 0.0:
		punch_level = move_toward(punch_level, 0.0, delta * 5.5)
		flash_level = move_toward(flash_level, 0.0, delta * 3.5)
		drain_level = move_toward(drain_level, 0.0, delta * 1.6)
		grade.set_shader_parameter("punch", punch_level)
		grade.set_shader_parameter("flash", flash_level)
		grade.set_shader_parameter("drain", drain_level)
	if key_light != null:
		# The key light breathes with the flames it stands for.
		key_light.light_energy = key_light.get_meta("base") * (0.94 + 0.06 * sin(elapsed * 7.0) * sin(elapsed * 3.3))
	for i in flags.size():
		# Wind travels along the rope, so neighbouring flags ripple in sequence.
		flags[i].rotation.x = sin(elapsed * 3.1 - i * 0.55) * 0.35
		flags[i].rotation.z = sin(elapsed * 2.3 - i * 0.4) * 0.08
	for i in lanterns.size():
		lanterns[i].rotation.z = sin(elapsed * 1.6 + i * 0.9) * 0.06
	for i in lamp_lights.size():
		var flicker := 0.86 + 0.14 * sin(elapsed * 11.0 + i * 2.1) * sin(elapsed * 4.7 + i)
		lamp_lights[i].light_energy = lamp_lights[i].get_meta("base") * flicker

# --- materials and primitives -------------------------------------------

func _surface(key: String, pattern: int, base: Color, joint: Color, surface_scale := 1.0) -> ShaderMaterial:
	if not materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = surface_shader
		material.set_shader_parameter("pattern", pattern)
		material.set_shader_parameter("base_color", base)
		material.set_shader_parameter("joint_color", joint)
		material.set_shader_parameter("scale", surface_scale)
		materials[key] = material
	return materials[key]

func _flat(key: String, color: Color, glow := 0.0, metal := 0.0) -> StandardMaterial3D:
	if not materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.85 if metal == 0.0 else 0.35
		material.metallic = metal
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if glow > 0.0:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = glow
		materials[key] = material
	return materials[key]

func _brick() -> ShaderMaterial:
	return _surface("brick", 0, Color("a4513a"), Color("5e4a3c"))

func _stone() -> ShaderMaterial:
	return _surface("stone", 1, Color("a09685"), Color("5f584e"))

func _wood() -> ShaderMaterial:
	return _surface("wood", 4, Color("4a2e1d"), Color("2a190f"))

func _roof() -> ShaderMaterial:
	return _surface("roof", 2, Color("6b3b28"), Color("2b1a13"))

func _lattice() -> ShaderMaterial:
	return _surface("lattice", 6, Color("3a2416"), Color("0d0806"))

func _gold() -> StandardMaterial3D:
	return _flat("gold", Color("d4a646"), 0.0, 0.7)

func _piece(shape: Mesh, at: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material
	node.position = at
	(parent if parent != null else content).add_child(node)
	return node

func _box(size: Vector3, at: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _piece(shape, at, material, parent)

## Square (or n-sided) frustum; four sides are turned so edges follow the axes.
func _frustum(bottom_half: float, top_half: float, height: float, at: Vector3, material: Material, sides := 4) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	var corner := sqrt(2.0) if sides == 4 else 1.0
	shape.bottom_radius = bottom_half * corner
	shape.top_radius = top_half * corner
	shape.height = height
	shape.radial_segments = sides
	shape.rings = 1
	var node := _piece(shape, at + Vector3(0, height * 0.5, 0), material)
	if sides == 4:
		node.rotation.y = PI / 4.0
	return node

func _ball(radius: float, at: Vector3, material: Material, squash := 1.0) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 20
	shape.rings = 10
	var node := _piece(shape, at, material)
	node.scale.y = squash
	return node

# --- sky, light and ground ----------------------------------------------

## Heritage Square: swaps the block pagoda, stone towers, temple lions,
## plank windows and doorways and the corner lamp boxes for Meshy props.
## Pieces are recognised by position and shape in the arena model, so the
## model file itself stays as supplied.
func _dress_heritage(folder: String) -> void:
	var model := content.get_node_or_null("ArenaModel") as Node3D
	if model == null:
		return
	var to_content := content.global_transform.affine_inverse()
	var windows: Array = []  # [centre, width, facing]
	var doors: Array = []
	var doomed: Array[Node] = []
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (to_content * node.global_transform) * node.get_aabb()
		var centre := box.get_center()
		var size := box.size
		var facing := 1.0 if centre.x < 0.0 else -1.0
		var square := absf(size.x - size.z) < 0.05
		if absf(centre.x) < 4.4 and centre.z < -19.0 and centre.z > -33.0 and size.x < 14.0:
			doomed.append(node)  # pagoda, its stairs and lions
		elif absf(centre.x) > 6.2 and absf(centre.x) < 10.3 and centre.z > -21.7 and centre.z < -17.3 and square:
			doomed.append(node)  # stone towers
		elif absf(centre.x) > 5.0 and absf(centre.x) < 6.0 and absf(centre.z + 1.55) < 0.5 and box.end.y < 0.5:
			doomed.append(node)  # lamp box and its clay bowls
		elif size.x < 0.3 and absf(centre.x) > 7.9 and absf(centre.x) < 8.8:
			var wall := box.position.x if facing > 0.0 else box.end.x
			if size.distance_to(Vector3(0.12, 1.5, 1.1)) < 0.05:
				doors.append([Vector3(wall, box.position.y, centre.z), facing])
				doomed.append(node)
			elif size.distance_to(Vector3(0.16, 0.16, 1.5)) < 0.05:
				doomed.append(node)  # door lintel
			elif absf(size.y - 1.05) < 0.03 and size.x < 0.2 and (absf(size.z - 0.96) < 0.03 or absf(size.z - 2.44) < 0.03):
				windows.append([Vector3(wall, centre.y, centre.z), size.z, facing])
				doomed.append(node)
			elif absf(size.y - 0.84) < 0.03 or (absf(size.y - 0.1) < 0.02 and size.z > 1.0):
				doomed.append(node)  # window pane and sill
	for node in doomed:
		node.get_parent().remove_child(node)
		node.free()
	var floor_y := -0.12
	_place_prop(folder + "pagoda.glb", Vector3(0, floor_y, -24.4), 0.0)
	# The real range rises beyond the rooftops, hazed by distance fog.
	var range_path: String = folder + "himalaya.glb"
	if ResourceLoader.exists(range_path):
		var peaks := (load(range_path) as PackedScene).instantiate() as Node3D
		peaks.position = Vector3(0, -4.0, -175.0)
		peaks.scale = Vector3(1.6, 1.5, 1.0)
		for mesh: MeshInstance3D in peaks.find_children("*", "MeshInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		content.add_child(peaks)
	if night:
		_heritage_night(floor_y)
	for side in [-1.0, 1.0]:
		_place_prop(folder + "shikhara.glb", Vector3(side * 8.2, floor_y, -19.5), 0.0)
		_place_prop(folder + "lion.glb", Vector3(side * 3.0, floor_y, -19.0), 0.0)
		_place_prop(folder + "diyo_stand.glb", Vector3(side * 5.5, 0.0, -1.55), 0.0)
		for z in [-15.0, -8.0]:
			_place_prop(folder + "lamp_post.glb", Vector3(side * 6.9, floor_y, z), -side * PI / 2.0)
	for door in doors:
		_place_prop(folder + "doorway.glb", door[0], door[1] * PI / 2.0, 1.35 / 1.75, CARVED_WOOD)
	# Newari windows come in pairs: each run of three small panes, or one
	# wide pane, becomes two carved windows side by side.
	windows.sort_custom(func(a, b): return [a[0].x, a[0].y, a[0].z] < [b[0].x, b[0].y, b[0].z])
	var runs: Array = []
	for window in windows:
		var last: Array = runs.back() if not runs.is_empty() else []
		var joined := false
		if not last.is_empty():
			var prev: Array = last.back()
			joined = absf(prev[0].x - window[0].x) < 0.05 and absf(prev[0].y - window[0].y) < 0.05 				and window[0].z - window[1] * 0.5 - (prev[0].z + prev[1] * 0.5) < 0.2
		if joined:
			last.append(window)
		else:
			runs.append([window])
	for run: Array in runs:
		var low: float = run[0][0].z - run[0][1] * 0.5
		var high: float = run.back()[0].z + run.back()[1] * 0.5
		var width := (high - low) / 2.0
		for part in 2:
			var at: Vector3 = run[0][0]
			at.z = low + width * (part + 0.5)
			var scale := width / 1.28
			at.y -= 1.15 * scale * 0.5
			_place_prop(folder + "window.glb", at, run[0][2] * PI / 2.0, scale, CARVED_WOOD)

## Dark carved wood: lifted and warmed so the blue sky light doesn't read it
## as grey stone.
const CARVED_WOOD := Color(1.3, 0.98, 0.68)
## Tinted copies shared by every placement, so repeats batch together.
var _tinted: Dictionary = {}

## Facade pieces (tinted) sit flat on walls: their shadows would only fall
## on the wall behind, so they skip the shadow pass.
## Night in the square: warm pools under each lamp post, golden light up
## the pagoda's tiers and the towers, and a moonlit rim on the lions.
func _heritage_night(floor_y: float) -> void:
	var lights := [
		# [position, colour, energy, range]
		[Vector3(0, floor_y + 0.6, -18.2), Color("ffb25c"), 2.6, 9.0],   # pagoda steps, up the facade
		[Vector3(0, floor_y + 7.5, -18.5), Color("ffc27a"), 1.4, 7.0],   # upper tiers
	]
	for side in [-1.0, 1.0]:
		lights.append([Vector3(side * 6.9, floor_y + 0.6, -17.6), Color("ffb868"), 1.6, 6.5])  # tower base
		for z in [-15.0, -8.0]:
			lights.append([Vector3(side * 6.7, floor_y + 3.0, z), Color("ffb45a"), 1.8, 6.0])  # lamp posts
	for spec in lights:
		var lamp := OmniLight3D.new()
		lamp.position = spec[0]
		lamp.light_color = spec[1]
		lamp.light_energy = spec[2]
		lamp.omni_range = spec[3]
		lamp.omni_attenuation = 1.4
		lamp.set_meta("base", spec[2])
		content.add_child(lamp)
		lamp_lights.append(lamp)
	# A glowing lantern flame in each lamp post head.
	var flame := _flat("post_flame", Color("ffc46a"), 5.0)
	for side in [-1.0, 1.0]:
		for z in [-15.0, -8.0]:
			_ball(0.07, Vector3(side * 6.9, floor_y + 3.05, z), flame, 1.0).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _place_prop(path: String, at: Vector3, turn: float, scale := 1.0, tint := Color.WHITE) -> void:
	if not ResourceLoader.exists(path):
		return
	var prop := (load(path) as PackedScene).instantiate() as Node3D
	prop.position = at
	prop.rotation.y = turn
	prop.scale = Vector3.ONE * scale
	if tint != Color.WHITE:
		for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for surface in mesh.get_surface_override_material_count():
				var material := mesh.get_active_material(surface)
				if material is StandardMaterial3D:
					if not _tinted.has(material):
						var warm: StandardMaterial3D = material.duplicate()
						warm.albedo_color = tint
						warm.metallic = 0.0
						warm.metallic_texture = null
						_tinted[material] = warm
					mesh.set_surface_override_material(surface, _tinted[material])
	content.add_child(prop)

func _lighting() -> void:
	var mood: Array = MOODS[current_round]
	var look: Array = GRADES[current_round]
	sky_material.set_shader_parameter("top_color", mood[0])
	sky_material.set_shader_parameter("horizon_color", mood[1])
	sky_material.set_shader_parameter("sun_color", mood[2])
	sky_material.set_shader_parameter("stars", 0.9 if night else 0.0)
	sky_material.set_shader_parameter("moon", 1.0 if night else 0.0)
	sky_material.set_shader_parameter("disc", 0.9992 if night else 0.99955)
	sun.rotation_degrees = Vector3(mood[6], mood[7], 0)
	# The light travels along -Z of its basis, so the disc sits along +Z.
	sky_material.set_shader_parameter("sun_dir", Basis.from_euler(sun.rotation) * Vector3.BACK)
	sun.light_color = mood[2]
	sun.light_energy = mood[3]
	var env: Environment = environment.environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = mood[4]
	env.ambient_light_energy = mood[5]
	env.tonemap_exposure = look[5]
	# Depth fog leaves the fighters crisp while the distant ridges merge
	# naturally into the sky. Supported by the Compatibility renderer.
	env.fog_enabled = true
	env.fog_light_color = mood[1]
	env.fog_light_energy = 0.65
	env.fog_density = 0.0025 if night else 0.0018
	env.fog_sky_affect = 0.12
	# Sunlight scattered into the haze, so fog glows toward the sun.
	env.fog_sun_scatter = 0.0 if night else 0.35
	# A thin ground mist pools on the night squares: it catches the
	# lamplight low around the dais without dulling the fighters.
	env.fog_height = 0.35 if night else -20.0
	env.fog_height_density = 0.045 if night else 0.0
	# Bloom on flames, lanterns, lit windows and the sun disc. The threshold
	# is set so costume colours and pale stone stay crisp while anything
	# emissive or sunlit-white blooms. Off at the lowest quality preset.
	env.glow_enabled = _effects_level() > 0
	grade_rect.visible = _effects_level() > 0
	env.glow_intensity = look[6]
	env.glow_strength = 1.0
	env.glow_bloom = 0.04 if night else 0.02
	env.glow_hdr_threshold = look[7]
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT if night else Environment.GLOW_BLEND_MODE_ADDITIVE
	if not night:
		env.glow_intensity = look[6] * 0.5
	grade.set_shader_parameter("shadow_tint", look[0])
	grade.set_shader_parameter("highlight_tint", look[1])
	grade.set_shader_parameter("saturation", look[2])
	grade.set_shader_parameter("contrast", look[3])
	grade.set_shader_parameter("vignette", look[4])
	grade.set_shader_parameter("punch_color", Color("ffd9a0") if current_round != 3 else Color("cfe4ff"))

## 0 on the LOW preset (or custom settings with everything off), 1 otherwise:
## gates the post effects and the dais key-light shadow.
func _effects_level() -> int:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return 1
	if not settings.post_effects:
		return 0
	if settings.quality == settings.Quality.LOW:
		return 0
	if settings.quality == settings.Quality.CUSTOM and settings.shadows == 0 and settings.anti_aliasing == 0:
		return 0
	return 1

## The finishing pass: a screen-reading ColorRect on its own canvas layer,
## under every HUD layer (which start at 1) and over the 3D world.
func _grade() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Grade"
	layer.layer = 0
	add_child(layer)
	grade = ShaderMaterial.new()
	grade.shader = GRADE_SHADER
	grade_rect = ColorRect.new()
	grade_rect.name = "GradeRect"
	grade_rect.material = grade
	grade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(grade_rect)

## An impact seen at `screen_point` (0..1 across the view): a shock ring and
## a radial colour split that fade over a few frames. `strength` 1 is a
## heavy hit.
func punch(screen_point: Vector2, strength: float) -> void:
	if _effects_level() == 0:
		return
	punch_level = maxf(punch_level, clampf(strength, 0.0, 1.0))
	grade.set_shader_parameter("punch_center", screen_point)
	grade.set_shader_parameter("punch", punch_level)

## A whole-screen flash that decays into a brief drain of colour: the
## knockout hit.
func flash(color: Color, strength: float, drain_after := 0.0) -> void:
	flash_level = maxf(flash_level, strength)
	drain_level = maxf(drain_level, drain_after)
	grade.set_shader_parameter("flash_color", color)
	grade.set_shader_parameter("flash", flash_level)
	grade.set_shader_parameter("drain", drain_level)

func _ground() -> void:
	# Brick plaza one step below the flagstone fighting dais.
	var plaza := PlaneMesh.new()
	plaza.size = Vector2(90, 90)
	_piece(plaza, Vector3(0, -0.12, -10), _surface("plaza", 0, Color("8e4a36"), Color("4b3a30"), 1.25))
	floor_material = _surface("dais", 5, Color("8a8071"), Color("463f37"))
	_box(Vector3(12.2, 0.12, 3.8), Vector3(0, -0.06, 0), floor_material)
	# Carved stone kerb frames the dais.
	var kerb := _surface("kerb", 1, Color("7d7466"), Color("3f3a33"))
	for side in [-1.0, 1.0]:
		_box(Vector3(12.6, 0.16, 0.22), Vector3(0, -0.05, side * 2.0), kerb)
		_box(Vector3(0.22, 0.16, 4.2), Vector3(side * 6.2, -0.05, 0), kerb)

## Two rings of ridges: blue-green foothills and the snowy Himalaya behind.
func _mountains() -> void:
	var tint: Color = MOODS[current_round][8]
	_ridge(110.0, 2.0, 7.0, 71, Color("3b5a5e") * tint, Color("6f8f86") * tint, 0.0, 1.3)
	_ridge(190.0, 10.0, 30.0, 97, Color("6a82a0") * tint, Color("f2f4f8") * tint, 0.6, 3.7)

func _ridge(radius: float, low: float, high: float, seed_value: int, base: Color, peak: Color, snow_line: float, frequency: float) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 90
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var offsets: Array[float] = []
	for i in 6:
		offsets.append(rng.randf() * TAU)
	var shoulder := base.lerp(peak, 0.45)
	var snow_height := lerpf(low, high, snow_line)
	var previous_top := Vector3.ZERO
	var previous_base := Vector3.ZERO
	for i in steps + 1:
		var t := float(i) / steps
		var angle := lerpf(-2.1, 2.1, t)
		var ridge := 0.5 + 0.28 * sin(angle * frequency * 2.0 + offsets[0]) + 0.16 * sin(angle * frequency * 5.3 + offsets[1]) + 0.08 * sin(angle * frequency * 11.0 + offsets[2])
		var height := lerpf(low, high, clampf(ridge, 0.0, 1.0))
		var direction := Vector3(sin(angle), 0, -cos(angle))
		var top := direction * radius + Vector3(0, height, 0)
		var bottom := direction * radius + Vector3(0, -2, 0)
		if i > 0:
			var top_color := peak if snow_line > 0.0 and height > snow_height else shoulder
			var previous_color := peak if snow_line > 0.0 and previous_top.y > snow_height else shoulder
			for vertex in [[previous_base, base], [previous_top, previous_color], [top, top_color], [previous_base, base], [top, top_color], [bottom, base]]:
				tool.set_color(vertex[1])
				tool.add_vertex(vertex[0])
		previous_top = top
		previous_base = bottom
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content.add_child(node)

# --- architecture -------------------------------------------------------

## Newari town houses line both sides of the square, facing inward.
func _houses() -> void:
	var plaster := _surface("plaster", 3, Color("d9c6a2"), Color("b19a78"))
	for side in [-1.0, 1.0]:
		var zs := [-20.0, -16.2, -12.4, -8.6, -4.8, -1.0, 2.8, 6.6]
		for i in zs.size():
			var z: float = zs[i]
			var storeys := 3 if (i + (1 if side > 0 else 0)) % 2 == 0 else 2
			var height := 1.1 + storeys * 1.75
			var x: float = side * (10.2 + (i % 2) * 0.4)
			var face: float = x - side * 2.0
			_box(Vector3(4.0, height, 3.7), Vector3(x, height * 0.5 - 0.12, z), _brick() if i % 3 != 2 else plaster)
			# Timber string courses between storeys.
			for storey in storeys:
				var level := 1.05 + storey * 1.75
				_box(Vector3(0.18, 0.14, 3.8), Vector3(face - side * 0.06, level, z), _wood())
			# Ground floor: shop doorway with a carved lintel.
			_box(Vector3(0.12, 1.5, 1.1), Vector3(face - side * 0.04, 0.63, z - 0.8), _flat("doorway", Color("1a110b")))
			_box(Vector3(0.16, 0.16, 1.5), Vector3(face - side * 0.07, 1.45, z - 0.8), _wood())
			# Upper storeys: the classic three-bay window, then a wide sanjhya.
			for storey in range(1, storeys):
				var y := 1.05 + storey * 1.75 - 0.95
				var bays := 3 if storey == 1 else 1
				for bay in bays:
					var width := 0.72 if bays == 3 else 2.2
					var bz: float = z + (bay - 1) * 0.95 if bays == 3 else z
					_box(Vector3(0.16, 1.05, width + 0.24), Vector3(face - side * 0.07, y, bz), _wood())
					_box(Vector3(0.18, 0.84, width), Vector3(face - side * 0.1, y, bz), _lattice())
					_box(Vector3(0.26, 0.1, width + 0.5), Vector3(face - side * 0.12, y - 0.58, bz), _wood())
			# Overhanging tiled gable roof held on carved struts.
			var roof := PrismMesh.new()
			roof.size = Vector3(5.3, 1.3, 4.3)
			_piece(roof, Vector3(x, height + 0.5, z), _roof())
			for strut in 3:
				var brace := _box(Vector3(0.1, 0.8, 0.1), Vector3(face - side * 0.28, height - 0.25, z - 1.3 + strut * 1.3), _wood())
				brace.rotation.z = side * -0.6

func _pagoda(at: Vector3) -> void:
	# Five-step brick plinth with a central stair and guardian lions.
	var step_height := 0.5
	for i in 5:
		var half := 4.2 - i * 0.55
		_box(Vector3(half * 2, step_height, half * 2), at + Vector3(0, step_height * (i + 0.5), 0), _brick())
		_box(Vector3(half * 2 + 0.08, 0.06, half * 2 + 0.08), at + Vector3(0, step_height * (i + 1), 0), _stone())
	for i in 5:
		_box(Vector3(1.4, step_height * (i + 1), 0.55), at + Vector3(0, step_height * (i + 1) * 0.5, 4.5 - i * 0.55), _stone())
	for side in [-1.0, 1.0]:
		_lion(at + Vector3(side * 1.05, 0, 4.6))
	var top := at + Vector3(0, step_height * 5, 0)
	# Sanctum: brick walls with three latticed doors under a gilded arch.
	_box(Vector3(3.4, 2.3, 3.4), top + Vector3(0, 1.15, 0), _brick())
	for door in 3:
		_box(Vector3(0.62, 1.5, 0.1), top + Vector3((door - 1) * 0.85, 0.78, 1.72), _wood())
		_box(Vector3(0.5, 1.2, 0.12), top + Vector3((door - 1) * 0.85, 0.72, 1.74), _lattice())
	var arch := _ball(1.1, top + Vector3(0, 1.62, 1.74), _gold(), 0.5)
	arch.scale.z = 0.05
	# Three diminishing roofs with struts, gilded eaves and corner bells:
	# [eave half-width, top half-width, roof height, storey above].
	var tiers := [[3.3, 1.9, 1.25, 1.2], [2.4, 1.25, 1.05, 1.0], [1.65, 0.12, 1.25, 0.0]]
	var y := 2.3
	for t in tiers.size():
		var tier: Array = tiers[t]
		var eave: float = tier[0]
		_frustum(eave, tier[1], tier[2], top + Vector3(0, y, 0), _roof() if t < 2 else _surface("gilt", 2, Color("c79a3e"), Color("6d5220")))
		for side in [-1.0, 1.0]:
			_box(Vector3(eave * 2 + 0.05, 0.08, 0.1), top + Vector3(0, y + 0.03, side * eave), _gold())
			_box(Vector3(0.1, 0.08, eave * 2 + 0.05), top + Vector3(side * eave, y + 0.03, 0), _gold())
			for corner in [-1.0, 1.0]:
				_ball(0.08, top + Vector3(side * eave * 0.98, y - 0.14, corner * eave * 0.98), _gold())
		# Carved struts brace each eave from the wall below.
		var wall_half: float = 1.7 if t == 0 else float(tiers[t - 1][0]) * 0.62
		for s in 4:
			var angle := s * PI / 2.0
			var normal := Vector3(sin(angle), 0, cos(angle))
			var tangent := Vector3(cos(angle), 0, -sin(angle))
			for k in 3:
				var brace := _box(Vector3(0.09, 0.95, 0.09), top + Vector3(0, y - 0.38, 0) + normal * (wall_half + 0.35) + tangent * ((k - 1) * wall_half * 0.6), _wood())
				brace.rotation.y = angle
				brace.rotate_object_local(Vector3.RIGHT, 0.62)
		y += tier[2]
		if t < 2:
			var body_half: float = float(tiers[t + 1][0]) * 0.62
			_box(Vector3(body_half * 2, tier[3], body_half * 2), top + Vector3(0, y + tier[3] * 0.5, 0), _brick())
			y += tier[3]
	# Gilded pinnacle (gajur).
	for k in 4:
		_ball(0.3 - k * 0.05, top + Vector3(0, y + 0.2 + k * 0.38, 0), _gold(), 0.8)
	_frustum(0.06, 0.02, 0.6, top + Vector3(0, y + 1.6, 0), _gold(), 8)

func _shikhara(at: Vector3) -> void:
	for i in 3:
		var half := 1.9 - i * 0.35
		_box(Vector3(half * 2, 0.45, half * 2), at + Vector3(0, 0.45 * (i + 0.5), 0), _stone())
	var base := at + Vector3(0, 1.35, 0)
	_box(Vector3(2.0, 1.6, 2.0), base + Vector3(0, 0.8, 0), _stone())
	for side in [-1.0, 1.0]:
		for column in [-0.6, 0.0, 0.6]:
			_box(Vector3(0.14, 1.3, 0.14), base + Vector3(column, 0.65, side * 1.05), _stone())
	# Corner pavilions around a tall tapering spire.
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_frustum(0.42, 0.08, 1.4, base + Vector3(cx * 0.8, 1.6, cz * 0.8), _stone(), 8)
	_frustum(0.95, 0.22, 4.4, base + Vector3(0, 1.6, 0), _stone(), 8)
	_ball(0.26, base + Vector3(0, 6.2, 0), _gold())
	_frustum(0.05, 0.01, 0.5, base + Vector3(0, 6.35, 0), _gold(), 6)

func _lion(at: Vector3) -> void:
	var stone := _surface("lion", 1, Color("b4aa98"), Color("6c6558"), 0.4)
	_box(Vector3(0.7, 0.7, 0.7), at + Vector3(0, 0.35, 0), _stone())
	var body := _box(Vector3(0.36, 0.45, 0.6), at + Vector3(0, 0.95, 0), stone)
	body.rotation.x = -0.25
	_ball(0.3, at + Vector3(0, 1.2, 0.08), _flat("mane", Color("a6522f")), 0.9)
	_ball(0.22, at + Vector3(0, 1.3, 0.22), stone)
	_ball(0.13, at + Vector3(0, 1.26, 0.38), stone)

func _stupa(at: Vector3) -> void:
	var white := _surface("whitewash", 3, Color("e4ded2"), Color("c9c2b3"))
	for i in 3:
		var half := 6.0 - i * 0.9
		_box(Vector3(half * 2, 0.55, half * 2), at + Vector3(0, 0.55 * (i + 0.5), 0), white)
	var base_y := 1.65
	_ball(3.7, at + Vector3(0, base_y, 0), white, 0.78)
	# Harmika with the painted watching eyes on every face.
	var harmika := at + Vector3(0, base_y + 3.4, 0)
	_box(Vector3(1.9, 1.3, 1.9), harmika, _gold())
	for face in 4:
		var angle := face * PI / 2.0
		var normal := Vector3(sin(angle), 0, cos(angle))
		var tangent := Vector3(cos(angle), 0, -sin(angle))
		for eye_side in [-1.0, 1.0]:
			var spot: Vector3 = harmika + tangent * eye_side * 0.42 + Vector3(0, 0.08, 0)
			var eye := _ball(0.2, spot + normal * 0.96, _flat("eye_white", Color("f7f2e8")))
			eye.rotation.y = angle
			eye.scale = Vector3(1.4, 0.6, 0.2)
			var pupil := _ball(0.09, spot + normal * 1.0, _flat("ink", Color("141820")))
			pupil.rotation.y = angle
			pupil.scale = Vector3(1, 1, 0.3)
			var brow := _box(Vector3(0.55, 0.06, 0.04), spot + normal * 0.97 + Vector3(0, 0.26, 0), _flat("ink", Color("141820")))
			brow.rotation.y = angle
	# Thirteen gilded steps of the spire, parasol and pinnacle.
	var y := base_y + 4.05
	for step in 13:
		var radius := 1.05 - step * 0.065
		_frustum(radius, radius * 0.93, 0.22, at + Vector3(0, y, 0), _gold(), 12)
		y += 0.22
	_frustum(0.9, 0.12, 0.35, at + Vector3(0, y, 0), _gold(), 12)
	_ball(0.18, at + Vector3(0, y + 0.55, 0), _gold())
	# Prayer-flag lines radiate from the pinnacle down to the terrace edge.
	var peak := at + Vector3(0, y + 0.3, 0)
	for i in 6:
		var angle := -1.2 + i * 0.48
		_flag_line(peak, at + Vector3(sin(angle) * 7.5, 0.6, cos(angle) * 7.5), 0.7, 20)
	# A row of butter lamps along the lower terrace.
	for i in 13:
		_ball(0.07, at + Vector3(-5.4 + i * 0.9, 1.72, 5.1), _flat("flame", Color("ffc15a"), 4.0))

## Sunset lookout: stone parapet, a chautari resting platform with a pipal
## tree, and terraced hills stepping down the valley.
func _overlook() -> void:
	_box(Vector3(19, 0.9, 0.5), Vector3(0, 0.33, -10.0), _stone())
	for i in 9:
		_box(Vector3(0.5, 1.1, 0.6), Vector3(-8 + i * 2.0, 0.43, -10.0), _stone())
	var chautari := Vector3(6.0, -0.12, -13.0)
	for i in 2:
		_box(Vector3(3.6 - i * 0.6, 0.45, 3.6 - i * 0.6), chautari + Vector3(0, 0.45 * (i + 0.5), 0), _stone())
	_frustum(0.35, 0.25, 4.5, chautari + Vector3(0, 0.9, 0), _wood(), 10)
	var leaves := _flat("pipal", Color("3f6b2e"))
	var leaves_light := _flat("pipal_light", Color("5b8a36"))
	for i in 9:
		var angle := i * 0.8
		_ball(1.3 + (i % 3) * 0.4, chautari + Vector3(cos(angle) * 1.6, 5.2 + sin(i * 1.3) * 0.8, sin(angle) * 1.4), leaves if i % 2 == 0 else leaves_light, 0.8)
	var terrace_colors := [Color("5f8a3a"), Color("79a043"), Color("8faf4c")]
	var hills := [[Vector3(-26, -22, -70), 24.0], [Vector3(24, -21, -82), 28.0], [Vector3(-4, -26, -110), 34.0]]
	for h in hills.size():
		var hill: Array = hills[h]
		var center: Vector3 = hill[0]
		var radius: float = hill[1]
		# Stacked discs read as rice terraces from across the valley.
		for level in 12:
			var r := radius * (1.0 - level * 0.075)
			var disc := CylinderMesh.new()
			disc.top_radius = r
			disc.bottom_radius = r + 0.4
			disc.height = 1.4
			disc.radial_segments = 28
			_piece(disc, center + Vector3(0, level * 1.4, 0), _flat("terrace%d" % (level % 3), terrace_colors[level % 3]))
		for k in 5:
			var angle := k * 1.25 + h
			var level := 3 + k
			var r := radius * (1.0 - level * 0.075) - 1.0
			var house_at := center + Vector3(cos(angle) * r, level * 1.4 + 0.9, sin(angle) * r)
			_box(Vector3(1.4, 1.1, 1.0), house_at, _flat("cottage", Color("efe6d4")))
			var roof := PrismMesh.new()
			roof.size = Vector3(1.7, 0.6, 1.2)
			_piece(roof, house_at + Vector3(0, 0.85, 0), _flat("cottage_roof", Color("b3452f")))

# --- festive dressing ---------------------------------------------------

func _flag_poles(span: float, height: float, depth: float) -> void:
	var marigold := _flat("marigold", Color("f09a1c"))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.045
	pole.bottom_radius = 0.06
	pole.height = height + 0.3
	for side in [-1.0, 1.0]:
		_piece(pole, Vector3(side * span, (height + 0.3) * 0.5 - 0.12, depth), _wood())
		_ball(0.07, Vector3(side * span, height + 0.24, depth), _gold())
		for i in 14:
			var angle := i * 1.1
			_ball(0.055, Vector3(side * span + cos(angle) * 0.07, 0.9 + i * 0.1, depth + sin(angle) * 0.07), marigold)

## A sagging rope of five-colour prayer flags (lungta) from a to b.
func _flag_line(a: Vector3, b: Vector3, sag: float, count: int) -> void:
	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = 0.008
	rope_mesh.bottom_radius = 0.008
	rope_mesh.height = 1.0
	var flag_mesh := QuadMesh.new()
	flag_mesh.size = Vector2(0.2, 0.25)
	var run := b - a
	var heading := -atan2(run.z, run.x)
	var previous := a
	for i in count + 1:
		var t := float(i) / count
		var point := a.lerp(b, t) - Vector3(0, sin(t * PI) * sag, 0)
		if i > 0:
			var segment := _piece(rope_mesh, (previous + point) * 0.5, _flat("rope", Color("3b3129")))
			segment.basis = Basis(Quaternion(Vector3.UP, (point - previous).normalized()))
			segment.scale.y = previous.distance_to(point)
		previous = point
		if i == 0 or i == count:
			continue
		# Each flag hangs from a pivot on the rope so it swings from its top edge.
		var hanger := Node3D.new()
		hanger.position = point
		hanger.rotation.y = heading
		content.add_child(hanger)
		var color: Color = FLAG_COLORS[(i - 1) % FLAG_COLORS.size()]
		var flag := _piece(flag_mesh, Vector3(0, -0.135, 0), _flat("flag%d" % ((i - 1) % 5), color, 0.1 if night else 0.0), hanger)
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flags.append(hanger)

## Strings of paper lanterns cross the square for the night round.
func _lantern_strings() -> void:
	var paper := [_flat("lantern_red", Color("e0452f"), 2.2), _flat("lantern_gold", Color("f2a33a"), 2.2)]
	var rope := CylinderMesh.new()
	rope.top_radius = 0.01
	rope.bottom_radius = 0.01
	rope.height = 1.0
	var body := CylinderMesh.new()
	body.top_radius = 0.13
	body.bottom_radius = 0.13
	body.height = 0.3
	body.radial_segments = 12
	for line in [[-4.2, 3.9], [-9.0, 4.6], [-14.0, 4.9]]:
		var z: float = line[0]
		var height: float = line[1]
		var a := Vector3(-8.2, height, z)
		var b := Vector3(8.2, height, z)
		var previous := a
		for i in 17:
			var t := float(i) / 16.0
			var point := a.lerp(b, t) - Vector3(0, sin(t * PI) * 0.8, 0)
			if i > 0:
				var segment := _piece(rope, (previous + point) * 0.5, _flat("rope", Color("3b3129")))
				segment.basis = Basis(Quaternion(Vector3.UP, (point - previous).normalized()))
				segment.scale.y = previous.distance_to(point)
			previous = point
			if i % 2 == 1:
				var hanger := Node3D.new()
				hanger.position = point
				content.add_child(hanger)
				var lamp := _piece(body, Vector3(0, -0.22, 0), paper[(i / 2) % 2], hanger)
				lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_piece(body, Vector3(0, -0.06, 0), _flat("lantern_cap", Color("241a14")), hanger).scale = Vector3(0.8, 0.12, 0.8)
				lanterns.append(hanger)
	for x in [-4.5, 0.0, 4.5]:
		var glow := OmniLight3D.new()
		glow.position = Vector3(x, 3.0, -3.0)
		glow.light_color = Color("ffb66a")
		glow.omni_range = 7.0
		glow.set_meta("base", 0.9)
		glow.light_energy = 0.9
		content.add_child(glow)
		lamp_lights.append(glow)

## Clay butter lamps (diyo) on stone plinths at both ends of the dais.
func _butter_lamps() -> void:
	var clay := _flat("clay", Color("8a4b2c"))
	var flame := _flat("flame", Color("ffc15a"), 4.0)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.07
	bowl.bottom_radius = 0.045
	bowl.height = 0.05
	for side in [-1.0, 1.0]:
		var base := Vector3(side * 5.5, 0.2, -1.55)
		_box(Vector3(0.7, 0.42, 0.5), base + Vector3(0, -0.1, 0), _stone())
		for i in 5:
			var at := base + Vector3(-0.24 + i * 0.12, 0.135, 0.1 * ((i % 2) * 2 - 1))
			_piece(bowl, at, clay)
			_ball(0.022, at + Vector3(0, 0.055, 0), flame, 1.6).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var glow := OmniLight3D.new()
		glow.position = base + Vector3(0, 0.45, 0.2)
		glow.light_color = Color("ffb35c")
		glow.omni_range = 2.6 if night else 1.4
		glow.set_meta("base", 1.1 if night else 0.35)
		glow.light_energy = glow.get_meta("base")
		content.add_child(glow)
		lamp_lights.append(glow)

## A soft round dot for every particle quad (embers, sparks, dust): built
## once from a radial gradient, so motes read as points of light and haze
## rather than hard squares.
static var soft_dot_texture: Texture2D
static func soft_dot() -> Texture2D:
	if soft_dot_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.35, Color(1, 1, 1, 0.75))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 32
		texture.height = 32
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		soft_dot_texture = texture
	return soft_dot_texture

## Per-round atmosphere: courtyard dust, lantern embers, drifting rhododendron
## petals and, for the finale, sky lanterns rising behind the stupa.
func _ambience() -> void:
	var spec: Array = AMBIENCE[current_round]
	if spec[0] == "none":
		return
	var particles := CPUParticles3D.new()
	particles.name = "Ambience"
	particles.amount = spec[2]
	particles.lifetime = 9.0
	particles.preprocess = 9.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var quad := QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = soft_dot()
	quad.material = material
	particles.mesh = quad
	particles.color = spec[1]
	particles.gravity = Vector3.ZERO
	match spec[0]:
		"dust":
			quad.size = Vector2(0.025, 0.025)
			particles.position = Vector3(0, 1.4, -0.6)
			particles.emission_box_extents = Vector3(6, 1.4, 1.6)
			particles.direction = Vector3(1, 0.2, 0)
			particles.spread = 40
			particles.initial_velocity_min = 0.05
			particles.initial_velocity_max = 0.15
		"embers":
			quad.size = Vector2(0.05, 0.05)
			particles.position = Vector3(0, 0.3, -1.2)
			particles.emission_box_extents = Vector3(6, 0.3, 1.2)
			particles.direction = Vector3(0, 1, 0)
			particles.spread = 25
			particles.initial_velocity_min = 0.15
			particles.initial_velocity_max = 0.35
			particles.lifetime = 7.0
		"petals":
			quad.size = Vector2(0.09, 0.07)
			particles.position = Vector3(0, 4.2, -0.6)
			particles.emission_box_extents = Vector3(7, 0.2, 1.8)
			particles.gravity = Vector3(0.18, -0.32, 0)
			particles.angular_velocity_min = -160
			particles.angular_velocity_max = 160
			particles.angle_max = 360
			particles.lifetime = 11.0
		"sky_lanterns":
			quad.size = Vector2(0.14, 0.18)
			particles.position = Vector3(0, 2.0, -9.0)
			particles.emission_box_extents = Vector3(9, 0.4, 2.0)
			particles.direction = Vector3(0.15, 1, 0)
			particles.spread = 8
			particles.initial_velocity_min = 0.3
			particles.initial_velocity_max = 0.45
			particles.lifetime = 18.0
			particles.preprocess = 18.0
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content.add_child(particles)

## A short dip to black carries the journey from one arena into the next
## instead of a hard cut.
func _fade_in() -> void:
	if fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 40
		add_child(layer)
		fade = ColorRect.new()
		fade.color = Color("05070c")
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(fade)
	fade.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_property(fade, "modulate:a", 0.0, 0.7)
