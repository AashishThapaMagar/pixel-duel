extends RefCounted
## Skinned, animated stand-in for the procedural fighter rig. Owned by
## fighter_visual_3d.gd: when fighter_models.gd has an enabled entry for the
## fighter, the character scene is placed where the procedural model is,
## that model is hidden, and a clip is chosen every frame from the fighter's
## combat state. Combat, hit detection and timings are untouched.
##
## Attacks are scrubbed rather than played: the fighter's own attack_timer
## picks the frame, so the blow lands exactly on the active frames, and
## hitstop or the pause menu freeze it for free. Loops are played normally
## and frozen by zeroing the player's speed.
const MODELS := preload("res://scripts/fighter_models.gd")
## Missing logical clips fall back along these links until one exists.
const FALLBACK := {
	"walk_back": "walk", "sidestep": "walk", "run": "walk", "dash": "run",
	"land": "idle", "block_hit": "block", "block": "idle", "hit_heavy": "hit",
	"hit": "idle", "punch_heavy": "jab", "kick_spin": "kick", "kick_front": "kick", "grapple": "jab",
	"taunt": "idle", "jump": "idle", "ko": "idle", "kick": "jab", "jab": "idle",
}
## Attack variants (from move data poses) that use the heavy-punch clip.
const HEAVY_PUNCHES := ["cross", "hook", "rear_hook", "uppercut", "overhand", "backfist", "body_hook"]
const LOOPING := ["idle", "walk", "walk_back", "sidestep", "run", "dash", "block"]
## Locomotion clips whose hips must not travel: the game moves the fighter,
## so baked-in forward motion would drift and snap back every loop.
const IN_PLACE := ["walk", "walk_back", "sidestep", "run", "dash"]
var visual: Node
var root: Node3D
var character: Node3D
var player: AnimationPlayer
var config: Dictionary = {}
var clip_names: Dictionary = {}
var current := ""
var active := false
var _last_state := -1
## Set from the fighter's impact signal: kicks land as heavy hits.
var last_hit_heavy := false

func configure(owner_visual: Node, profile: Dictionary) -> void:
	visual = owner_visual
	if is_instance_valid(root):
		root.get_parent().remove_child(root)
		root.queue_free()
	root = null
	active = false
	current = ""
	config = MODELS.entry(str(profile.id))
	if config.is_empty() or visual.model == null:
		visual.model.visible = true if visual.model != null else false
		return
	var packed: PackedScene = load(config.scene) if ResourceLoader.exists(config.scene) else null
	if packed == null:
		push_warning("Fighter model %s missing; using the procedural rig." % config.scene)
		visual.model.visible = true
		return
	root = Node3D.new()
	root.name = "AnimatedFighter"
	visual.model.get_parent().add_child(root)
	character = packed.instantiate() as Node3D
	root.add_child(character)
	player = character.find_children("*", "AnimationPlayer", true, false).front() if not character.find_children("*", "AnimationPlayer", true, false).is_empty() else null
	if player == null:
		player = AnimationPlayer.new()
		character.add_child(player)
	_add_clip_files()
	_resolve_clips()
	_fit(float(config.get("height", 1.8)))
	visual.model.visible = false
	active = true
	var fighter: Node = visual.fighter
	if fighter != null and fighter.has_signal("impact") and not fighter.impact.is_connected(_on_impact):
		fighter.impact.connect(_on_impact)

func _on_impact(_point: Vector2, blocked: bool, heavy: bool) -> void:
	if not blocked:
		last_hit_heavy = heavy

## Scales the model to its configured height, feet on the floor, turned to
## face the game's +X like the procedural rig.
func _fit(height: float) -> void:
	character.rotation.y = float(config.get("yaw", PI / 2.0))
	var bounds := AABB()
	var first := true
	# Measured in the character's own space, before the rig's scale.
	var to_local := character.global_transform.affine_inverse()
	for mesh in character.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (to_local * mesh.global_transform) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var model_height := maxf(bounds.size.y, 0.01)
	# The fight rig works in pixels-per-metre units (64 per metre).
	var units := 64.0
	character.scale = Vector3.ONE * (height / model_height) * units
	character.position.y = -bounds.position.y * (height / model_height) * units - (64.0 if visual.world_root == null else 0.0)

