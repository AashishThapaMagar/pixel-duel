extends Control
## The teaser, recorded with Godot's movie maker:
##   godot --path . --fixed-fps 30 --write-movie teaser.avi res://scenes/Trailer.tscn
## with a 1920x1080 window set in override.cfg for the recording.
##
##   0-7    Ananta's legs only, walking through dust in a pitch-black void,
##          shot the way Kurosawa shoots a walk: long lens, low camera, wind
##   7-15   Heritage Square as a whole, two shots joined by a dissolve
##   15-39  every fighter's face on black with their name, four seconds each
##   39-48  Ananta's face, appearing slowly out of black, then his name
##   48-55  WHO WON?  COMING SOON
## Every cut after the opening is a dissolve.
##
## Built to sit under a voice-over: drop audio/trailer/narration.ogg (or
## .wav / .mp3) and it plays from the first frame; audio/trailer/music.*
## plays under it.
const UI := preload("res://scripts/ui_kit.gd")
const ROSTER := preload("res://scripts/fighter_roster.gd")
const STAGE := preload("res://scripts/nepal_stage_3d.gd")
const SIZE := Vector2(960, 540)
const BAR := 62.0
const ANANTA := 6
const CUT := 4.0
const DISSOLVE := 1.0
const OPENING := 7.0
## Where each arena is filmed from: [eye from, look from, eye to, look to, fov].
## Heritage Square as a whole: a push down the square to the pagoda, then a
## slow track past the pagoda and its lions.
const ARENA_SHOTS := [
	[Vector3(0, 5.5, 9), Vector3(0, 3.5, -24), Vector3(0, 3.8, 1), Vector3(0, 4.5, -24), 52.0],
	[Vector3(-7, 2.2, -11), Vector3(-2, 4.5, -24), Vector3(6, 2.4, -12), Vector3(2, 4.5, -24), 50.0],
]

var world: Node3D
var camera: Camera3D
var actors: Array = []
var t := 0.0
var shot: Dictionary = {}
var shot_start := 0.0
var beats: Array = []
var next_beat := 0
var length := 0.0
var fade: ColorRect
var overlay: Control
var key_light: SpotLight3D
var rim_light: OmniLight3D
var walk_light: SpotLight3D
var dust: CPUParticles3D
var ground: MeshInstance3D
## The arenas play in their own viewport, one at a time.
var arena_viewport: SubViewport
var arena_view: TextureRect
var arena_stage: Node3D
var arena_camera: Camera3D
var arena_shot: Array = []
var arena_start := 0.0
var walk_from := Vector3.ZERO
var walk_to := Vector3.ZERO
var walk_start := -1.0
var walk_time := 1.0

func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A clean frame: no FPS counter (in memory only, not saved).
	Settings.show_fps = false
	_build_void()
	for i in ROSTER.PROFILES.size():
		actors.append(_spawn(i))
		_show(i, false)
	arena_viewport = SubViewport.new()
	arena_viewport.size = Vector2i(1920, 1080)
	arena_viewport.own_world_3d = true
	arena_viewport.msaa_3d = Viewport.MSAA_2X
	arena_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(arena_viewport)
	arena_view = TextureRect.new()
	arena_view.texture = arena_viewport.get_texture()
	# Expand first, or the rect keeps the 1920x1080 texture's own size.
	arena_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arena_view.stretch_mode = TextureRect.STRETCH_SCALE
	arena_view.size = SIZE
	arena_view.visible = false
	add_child(arena_view)
	_build_overlay()
	_build_beats()
	for kind in ["narration", "music"]:
		var stream := _audio("res://audio/trailer/" + kind)
		if stream != null:
			var player := AudioStreamPlayer.new()
			player.stream = stream
			player.volume_db = 0.0 if kind == "narration" else -8.0
			add_child(player)
			player.play()

