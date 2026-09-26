extends RefCounted
## Distant scenery behind the Nepal arenas, generated once and shared by
## every round: terraced green foothills, forested ridges and the snowy
## Himalaya. Surfaces are Poly Haven CC0 aerial scans (snow_field_aerial,
## aerial_rocks_02, aerial_grass_rock) blended by height and slope in
## himalaya_terrain.gdshader, which also fades each layer into the sky haze.
const TERRAIN_SHADER := preload("res://scripts/himalaya_terrain.gdshader")
const TEXTURES := "res://assets/arenas/textures/"
## Layers: [name, inner radius, outer radius, base height, peak height,
## angular steps, radial steps, noise seed, snow line, ridged].
const LAYERS := [
	["Foothills", 62.0, 190.0, -1.5, 13.0, 220, 70, 11, 999.0, false],
	["Himalaya", 280.0, 470.0, 4.0, 92.0, 260, 60, 29, 34.0, true],
]
## Only the arc behind the arena is built; the sides are hidden by houses.
const ARC := 1.45
static var meshes: Dictionary = {}

## Builds the backdrop for one round; the lighting mood only changes the
## material, so the meshes are generated once and cached.
static func build(horizon: Color, night: bool, sunset: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "HimalayaBackdrop"
	for layer in LAYERS:
		var node := MeshInstance3D.new()
		node.name = layer[0]
		if not meshes.has(layer[0]):
			meshes[layer[0]] = _terrain(layer)
		node.mesh = meshes[layer[0]]
		node.material_override = _material(layer, horizon, night, sunset)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.extra_cull_margin = 50.0
		root.add_child(node)
	return root

static func _terrain(layer: Array) -> ArrayMesh:
	var inner: float = layer[1]
	var outer: float = layer[2]
	var base: float = layer[3]
	var peak: float = layer[4]
	var steps_a: int = layer[5]
	var steps_r: int = layer[6]
	var ridged: bool = layer[9]
	var noise := FastNoiseLite.new()
	noise.seed = layer[7]
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED if ridged else FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 6 if ridged else 5
	noise.frequency = 0.0055 if ridged else 0.012
	noise.fractal_gain = 0.5
	var detail := FastNoiseLite.new()
	detail.seed = layer[7] + 7
	detail.frequency = 0.004
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array[Vector3] = []
	for j in steps_r + 1:
		var t := float(j) / steps_r
		var radius := lerpf(inner, outer, t)
		for i in steps_a + 1:
			var angle := lerpf(-ARC, ARC, float(i) / steps_a)
			var x := sin(angle) * radius
			var z := -cos(angle) * radius
			var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
			var h: float
			if ridged:
				# Sharp ridged crests, strongest in the middle of the band so
				# the range rises out of haze and falls away behind.
				var massif := smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(0.75, 1.0, t) * 0.5)
				var swell := detail.get_noise_2d(x, z) * 0.5 + 0.5
				h = base + pow(n, 1.6) * (peak - base) * massif * (0.55 + 0.6 * swell)
			else:
				# Rolling hills that climb away from the town.
				var rise := smoothstep(0.0, 0.6, t)
				h = base + n * (peak - base) * (0.25 + 0.75 * rise)
			# Fade the edges of the arc down so no seam shows at the sides.
			h = lerpf(base - 4.0, h, smoothstep(0.0, 0.08, 1.0 - absf(angle) / ARC))
			grid.append(Vector3(x, h, z))
	var row := steps_a + 1
	for j in steps_r:
		for i in steps_a:
			var a := grid[j * row + i]
			var b := grid[j * row + i + 1]
			var c := grid[(j + 1) * row + i]
			var d := grid[(j + 1) * row + i + 1]
			for v in [a, c, b, b, c, d]:
				tool.add_vertex(v)
	tool.index()
	tool.generate_normals()
	return tool.commit()

static func _material(layer: Array, horizon: Color, night: bool, sunset: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	material.set_shader_parameter("snow_map", load(TEXTURES + "snow_field_aerial/snow_field_aerial_diff_1k.jpg"))
	material.set_shader_parameter("rock_map", load(TEXTURES + "aerial_rocks_02/aerial_rocks_02_diff_1k.jpg"))
	material.set_shader_parameter("grass_map", load(TEXTURES + "aerial_grass_rock/aerial_grass_rock_diff_1k.jpg"))
	material.set_shader_parameter("snow_line", layer[8])
	material.set_shader_parameter("terraces", 1.0 if layer[0] == "Foothills" else 0.0)
	material.set_shader_parameter("haze_color", horizon)
	# Far layers dissolve more into the sky; night haze is thinner.
	var far: bool = layer[9]
	material.set_shader_parameter("haze_start", 60.0 if not far else 180.0)
	material.set_shader_parameter("haze_density", (0.0045 if not far else 0.0032) * (0.7 if night else 1.0))
	material.set_shader_parameter("haze_max", 0.55 if night else (0.4 if sunset else 0.72))
	return material
