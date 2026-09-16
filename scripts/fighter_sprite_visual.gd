extends "res://scripts/fighter_visual.gd"
## Illustrated character atlases use the combat clock, not a looping attack timer.
var sprite: Sprite2D
var atlas: AtlasTexture
var sheet: Texture2D
var loaded_id: String = ""
var last_x: float = 0.0
var render_height: float = 130.0
var frame_data: Dictionary = {}
var art_scale: float = 1.0
var walk_phase: float = 0.0
var was_walking: bool = false
const RUN_STRIDE := 140.0
const WALK_STRIDE := 115.0
var locomotion_running: bool = false
var movement_blend: float = 0.0
var run_blend: float = 0.0
var retreat_walk: bool = false
var current_stride: float = 80.0
var gait: Node2D
const REGIONS := preload("res://scripts/fighter_sprite_regions.gd")
const HEIGHTS := {"anug":130.0, "ish":134.0, "sab":143.0, "bib":113.0, "abhi":140.0, "sup":128.0, "anant":146.0}

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	gait = preload("res://scripts/fighter_locomotion.gd").new()
	add_child(gait)
	gait.hide()
	if fighter != null:
		_load_sheet()

func _load_sheet() -> void:
	if sprite == null or loaded_id == fighter.character_profile.id:
		return
	loaded_id = fighter.character_profile.id
	var path := "res://assets/sprites/fighter/nepali/" + loaded_id + ".png"
	frame_data = REGIONS.DATA[loaded_id]
	if FileAccess.file_exists(path + ".import") or not FileAccess.file_exists(path):
		sheet = load(path)
	else:
		# Allows local first launch before the editor has imported new PNGs.
		var bitmap := Image.load_from_file(path)
		if bitmap == null:
			push_error("Missing fighter sheet: " + path)
			return
		sheet = ImageTexture.create_from_image(bitmap)
	atlas = AtlasTexture.new()
	atlas.atlas = sheet
	atlas.filter_clip = true
	sprite.texture = atlas
	render_height = HEIGHTS[loaded_id]
	art_scale = render_height / float(frame_data.standing_height)
	gait.configure(sheet, frame_data.frames[1], loaded_id, render_height, float(frame_data.standing_height))
	sprite.scale = Vector2.ONE * art_scale
	last_x = fighter.position.x
	_set_frame(0)

func sync_pose(owner_fighter: Node) -> void:
	super.sync_pose(owner_fighter)
	_load_sheet()
	_sample_frame()

func _process(delta: float) -> void:
	if fighter == null or fighter.combat_paused:
		return
	if fighter.hitstop_remaining > 0.0:
		return
	# Retain joint pose data for diagnostics, but render the authored sprite only.
	super._process(delta)
	rotation = 0.0
	position = Vector2.ZERO
	var travel: float = fighter.position.x - last_x
	var walking: bool = fighter.state in [fighter.State.WALK, fighter.State.DASH]
	locomotion_running = fighter.running or (fighter.state == fighter.State.DASH and fighter._dash_dir == fighter.facing)
	movement_blend = move_toward(movement_blend,1.0 if walking else 0.0,delta*8.0)
	run_blend = move_toward(run_blend,1.0 if locomotion_running else 0.0,delta*6.0)
	current_stride = lerpf(gait.cycle_length(false),gait.cycle_length(true),run_blend)
	if walking:
		var retreat: bool = fighter.velocity.x * fighter.facing < -1.0
		if retreat != retreat_walk:
			# Reflect the step phase so reversing direction keeps each foot
			# at the same point in its support or recovery arc.
			walk_phase = fposmod(lerpf(0.72,0.46,run_blend)-walk_phase-0.5,1.0)
			retreat_walk = retreat
		if absf(travel) < 40.0:
			walk_phase = fposmod(walk_phase + absf(travel) / current_stride,1.0)
	was_walking = walking
	last_x = fighter.position.x
	_sample_frame()

func _sample_frame() -> void:
	if sprite == null or sheet == null or fighter == null:
		return
	var frame := 0
	match fighter.state:
		fighter.State.IDLE, fighter.State.BLOCK:
			# Same illustrated stance at rest and in motion; feet ease back
			# into guard rather than swapping abruptly to another pose.
			_set_walk_frame()
			return
		fighter.State.BLOCKSTUN:
			frame = 1
		fighter.State.WALK, fighter.State.DASH:
			locomotion_running = fighter.running or (fighter.state == fighter.State.DASH and fighter._dash_dir == fighter.facing)
			_set_walk_frame()
			return
		fighter.State.JUMP:
			frame = 4
		fighter.State.JUMP_START, fighter.State.LAND:
			frame = 8
		fighter.State.HITSTUN:
			frame = 11
		fighter.State.KO:
			frame = 15
		fighter.State.PUNCH, fighter.State.KICK:
			var family := 8 if fighter.state == fighter.State.KICK else 5
			if fighter.attack_variant in ["dive", "grapple", "cartwheel", "taunt"] or (loaded_id in ["ish", "bib", "anant"] and fighter.current_move.get("name", "") == fighter.available_moves().drive.name):
				family = 12
			var attack_phase := 0 if fighter.attack_timer < fighter.attack_startup() else (1 if fighter.attack_timer < fighter.attack_startup() + fighter.attack_active_time() else 2)
			frame = family + attack_phase
			if fighter.attack_variant in ["save", "feint"]:
				frame = 12
	_set_frame(frame)

func _set_frame(frame: int) -> void:
	if atlas == null:
		return
	sprite.show()
	if gait != null:
		gait.hide()
	var data: Dictionary = frame_data.frames[frame]
	scale.x = float(fighter.facing)
	atlas.atlas = sheet
	var region: Array = data.region
	atlas.region = Rect2(region[0], region[1], region[2], region[3])
	var breath := sin(phase) * 0.005 if frame == 0 else 0.0
	sprite.scale = Vector2(art_scale, art_scale * (1.0 + breath))
	sprite.position = Vector2(float(region[2]) * 0.5 - float(data.pivot_x), float(region[3]) * 0.5 - float(data.floor_y)) * sprite.scale
	if frame == 4 or (frame == 13 and loaded_id == "bib"):
		sprite.position.y -= 18.0
	if frame == 13 and loaded_id == "anug":
		sprite.position.y -= 36.0

func _set_walk_frame() -> void:
	sprite.hide()
	gait.show()
	scale.x = float(fighter.facing)
	gait.sample(walk_phase,locomotion_running,current_stride,movement_blend,retreat_walk,run_blend)

func reset_pose() -> void:
	super.reset_pose()
	walk_phase = 0.0
	was_walking = false
	locomotion_running = false
	movement_blend = 0.0
	run_blend = 0.0
	retreat_walk = false
	if fighter != null:
		last_x = fighter.position.x

func _draw() -> void:
	# No procedural body under the sprite.
	pass