static func _audio(base: String) -> AudioStream:
	for extension in [".ogg", ".wav", ".mp3"]:
		var path: String = base + extension
		if ResourceLoader.exists(path):
			return load(path)
		if FileAccess.file_exists(path):
			match extension:
				".ogg":
					return AudioStreamOggVorbis.load_from_file(path)
				".wav":
					return AudioStreamWAV.load_from_file(path)
				".mp3":
					return AudioStreamMP3.load_from_file(path)
	return null

## A pitch-black stage: only a dark floor catching one low light, and dust
## streaming through it on the wind.
func _build_void() -> void:
	world = Node3D.new()
	add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.1, 0.11, 0.14)
	environment.environment.ambient_light_energy = 0.15
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment.glow_enabled = true
	environment.environment.glow_intensity = 0.8
	environment.environment.glow_hdr_threshold = 0.9
	world.add_child(environment)
	ground = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.13, 0.11, 0.09)
	floor_material.roughness = 0.4
	ground.material_override = floor_material
	world.add_child(ground)
	# One warm light low and ahead of him, raking along the ground so the
	# boots, the coat hem and the dust catch it.
	walk_light = SpotLight3D.new()
	walk_light.light_color = Color("ffcf94")
	walk_light.light_energy = 7.0
	walk_light.spot_range = 14.0
	walk_light.spot_angle = 30.0
	walk_light.shadow_enabled = true
	world.add_child(walk_light)
	key_light = SpotLight3D.new()
	key_light.light_color = Color("ffe6c8")
	key_light.light_energy = 0.0
	key_light.spot_range = 8.0
	key_light.spot_angle = 22.0
	key_light.shadow_enabled = true
	world.add_child(key_light)
	rim_light = OmniLight3D.new()
	rim_light.light_color = Color("9fb8ff")
	rim_light.light_energy = 0.0
	rim_light.omni_range = 3.0
	world.add_child(rim_light)
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = 200
	world.add_child(camera)
	camera.current = true
	dust = CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.02)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.86, 0.66, 0.6)
	quad.material = material
	dust.mesh = quad
	dust.amount = 360
	dust.lifetime = 2.5
	dust.preprocess = 3.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(0.5, 0.45, 8)
	dust.position = Vector3(-5, 0.4, -8)
	dust.direction = Vector3(1, 0.05, 0.0)
	dust.spread = 7
	dust.gravity = Vector3.ZERO
	dust.initial_velocity_min = 3.5
	dust.initial_velocity_max = 6.0
	world.add_child(dust)

# ── Cast ─────────────────────────────────────────────────────────────────

func _spawn(index: int) -> Dictionary:
	var fighter: Node = load("res://scenes/Player.tscn").instantiate()
	var previous: Node = fighter.get_node("Visual")
	fighter.remove_child(previous)
	previous.free()
	var visual := preload("res://scripts/fighter_visual_3d.gd").new()
	visual.name = "Visual"
	var rig := Node3D.new()
	rig.scale = Vector3.ONE / 64.0
	world.add_child(rig)
	visual.world_root = rig
	fighter.add_child(visual)
	fighter.set_physics_process(false)
	world.add_child(fighter)
	fighter.controls_enabled = false
	fighter.collision_layer = 0
	fighter.hurtbox.collision_layer = 0
	fighter.apply_character(index)
	fighter.apply_style(load("res://resources/styles/action.tres"))
	fighter._update_animation()
	return {"fighter": fighter, "rig": rig}

func _show(index: int, on: bool) -> void:
	(actors[index].rig as Node3D).visible = on

func _place(index: int, at: Vector3, face: Vector3) -> void:
	var rig: Node3D = actors[index].rig
	rig.position = at + Vector3(0, 0.02, 0)
	var direction := face - at
	rig.rotation.y = atan2(-direction.z, direction.x)
	_show(index, true)

func _pose(index: int, clip: String) -> void:
	var animated = actors[index].fighter.get_node("Visual").get("animated")
	if animated != null:
		animated.pose_override = clip
		animated.replay()

