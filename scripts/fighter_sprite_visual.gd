extends Node2D
## Complete arcade poses, sampled once by the authoritative combat clock.
const REGIONS := preload("res://scripts/arcade_sprite_regions.gd")
const KEY_SHADER := preload("res://scripts/arcade_sprite.gdshader")
const HEIGHTS := {"anug":130.0, "ish":134.0, "sab":143.0, "bib":113.0, "abhi":140.0, "sup":128.0, "anant":146.0}
# Return through intermediate poses instead of jumping from narrow to wide.
const WALK_FRAMES := [0, 1, 2, 1, 3, 4, 5, 4]
const RUN_FRAMES := [6, 7, 8, 7, 9, 10, 11, 10]
const WALK_STRIDE := 100.0
const RUN_STRIDE := 170.0
static var sheets: Dictionary = {}
var fighter: Node
var sprite: Sprite2D
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

func _ready() -> void:
	sprite = Sprite2D.new()
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
	var path := "res://assets/sprites/fighter/arcade/" + loaded_id + ".png"
	if not sheets.has(loaded_id):
		if FileAccess.file_exists(path + ".import"):
			sheets[loaded_id] = load(path)
		else:
			sheets[loaded_id] = ImageTexture.create_from_image(Image.load_from_file(path))
	sheet = sheets[loaded_id]
	frame_data = REGIONS.DATA[loaded_id]
	atlas = AtlasTexture.new()
	atlas.atlas = sheet
	atlas.filter_clip = true
	sprite.texture = atlas
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
	if atlas == null or frame == current_frame:
		return
	current_frame = frame
	var data: Dictionary = frame_data.frames[frame]
	var region: Array = data.region
	atlas.region = Rect2(region[0], region[1], region[2], region[3])
	for index in range(16):
		var bounds := Vector4.ZERO
		if index < data.exclusions.size():
			var values: Array = data.exclusions[index]
			bounds = Vector4(values[0], values[1], values[2], values[3])
		sprite.material.set_shader_parameter("clip_%d" % index, bounds)
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
