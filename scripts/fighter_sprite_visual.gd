extends Node2D
## Standing artwork for every combat pose; walking/running deforms that same
## art's legs procedurally instead of switching to separately-drawn frames —
## keeps the character visually identical whether idle or moving.
const REGIONS := preload("res://scripts/arcade_sprite_regions.gd")
const KEY_SHADER := preload("res://scripts/arcade_sprite.gdshader")
const GAIT := preload("res://scripts/fighter_locomotion.gd")
const HEIGHTS := {"anug":130.0, "ish":134.0, "sab":143.0, "bib":113.0, "abhi":140.0, "sup":128.0, "anant":146.0}
# Hip/knee/ankle landmarks measured directly on each character's own idle
# (frame 12) art, as fractions of that frame's region box: [waist, crotch,
# split_x, [side0 hip_x,hip_y,knee_x,knee_y,ankle_x,ankle_y], [side1 ...]].
# fighter_locomotion.gd's own FIT table was calibrated for the older,
# separately-drawn nepali art and no longer matches this art's proportions.
const GAIT_FIT := {
	"anug":  [0.469, 0.565, 0.498, [0.388, 0.494, 0.274, 0.690, 0.090, 0.891], [0.607, 0.494, 0.746, 0.661, 0.910, 0.870]],
	"ish":   [0.565, 0.625, 0.460, [0.308, 0.597, 0.213, 0.766, 0.071, 0.935], [0.616, 0.597, 0.782, 0.726, 0.924, 0.895]],
	"sab":   [0.494, 0.628, 0.509, [0.347, 0.502, 0.278, 0.732, 0.069, 0.891], [0.694, 0.502, 0.810, 0.732, 0.926, 0.879]],
	"bib":   [0.525, 0.615, 0.481, [0.344, 0.533, 0.238, 0.717, 0.106, 0.873], [0.661, 0.533, 0.820, 0.738, 0.926, 0.873]],
	"abhi":  [0.594, 0.730, 0.492, [0.330, 0.615, 0.228, 0.799, 0.102, 0.934], [0.660, 0.615, 0.787, 0.799, 0.888, 0.934]],
	"sup":   [0.531, 0.694, 0.476, [0.288, 0.571, 0.216, 0.776, 0.048, 0.931], [0.673, 0.571, 0.817, 0.776, 0.938, 0.918]],
	"anant": [0.481, 0.628, 0.490, [0.306, 0.502, 0.255, 0.732, 0.051, 0.891], [0.663, 0.502, 0.816, 0.732, 0.944, 0.879]],
}
# Shoulder/elbow/wrist landmarks, same idle art and fraction convention as
# GAIT_FIT: [side0 shoulder_x,shoulder_y,elbow_x,elbow_y,wrist_x,wrist_y],
# [side1 ...]. Side0 is the far arm (mostly tucked behind the torso in this
# 3/4 guard), side1 the near arm.
const ARM_FIT := {
	"anug":  [[0.338, 0.201, 0.299, 0.377, 0.423, 0.293], [0.637, 0.201, 0.736, 0.368, 0.920, 0.301]],
	"ish":   [[0.370, 0.222, 0.308, 0.383, 0.427, 0.323], [0.664, 0.222, 0.758, 0.363, 0.900, 0.323]],
	"sab":   [[0.440, 0.188, 0.324, 0.314, 0.486, 0.272], [0.718, 0.188, 0.833, 0.335, 0.949, 0.272]],
	"bib":   [[0.344, 0.225, 0.265, 0.389, 0.423, 0.348], [0.635, 0.225, 0.767, 0.369, 0.952, 0.348]],
	"abhi":  [[0.381, 0.279, 0.482, 0.410, 0.254, 0.369], [0.533, 0.266, 0.660, 0.389, 0.761, 0.266]],
	"sup":   [[0.433, 0.245, 0.385, 0.388, 0.481, 0.327], [0.721, 0.245, 0.817, 0.367, 0.913, 0.306]],
	"anant": [[0.383, 0.209, 0.459, 0.356, 0.306, 0.293], [0.485, 0.188, 0.587, 0.335, 0.740, 0.230]],
}
static var sheets: Dictionary = {}
static var animations: Dictionary = {}
var fighter: Node
var sprite: AnimatedSprite2D
var gait: Node2D
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
var retreat_walk := false
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
	gait = GAIT.new()
	gait.hide()
	add_child(gait)
	set_process(false)
	if fighter != null:
		_load_sheet()

