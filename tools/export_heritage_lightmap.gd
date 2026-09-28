extends SceneTree
## Writes the scene that Heritage Square's baked lighting is made in.
##
## LightmapGI can only bake inside the Godot editor, on a machine with a GPU,
## and the square is assembled by code at run time (nepal_stage_3d.gd merges
## the arena model and Meshy props into ~20 batches). So baking is two steps:
##
## 1. Export (headless, 5-15 minutes; run again after any change to
##    the square's scenery, then bake again):
##      godot --headless --path . -s res://tools/export_heritage_lightmap.gd
##    This builds round 0 exactly as the game does and saves it as
##    res://assets/lightmaps/heritage_square.scn: the merged batches with a
##    lightmap UV2 unwrap (GI mode Static; the distant mountains and the dense
##    facade props are left out and stay real time), bake-only copies of every
##    lamp, fill light and the moon (BakeLights, indirect only: direct light
##    stays real time in the game), flat stand-in materials
##    carrying each surface's average colour and glow, and a LightmapGI node
##    with the night-sky ambient as its environment.
## 2. Bake (in the editor, about a minute on Intel UHD graphics). The baker
##    needs a RenderingDevice, which a Compatibility editor does not create
##    (Bake finishes in 0 s with nothing written), so open the editor for
##    this one session with the Forward+ backend; the project setting and the
##    game stay Compatibility, which renders the result:
##      godot --editor --rendering-method forward_plus --path .
##    Open res://assets/lightmaps/heritage_square.scn, select its LightmapGI
##    node, click Bake Lightmaps in the 3D toolbar, and when asked for the
##    bake file keep res://assets/lightmaps/heritage_square.lmbake (the game
##    looks for exactly that name). Save the scene (Ctrl+S) and commit
##    heritage_square.scn, .lmbake, .exr and .exr.import.
##
## At run time nepal_stage_3d.gd (_apply_baked_lighting) uses the scene only
## if it has light data and its geometry signature matches the scenery it
## just built; otherwise the square keeps its live lighting exactly as before.
## Both arena-texture settings currently merge the scenery identically, so one
## bake serves both; the exporter says so, or warns when that stops being true.
const STAGE := preload("res://scripts/nepal_stage_3d.gd")
const ROUND := 0
## Lightmap texel size in metres (LightmapGI.texel_scale multiplies density).
## 0.2 keeps the whole square in one or two 4096 pages.
const TEXEL_SIZE := 0.2
## Batches this far behind the square (the Meshy mountain range) are too big
## and too distant to be worth lightmap space; they stay real-time lit.
const FAR_Z := -60.0
## The dense Meshy facade props (every carved doorway, every window: ~300k
## and ~220k vertices merged) would take minutes to unwrap and tens of MB
## of UV2. They sit flat on the walls, so they keep the plain ambient.
const MAX_BAKED_VERTICES := 100000

var proxies: Dictionary = {}
var average_cache: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/lightmaps"))
	var settings := root.get_node_or_null("Settings")
	var saved_detail: bool = settings.detailed_textures if settings != null else true
	var signatures := {}
	var result := OK
	# Standard textures first, only to compare its geometry; then the
	# photo-real build (the default, High) is exported.
	for detailed in [false, true]:
		if settings != null:
			settings.detailed_textures = detailed
		var stage: Node3D = STAGE.new()
		stage.use_baked_lighting = false
		root.add_child(stage)
		stage.show_round(ROUND)
		signatures[detailed] = stage.batch_signature()
		if detailed:
			var path: String = STAGE.LIGHTMAP_SCENES[ROUND]
			var started := Time.get_ticks_msec()
			result = export_scene(stage, path)
			print("%s: %s (%.1f s)" % [path, error_string(result), (Time.get_ticks_msec() - started) / 1000.0])
		root.remove_child(stage)
		stage.free()
	if settings != null:
		settings.detailed_textures = saved_detail
	if signatures[false] == signatures[true]:
		print("Both arena-texture settings build this geometry: one bake serves both.")
	else:
		push_warning("STANDARD arena textures merge the scenery differently; they will keep live lighting.")
	print("Now open the scene in the editor, select LightmapGI, click Bake Lightmaps and save." if result == OK else "EXPORT FAILED")
	quit(0 if result == OK else 1)