func _head(index: int) -> Vector3:
	var animated = actors[index].fighter.get_node("Visual").get("animated")
	if animated != null and animated.active and animated.skeleton != null:
		var bone: int = animated.skeleton.find_bone("mixamorig_Head")
		if bone >= 0:
			return animated.skeleton.global_transform * animated.skeleton.get_bone_global_pose(bone).origin
	return (actors[index].rig as Node3D).position + Vector3(0, 1.6, 0)

## Where a standing fighter's face is: just below the top of their model,
## steadier than the animated head bone for portraits.
func _face(index: int) -> Vector3:
	var animated = actors[index].fighter.get_node("Visual").get("animated")
	var rig: Node3D = actors[index].rig
	var top := 1.75
	if animated != null and animated.character != null:
		var first := true
		for mesh: MeshInstance3D in animated.character.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			top = box.end.y if first else maxf(top, box.end.y)
			first = false
	# Skinned bounds sit above the rendered head; measured on the roster.
	return Vector3(rig.position.x, top - 0.29, rig.position.z)

func _hide_all() -> void:
	walk_start = -1.0
	for i in actors.size():
		_show(i, false)
		_pose(i, "")

func _walk(from: Vector3, to: Vector3, seconds: float) -> void:
	walk_from = from
	walk_to = to
	walk_start = t
	walk_time = seconds
	_place(ANANTA, from, to)
	_pose(ANANTA, "walk")

## Portrait lighting for a face on black: a warm key from the front-left
## (optionally fading up) and a cool rim behind.
func _light_face(index: int, energy: float, rise := 0.0) -> void:
	var head := _head(index)
	key_light.position = head + Vector3(0.9, 0.35, 1.3)
	key_light.look_at(head, Vector3.UP)
	rim_light.position = head + Vector3(-0.5, 0.3, -0.6)
	rim_light.light_energy = 1.4
	walk_light.light_energy = 0.0
	dust.emitting = false
	dust.visible = false
	ground.visible = false
	if rise > 0.0:
		key_light.light_energy = 0.0
		key_light.create_tween().tween_property(key_light, "light_energy", energy, rise).set_trans(Tween.TRANS_SINE)
	else:
		key_light.light_energy = energy

# ── Arenas ───────────────────────────────────────────────────────────────

func _arena(index: int) -> void:
	if is_instance_valid(arena_stage):
		arena_stage.queue_free()
	arena_stage = STAGE.new()
	arena_viewport.add_child(arena_stage)
	arena_stage.show_round(0)
	if not is_instance_valid(arena_camera):
		arena_camera = Camera3D.new()
		arena_camera.near = 0.1
		arena_camera.far = 500
		arena_viewport.add_child(arena_camera)
	arena_camera.current = true
	arena_shot = ARENA_SHOTS[index]
	arena_start = t
	arena_camera.fov = arena_shot[4]
	arena_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	arena_view.visible = true
	_update_arena_camera()

func _end_arena() -> void:
	if is_instance_valid(arena_stage):
		arena_stage.queue_free()
	arena_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	arena_view.visible = false
	arena_shot = []