func _load_sheet() -> void:
	if sprite == null or loaded_id == fighter.character_profile.id:
		return
	loaded_id = fighter.character_profile.id
	frame_data = REGIONS.DATA[loaded_id]
	var path := "res://assets/sprites/fighter/arcade/" + loaded_id + ".png"
	if not sheets.has(path):
		sheets[path] = load(path) if FileAccess.file_exists(path + ".import") else ImageTexture.create_from_image(Image.load_from_file(path))
	if not animations.has(loaded_id):
		var clips := SpriteFrames.new()
		clips.remove_animation("default")
		clips.add_animation("combat")
		clips.set_animation_loop("combat", false)
		for index in frame_data.frames.size():
			var data: Dictionary = frame_data.frames[index]
			var texture := AtlasTexture.new()
			texture.atlas = sheets[path]
			var region: Array = data.region
			texture.region = Rect2(region[0], region[1], region[2], region[3])
			texture.filter_clip = true
			clips.add_frame("combat", texture)
		animations[loaded_id] = clips
	sprite.sprite_frames = animations[loaded_id]
	sprite.pause()
	render_height = HEIGHTS[loaded_id]
	art_scale = render_height / float(frame_data.standing_height)
	sprite.scale = Vector2.ONE * art_scale
	# Rig the leg/arm-deformation mesh against the same standing (idle) art
	# the sprite uses at rest — walking/running bends this exact artwork's
	# limbs rather than swapping to a different drawing.
	gait.configure(sheets[path], frame_data.frames[12], loaded_id, render_height, frame_data.standing_height, GAIT_FIT[loaded_id], ARM_FIT[loaded_id])
	var limb_material := ShaderMaterial.new()
	limb_material.shader = KEY_SHADER
	for i in [0, 1, 3, 4]:
		gait.meshes[i].material = limb_material
	# The torso mesh still carries the original, now-unmoving arm pixels
	# underneath the new deforming arm meshes — clip them out so the two
	# don't double-render (chroma-key alone can't punch a hole mid-texture).
	var torso_material := ShaderMaterial.new()
	torso_material.shader = KEY_SHADER
	var sheet_size: Vector2 = sheets[path].get_size()
	for i in gait.arm_clip_regions.size():
		var box: Vector4 = gait.arm_clip_regions[i]
		torso_material.set_shader_parameter("clip_%d" % i, Vector4(box.x / sheet_size.x, box.y / sheet_size.y, box.z / sheet_size.x, box.w / sheet_size.y))
	gait.meshes[2].material = torso_material
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
	var stride: float = gait.cycle_length(locomotion_running)
	if walking:
		var retreat: bool = fighter.velocity.x * fighter.facing < -1.0
		if not was_walking:
			walk_phase = 0.0
			retreat_walk = retreat
			# Enter on contact; displacement from an attack/landing is not a step.
			last_x = fighter.position.x
		elif fighter.combat_time != last_clock:
			if retreat != retreat_walk:
				# Reflect the step phase so reversing direction keeps each foot
				# at the same point in its support or recovery arc.
				walk_phase = fposmod(lerpf(0.72, 0.46, 1.0 if locomotion_running else 0.0) - walk_phase - 0.5, 1.0)
				retreat_walk = retreat
			var travel: float = fighter.position.x - last_x
			if absf(travel) < 40.0:
				walk_phase = fposmod(walk_phase + absf(travel) / stride, 1.0)
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
	if fighter.state in [fighter.State.WALK, fighter.State.DASH]:
		_set_walk_pose()
		return
	sprite.show()
	gait.hide()
	var frame := 12
	match fighter.state:
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

func _set_walk_pose() -> void:
	current_frame = -1
	sprite.hide()
	gait.show()
	scale.x = float(fighter.facing)
	gait.sample(walk_phase, locomotion_running, gait.cycle_length(locomotion_running), 1.0, retreat_walk)

func _set_frame(frame: int) -> void:
	if sprite == null or frame == current_frame:
		return
	current_frame = frame
	var data: Dictionary = frame_data.frames[frame]
	var region: Array = data.region
	sprite.animation = "combat"
	# Sample synchronously: no independent render clock, start delay or hit-stop drift.
	sprite.set_frame_and_progress(frame, 0.0)
	atlas = sprite.sprite_frames.get_frame_texture("combat", frame)
	sheet = atlas.atlas
	sprite.material.set_shader_parameter("chroma_key", true)
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
	retreat_walk = false
	locomotion_running = false
	current_frame = -1
	last_clock = -1.0
	rotation = 0.0
	position = Vector2.ZERO
	if gait != null:
		gait.hide()
	if fighter != null:
		last_x = fighter.position.x