func export_scene(stage: Node3D, path: String) -> Error:
	var scene := Node3D.new()
	scene.name = "HeritageLightmap"
	scene.set_meta("signature", stage.batch_signature())
	scene.set_meta("detailed_textures", stage.built_detailed)
	var content: Node3D = stage.content
	var to_content := content.global_transform.affine_inverse()
	for batch: MeshInstance3D in stage.batches:
		# Batches left out of the scene stay as the game builds them.
		var bounds: AABB = batch.mesh.get_aabb()
		var vertices: int = batch.mesh.surface_get_array_len(0)
		if bounds.end.z < FAR_Z or bounds.size.length() > 400.0 or vertices > MAX_BAKED_VERTICES:
			print("  %s (%d vertices) stays real-time lit" % [batch.name, vertices])
			continue
		print("  unwrapping %s (%d vertices)..." % [batch.name, vertices])
		# Welding shared vertices first gives the unwrapper connected
		# surfaces to chart; a triangle soup becomes thousands of specks.
		var welder := SurfaceTool.new()
		welder.create_from(batch.mesh, 0)
		welder.index()
		var mesh := welder.commit()
		if mesh.lightmap_unwrap(Transform3D.IDENTITY, TEXEL_SIZE) != OK:
			push_warning("Could not unwrap %s; it stays real-time lit." % batch.name)
			continue
		var copy := MeshInstance3D.new()
		copy.name = batch.name
		copy.mesh = mesh
		copy.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		copy.cast_shadow = batch.cast_shadow
		copy.material_override = proxy(batch.material_override)
		scene.add_child(copy)
	# Bake-only lights, removed again at run time. Dynamic bake mode bakes
	# only their bounce: direct light stays real time in the game (flicker,
	# specular on the wet paving, fighters). The lamps trace no shadows, as
	# they light the square live: each sits inside its lantern head or
	# against the pagoda steps, where traced shadows would snuff them out.
	var lights := Node3D.new()
	lights.name = "BakeLights"
	scene.add_child(lights)
	for light: Light3D in content.find_children("*", "Light3D", true, false):
		if not light.is_visible_in_tree():
			continue
		var copy: Light3D = light.duplicate(0)
		for child in copy.get_children():
			copy.remove_child(child)
			child.free()
		copy.transform = to_content * light.global_transform
		copy.light_energy = light.get_meta("base", light.light_energy)
		copy.light_bake_mode = Light3D.BAKE_DYNAMIC
		copy.shadow_enabled = false
		lights.add_child(copy)
	var moon: DirectionalLight3D = stage.sun.duplicate(0)
	moon.name = "Moon"
	moon.transform = to_content * stage.sun.global_transform
	moon.light_bake_mode = Light3D.BAKE_DYNAMIC
	moon.shadow_enabled = true
	lights.add_child(moon)
	var gi := LightmapGI.new()
	gi.name = "LightmapGI"
	gi.quality = LightmapGI.BAKE_QUALITY_MEDIUM
	gi.bounces = 3
	gi.use_denoiser = true
	gi.directional = false
	gi.interior = false
	gi.texel_scale = 1.0
	gi.max_texture_size = 4096
	# Fighters keep their live lights and ambient, so no probes: probe light
	# would double the static lamps on them.
	gi.generate_probes_subdiv = LightmapGI.GENERATE_PROBES_DISABLED
	var mood: Array = STAGE.MOODS[ROUND]
	gi.environment_mode = LightmapGI.ENVIRONMENT_MODE_CUSTOM_COLOR
	gi.environment_custom_color = mood[4]
	gi.environment_custom_energy = mood[5]
	scene.add_child(gi)
	_own(scene, scene)
	var packed := PackedScene.new()
	var result := packed.pack(scene)
	if result == OK:
		result = ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS)
	scene.free()
	return result

func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)

## A flat stand-in with the surface's average colour and glow: bounce light
## only needs the average, and it keeps the scene free of embedded textures.
## The game puts the real material back on each batch.
func proxy(material: Material) -> StandardMaterial3D:
	if proxies.has(material):
		return proxies[material]
	var flat := StandardMaterial3D.new()
	var albedo := Color(0.5, 0.5, 0.5)
	if material is StandardMaterial3D:
		albedo = material.albedo_color * average(material.albedo_texture)
		flat.cull_mode = material.cull_mode
		if material.emission_enabled:
			flat.emission_enabled = true
			flat.emission = material.emission * average(material.emission_texture)
			flat.emission_energy_multiplier = material.emission_energy_multiplier
	elif material is ShaderMaterial:
		var tint: Variant = material.get_shader_parameter("tint")
		var tint_color: Color = tint if tint is Color else Color.WHITE
		for texture_name in ["albedo_map", "color_texture"]:
			var texture: Variant = material.get_shader_parameter(texture_name)
			if texture is Texture2D:
				albedo = average(texture) * tint_color
		var base: Variant = material.get_shader_parameter("base_color")
		if base is Color:
			albedo = base
		elif base is Vector3:
			albedo = Color(base.x, base.y, base.z)
	albedo.a = 1.0
	flat.albedo_color = Color(minf(albedo.r, 1.0), minf(albedo.g, 1.0), minf(albedo.b, 1.0))
	flat.roughness = 0.9
	proxies[material] = flat
	return flat

func average(texture: Texture2D) -> Color:
	if texture == null:
		return Color.WHITE
	if average_cache.has(texture):
		return average_cache[texture]
	var color := Color.WHITE
	var image := texture.get_image()
	if image != null:
		image = image.duplicate()
		if image.is_compressed():
			image.decompress()
		image.resize(1, 1, Image.INTERPOLATE_BILINEAR)
		color = image.get_pixel(0, 0)
	average_cache[texture] = color
	return color
