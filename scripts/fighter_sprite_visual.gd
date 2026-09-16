extends Node2D
## Complete arcade poses, sampled once by the authoritative combat clock.
const REGIONS := preload("res://scripts/arcade_sprite_regions.gd")
const MOTION := preload("res://scripts/motion_sprite_regions.gd")
const KEY_SHADER := preload("res://scripts/arcade_sprite.gdshader")
const HEIGHTS := {"anug":130.0, "ish":134.0, "sab":143.0, "bib":113.0, "abhi":140.0, "sup":128.0, "anant":146.0}
# Contact, down, passing, swing; then the opposite leg. Never ping-pong.
const WALK_FRAMES := [24, 25, 26, 27, 28, 29, 30, 31]
const RUN_FRAMES := [32, 33, 34, 35, 36, 37, 38, 39]
const WALK_STRIDE := 128.0
const RUN_STRIDE := 184.0
static var sheets: Dictionary = {}
static var animations: Dictionary = {}
var fighter: Node
var sprite: AnimatedSprite2D
var atlas: AtlasTexture
var sheet: Texture2D
var loaded_id := ""
var frame_data: Dictionary = {}
var art_scale := 1.0
var render_height := 130.0
var walk_phase := 0.0
var last_x := 0.0
var last_clock := -1.0
var was_walking := false
var locomotion_running := false
var current_frame := -1
var clip_count := 0

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var key_material := ShaderMaterial.new()
	key_material.shader = KEY_SHADER
	sprite.material = key_material
	add_child(sprite)
	set_process(false)
	if fighter != null:
		_load_sheet()

func _load_sheet() -> void:
	if sprite == null or loaded_id == fighter.character_profile.id:
		return
	loaded_id = fighter.character_profile.id
	frame_data = REGIONS.DATA[loaded_id].duplicate(true)
	frame_data.frames.append_array(MOTION.DATA[loaded_id].frames)
	if not animations.has(loaded_id):
		var clips := SpriteFrames.new()
		clips.remove_animation("default")
		for clip_name in ["combat", "walk", "run"]:
			clips.add_animation(clip_name)
			clips.set_animation_loop(clip_name, clip_name != "combat")
			clips.set_animation_speed(clip_name, 12.0 if clip_name == "walk" else 16.0)
		for index in frame_data.frames.size():
			var data: Dictionary = frame_data.frames[index]
			var source: String = data.get("source", "arcade")
			var path := "res://assets/sprites/fighter/" + source + "/" + loaded_id + ".png"
			if not sheets.has(path):
				sheets[path] = load(path) if FileAccess.file_exists(path + ".import") else ImageTexture.create_from_image(Image.load_from_file(path))
			var texture := AtlasTexture.new()
			texture.atlas = sheets[path]
			var region: Array = data.region
			texture.region = Rect2(region[0], region[1], region[2], region[3])
			texture.filter_clip = true
			clips.add_frame("combat" if index < 24 else ("walk" if index < 32 else "run"), texture)
		animations[loaded_id] = clips
	sprite.sprite_frames = animations[loaded_id]
	sprite.pause()
	render_height = HEIGHTS[loaded_id]
	art_scale = render_height / float(frame_data.standing_height)
	sprite.scale = Vector2.ONE * art_scale
	reset_pose()
	_set_frame(12)

func sync_pose(owner_fighter: Node) -> void:
	fighter = owner_fighter
	_load_sheet()
	if sprite == null:
		return
	scale.x = float(fighter.facing)
	var walking: bool = fighter.state in [fighter.State.WALK, fighter.State.DASH]
	locomotion_running = walking and (fighter.running or (fighter.state == fighter.State.DASH and fighter._dash_dir == fighter.facing))
	if walking:
		if not was_walking:
			walk_phase = 0.0
			# Enter on contact; displacement from an attack/landing is not a step.
			last_x = fighter.position.x
		elif fighter.combat_time != last_clock:
			var travel: float = fighter.position.x - last_x
			if absf(travel) < 40.0:
				var stride := (RUN_STRIDE if locomotion_running else WALK_STRIDE) * render_height / 130.0
				var direction := -1.0 if fighter.velocity.x * fighter.facing < 0.0 else 1.0
				walk_phase = fposmod(walk_phase + absf(travel) / stride * direction, 1.0)
	# Repeated syncs can occur before movement finishes in this physics tick.
	# Keep that displacement for the next authoritative sample.
	if fighter.combat_time != last_clock or not walking:
		last_x = fighter.position.x
	last_clock = fighter.combat_time
	was_walking = walking
	_sample_frame()

func _process(_delta: float) -> void:
	# Callable by pause diagnostics; rendering never advances a second clock.
	pass

func _sample_frame() -> void:
	var frame := 12
	match fighter.state:
		fighter.State.WALK, fighter.State.DASH:
			var clip: Array = RUN_FRAMES if locomotion_running else WALK_FRAMES
			frame = clip[mini(int(walk_phase * clip.size()), clip.size() - 1)]
		fighter.State.BLOCK, fighter.State.BLOCKSTUN:
			frame = 13
		fighter.State.JUMP:
			frame = 14
		fighter.State.JUMP_START, fighter.State.LAND:
			frame = 12
		fighter.State.HITSTUN:
			frame = 21
		fighter.State.KO:
			frame = 23
		fighter.State.PUNCH, fighter.State.KICK:
			var attack_phase := 0 if fighter.attack_timer < fighter.attack_startup() else (1 if fighter.attack_timer < fighter.attack_startup() + fighter.attack_active_time() else 2)
			frame = (18 if fighter.state == fighter.State.KICK else 15) + attack_phase
			if fighter.attack_variant in ["dive", "grapple", "cartwheel", "taunt", "save", "feint"] or (loaded_id in ["ish", "bib", "anant"] and fighter.current_move.get("name", "") == fighter.available_moves().drive.name):
				frame = [15, 22, 17][attack_phase]
	_set_frame(frame)

func _set_frame(frame: int) -> void:
	if sprite == null or frame == current_frame:
		return
	current_frame = frame
	var data: Dictionary = frame_data.frames[frame]
	var region: Array = data.region
	var clip_name := "combat" if frame < 24 else ("walk" if frame < 32 else "run")
	var clip_frame := frame if frame < 24 else (frame - 24 if frame < 32 else frame - 32)
	sprite.animation = clip_name
	# Sample synchronously: no independent render clock, start delay or hit-stop drift.
	sprite.set_frame_and_progress(clip_frame, 0.0)
	atlas = sprite.sprite_frames.get_frame_texture(clip_name, clip_frame)
	sheet = atlas.atlas
	art_scale = render_height / float(data.get("standing_height", frame_data.standing_height))
	sprite.scale = Vector2.ONE * art_scale
	sprite.material.set_shader_parameter("chroma_key", frame < 24)
	for index in range(maxi(clip_count, data.exclusions.size())):
		var bounds := Vector4.ZERO
		if index < data.exclusions.size():
			var values: Array = data.exclusions[index]
			bounds = Vector4(values[0], values[1], values[2], values[3])
		sprite.material.set_shader_parameter("clip_%d" % index, bounds)
	clip_count = data.exclusions.size()
	sprite.position = Vector2(float(region[2]) * 0.5 - float(data.pivot_x), float(region[3]) * 0.5 - float(data.floor_y)) * art_scale

func reset_pose() -> void:
	walk_phase = 0.0
	was_walking = false
	locomotion_running = false
	current_frame = -1
	last_clock = -1.0
	rotation = 0.0
	position = Vector2.ZERO
	if fighter != null:
		last_x = fighter.position.x