## Mixamo-style one-move-per-file downloads, retargeted onto this skeleton.
func _add_clip_files() -> void:
	var files: Dictionary = config.get("files", {})
	if files.is_empty():
		return
	var skeleton := character.find_children("*", "Skeleton3D", true, false)
	if skeleton.is_empty():
		return
	var library := AnimationLibrary.new()
	var to_skeleton := player.get_node(player.root_node).get_path_to(skeleton[0])
	for key in files:
		var source: PackedScene = load(files[key])
		if source == null:
			continue
		var scene := source.instantiate()
		var source_players := scene.find_children("*", "AnimationPlayer", true, false)
		if not source_players.is_empty():
			var from: AnimationPlayer = source_players[0]
			# Mixamo files also carry a leftover bind-pose "Take 001"; the
			# real clip is "mixamo_com", otherwise take the longest.
			var names := Array(from.get_animation_list())
			names.sort_custom(func(x, y): return x == "mixamo_com" or (y != "mixamo_com" and from.get_animation(x).length > from.get_animation(y).length))
			for name in names:
				var animation: Animation = from.get_animation(name).duplicate()
				# Point every bone track at this character's skeleton.
				for track in animation.get_track_count():
					var path := animation.track_get_path(track)
					if path.get_subname_count() > 0:
						animation.track_set_path(track, NodePath(str(to_skeleton) + ":" + path.get_concatenated_subnames()))
				if key in IN_PLACE:
					_pin_hips(animation)
				library.add_animation(key, animation)
				break
		scene.free()
	player.add_animation_library("files", library)

## Holds the root bone's horizontal position at its first key (keeping the
## up-down bob), making a travelling clip play in place.
func _pin_hips(animation: Animation) -> void:
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		var bone := String(animation.track_get_path(track).get_concatenated_subnames())
		if not bone.to_lower().ends_with("hips") and bone != "root":
			continue
		var first: Vector3 = animation.track_get_key_value(track, 0)
		for key in animation.track_get_key_count(track):
			var value: Vector3 = animation.track_get_key_value(track, key)
			animation.track_set_key_value(track, key, Vector3(first.x, value.y, first.z))