func _update_arena_camera() -> void:
	if arena_shot.is_empty():
		return
	var k := clampf((t - arena_start) / (CUT + DISSOLVE), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	arena_camera.position = (arena_shot[0] as Vector3).lerp(arena_shot[2], k)
	arena_camera.look_at((arena_shot[1] as Vector3).lerp(arena_shot[3], k), Vector3.UP)

# ── Overlay ──────────────────────────────────────────────────────────────

func _build_overlay() -> void:
	for edge in [0.0, SIZE.y - BAR]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.position = Vector2(0, edge)
		bar.size = Vector2(SIZE.x, BAR)
		add_child(bar)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.size = SIZE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	overlay = Control.new()
	overlay.size = SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

func _clear_text() -> void:
	for child in overlay.get_children():
		child.queue_free()

## Arena name, small and quiet, low on the frame.
func _caption(text: String) -> void:
	_clear_text()
	var label := UI.eyebrow(overlay, text, Vector2(0, SIZE.y - BAR - 34), Vector2(SIZE.x, 20), UI.GOLD)
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate.a = 0.0
	var tween := label.create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(label, "modulate:a", 1.0, 0.8)

## COMING SOON drawn out letter by letter across a gold line, over black.
## The fighter's name and title, fading in low on the frame beside them.
func _name(index: int, delay := 0.7, slow := 0.8) -> void:
	_clear_text()
	var profile := ROSTER.profile(index)
	var box := Control.new()
	box.size = SIZE
	box.modulate.a = 0.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(box)
	var name_label := UI.heading(box, profile.name, Vector2(90, 350), Vector2(420, 66), 58, UI.WHITE, profile.color)
	var title := UI.eyebrow(box, String(profile.title).to_upper(), Vector2(94, 416), Vector2(420, 18), UI.GOLD)
	title.add_theme_font_size_override("font_size", 13)
	box.position.x = -24.0
	var tween := box.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(box, "modulate:a", 1.0, slow)
	tween.parallel().tween_property(box, "position:x", 0.0, slow + 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

## WHO WON? burns in, then COMING SOON is drawn out beneath a gold line.
func _coming_soon() -> void:
	_clear_text()
	var box := Control.new()
	box.size = SIZE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(box)
	var rule := ColorRect.new()
	rule.color = UI.GOLD
	rule.position = Vector2(SIZE.x / 2.0, 268)
	rule.size = Vector2(0, 2)
	box.add_child(rule)
	rule.position.y = 286
	var who := UI.heading(box, "WHO WON?", Vector2(0, 176), Vector2(SIZE.x, 100), 92, UI.GOLD, UI.CRIMSON)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.pivot_offset = Vector2(SIZE.x / 2.0, 50)
	who.scale = Vector2.ONE * 1.15
	who.modulate.a = 0.0
	var soon := UI.label(box, "C O M I N G     S O O N", Vector2(0, 300), Vector2(SIZE.x, 30), 22, UI.WHITE)
	soon.add_theme_font_override("font", UI.strong_font())
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soon.visible_ratio = 0.0
	var tween := box.create_tween()
	tween.tween_property(who, "modulate:a", 1.0, 1.0)
	tween.parallel().tween_property(who, "scale", Vector2.ONE, 1.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(rule, "size:x", 460.0, 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(rule, "position:x", SIZE.x / 2.0 - 230.0, 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(soon, "visible_ratio", 1.0, 1.2)
	tween.tween_interval(1.8)
	tween.tween_property(box, "modulate:a", 0.0, 0.8)

func _fade(to: float, seconds: float) -> void:
	fade.create_tween().tween_property(fade, "color:a", to, seconds)

## A dissolve: the outgoing frame, frozen, fades out over the new shot.
func _dissolve() -> void:
	var image := get_viewport().get_texture().get_image()
	var still := TextureRect.new()
	still.texture = ImageTexture.create_from_image(image)
	still.size = SIZE
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	still.stretch_mode = TextureRect.STRETCH_SCALE
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(still)
	move_child(still, overlay.get_index())
	var tween := still.create_tween()
	tween.tween_property(still, "modulate:a", 0.0, DISSOLVE).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(still.queue_free)

# ── Camera ───────────────────────────────────────────────────────────────

func _cut(spec: Dictionary) -> void:
	shot = spec
	shot_start = t
	camera.fov = float(spec.get("fov", 30.0))

func _update_camera() -> void:
	if shot.is_empty():
		return
	var k := clampf((t - shot_start) / float(shot.get("time", 4.0)), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var head := _face(shot.follow) if shot.get("portrait", false) else _head(shot.follow)
	camera.position = head + (shot.offset as Vector3).lerp(shot.get("offset_to", shot.offset), k)
	camera.look_at(head + (shot.aim as Vector3), Vector3.UP)

# ── Timeline ─────────────────────────────────────────────────────────────

func _at(time: float, action: Callable) -> void:
	beats.append([time, action])

func _build_beats() -> void:
	# 0-7: his legs only. A low camera tracks beside the stride, then a
	# long lens from the ground as the boots come toward us.
	_at(0.0, func():
		_walk(Vector3(0, 0, -12), Vector3(0, 0, -1), OPENING)
		_cut({"fov": 26, "follow": ANANTA, "offset": Vector3(2.4, -1.4, -0.2), "offset_to": Vector3(2.1, -1.35, 0.4), "aim": Vector3(0, -1.35, 0.3), "time": 3.8})
		_fade(0.0, 1.5))
	_at(3.8, func():
		_cut({"fov": 14, "follow": ANANTA, "offset": Vector3(0.25, -1.6, 5.0), "aim": Vector3(0, -1.2, 0), "time": 3.2}))
	# 7-23: the four arenas, dissolving one into the next.
	var at := OPENING
	for index in ARENA_SHOTS.size():
		_at(at, func():
			_dissolve()
			_hide_all()
			_arena(index)
			_caption(STAGE.ROUNDS[0].name))
		at += CUT
	# Every fighter's face on black.
	for index in ANANTA:
		_at(at, func():
			_dissolve()
			_clear_text()
			_end_arena()
			_hide_all()
			_place(index, Vector3.ZERO, Vector3(0.25, 0, 1))
			# Upright (the walk) so the head is up and the fists are down,
			# filmed from just below eye level.
			_pose(index, "walk")
			_light_face(index, 5.0)
			_cut({"fov": 22, "follow": index, "portrait": true, "offset": Vector3(0.32, -0.04, 1.6), "offset_to": Vector3(0.26, -0.04, 1.3), "aim": Vector3(0, 0.0, 0), "time": CUT})
			_name(index))
		at += CUT
	# Ananta: out of full black, his face appears slowly as the light
	# creeps up and the camera drifts in; his name comes last.
	_at(at, func():
		_clear_text()
		_fade(1.0, 0.8))
	_at(at + 0.9, func():
		_hide_all()
		_place(ANANTA, Vector3.ZERO, Vector3(0, 0, 1))
		_pose(ANANTA, "walk")
		_light_face(ANANTA, 5.5, 6.0)
		_fade(0.0, 2.5)
		_cut({"fov": 20, "follow": ANANTA, "portrait": true, "offset": Vector3(0.08, -0.04, 2.0), "offset_to": Vector3(0.04, -0.03, 1.1), "aim": Vector3(0, 0.0, 0), "time": 8.0})
		_name(ANANTA, 5.0, 1.4))
	at += 9.0
	_at(at - 0.6, func(): _fade(1.0, 0.6))
	_at(at, func():
		_hide_all()
		_coming_soon())
	length = at + 6.8
	beats.sort_custom(func(a, b): return a[0] < b[0])

func _process(delta: float) -> void:
	t += delta
	while next_beat < beats.size() and beats[next_beat][0] <= t:
		beats[next_beat][1].call()
		next_beat += 1
	var rig: Node3D = actors[ANANTA].rig
	if walk_start >= 0.0:
		var k := clampf((t - walk_start) / walk_time, 0.0, 1.0)
		rig.position = walk_from.lerp(walk_to, k) + Vector3(0, 0.02, 0)
		if k >= 1.0:
			walk_start = -1.0
			_pose(ANANTA, "idle")
		walk_light.position = rig.position + Vector3(1.2, 0.6, 3.0)
		walk_light.look_at(rig.position + Vector3(0, 0.3, 0), Vector3.UP)
		dust.position.z = rig.position.z
	if is_instance_valid(arena_stage):
		arena_stage.animate(delta)
		_update_arena_camera()
	_update_camera()
	if t >= length:
		get_tree().quit()