func _resolve_clips() -> void:
	var available := player.get_animation_list()
	var wanted: Dictionary = config.get("clips", {})
	for logical in wanted:
		var name: String = wanted[logical]
		for candidate in [name, "files/" + name]:
			if available.has(candidate):
				clip_names[logical] = candidate
	for logical in FALLBACK.keys() + ["idle"]:
		var probe: String = logical
		var guard := 0
		while not clip_names.has(probe) and FALLBACK.has(probe) and guard < 8:
			probe = FALLBACK[probe]
			guard += 1
		if clip_names.has(probe):
			clip_names[logical] = clip_names[probe]
	for name in clip_names.values():
		var animation := player.get_animation(name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR if clip_names.find_key(name) in LOOPING else Animation.LOOP_NONE

## Picks and poses the clip for this frame. Called from the visual's
## _process and sync_pose.
func update(delta: float) -> void:
	if not active or visual.fighter == null:
		return
	var fighter: Node = visual.fighter
	# Only the facing turn: the procedural rig's knockdown/hit spin would
	# double up with the clips' own falls and sink the model into the floor.
	root.transform = Transform3D(Basis(Vector3.UP, visual.model.rotation.y), visual.model.position)
	var frozen: bool = fighter.combat_paused or fighter.hitstop_remaining > 0.0
	var S: Dictionary = fighter.State
	var state: int = fighter.state
	var logical := "idle"
	match state:
		S.PUNCH, S.KICK:
			logical = _attack_clip(fighter)
		S.WALK:
			logical = _move_clip(fighter)
		S.DASH:
			logical = "dash"
		S.JUMP, S.JUMP_START:
			logical = "jump"
		S.LAND:
			logical = "land"
		S.BLOCK:
			logical = "block"
		S.BLOCKSTUN:
			logical = "block_hit"
		S.HITSTUN:
			logical = "hit_heavy" if last_hit_heavy else "hit"
		S.KO:
			logical = "ko"
	var clip: String = clip_names.get(logical, clip_names.get("idle", ""))
	if clip.is_empty():
		return
	var entered := state != _last_state
	_last_state = state
	if logical in ["jab", "punch_heavy", "kick", "kick_spin", "kick_front", "grapple"]:
		_scrub_attack(fighter, logical, clip)
		return
	if clip != current or (entered and not logical in LOOPING):
		player.play(clip, 0.12)
		current = clip
	player.speed_scale = 0.0 if frozen else _loop_speed(fighter, logical)

func _attack_clip(fighter: Node) -> String:
	var variant: String = fighter.attack_variant
	if variant in ["grapple"]:
		return "grapple"
	if fighter.state == fighter.State.KICK or variant in ["kick", "finisher", "front_kick"]:
		if variant in ["spin", "finisher"]:
			return "kick_spin"
		return "kick_front" if variant == "front_kick" else "kick"
	if variant == "spin":
		return "kick_spin"
	return "punch_heavy" if variant in HEAVY_PUNCHES else "jab"

func _move_clip(fighter: Node) -> String:
	# Menu portraits use the 2D fighter, which has no physics body.
	var body = fighter.get("body")
	if body == null:
		return "walk"
	var velocity: Vector3 = body.velocity
	velocity.y = 0.0
	if fighter.running:
		return "run"
	var ahead: float = velocity.dot(fighter.get("forward") if fighter.get("forward") != null else Vector3.RIGHT)
	var across := velocity.length() - absf(ahead)
	if across > absf(ahead):
		return "sidestep"
	return "walk_back" if ahead < -0.05 else "walk"

## Loops keep pace with the fighter; walking back plays the walk reversed
## when there's no dedicated clip.
func _loop_speed(fighter: Node, logical: String) -> float:
	var body = fighter.get("body")
	if body == null or not logical in ["walk", "walk_back", "sidestep", "run", "dash"]:
		return 1.0
	var pace: float = Vector3(body.velocity.x, 0.0, body.velocity.z).length()
	var speed := clampf(pace / 1.6, 0.6, 1.8)
	var reversed: bool = logical == "walk_back" and clip_names.get("walk_back") == clip_names.get("walk")
	return -speed if reversed else speed

## Maps attack_timer onto the clip: wind-up covers the clip up to its
## impact point, and the blow's active frames and recovery cover the rest.
func _scrub_attack(fighter: Node, logical: String, clip: String) -> void:
	var animation := player.get_animation(clip)
	if animation == null:
		return
	# No cross-fade: the player is held at speed 0 while scrubbing, so a
	# blend would never finish and the previous clip would stay on screen.
	if clip != current:
		player.play(clip, 0.0)
		current = clip
	player.speed_scale = 0.0
	# Part of the clip to use: [start, impact, end] seconds from "timing",
	# or the whole clip with the impact at the "impact" fraction.
	var cut: Array = config.get("timing", {}).get(logical, [])
	var start := 0.0
	var end := animation.length
	var impact: float = float(config.get("impact", {}).get(logical, 0.45)) * animation.length
	if cut.size() == 3:
		start = cut[0]
		impact = cut[1]
		end = minf(cut[2], animation.length)
	var startup: float = fighter.attack_startup()
	var total: float = maxf(fighter.attack_duration(), startup + 0.01)
	var t: float = fighter.attack_timer
	var position := start + (impact - start) * clampf(t / maxf(startup, 0.001), 0.0, 1.0)
	if t > startup:
		position = impact + (end - impact) * clampf((t - startup) / (total - startup), 0.0, 1.0)
	player.seek(minf(position, animation.length - 0.001), true)
