extends RefCounted
## Skinned, animated stand-in for the procedural fighter rig. Owned by
## fighter_visual_3d.gd: when fighter_models.gd has an enabled entry for the
## fighter, the character scene is placed where the procedural model is,
## that model is hidden, and a clip is chosen every frame from the fighter's
## combat state. Combat, hit detection and timings are untouched.
##
## Attacks are scrubbed rather than played: the fighter's own attack_timer
## picks the frame, so the blow lands exactly on the active frames, and
## hitstop or the pause menu freeze it for free. Loops are advanced by hand
## each frame (frozen at speed 0), then the guard overlay is applied.
##
## Guard overlay: while stepping, backing up, sidestepping or dashing, the
## spine, arms and head keep the boxing guard from the idle clip and only the
## legs use the locomotion clip, the way fighting games layer upper and lower
## body. Locomotion clips play at the speed that matches the fighter's real
## ground speed (measured from how far each clip travels) so feet don't skate.
const MODELS := preload("res://scripts/fighter_models.gd")
## Missing logical clips fall back along these links until one exists.
const FALLBACK := {
	"walk_back": "walk", "sidestep": "walk", "run": "walk", "dash": "run", "backdash": "walk_back",
	"sidestep_left": "sidestep", "sidestep_right": "sidestep", "victory": "taunt", "uppercut": "punch_heavy",
	"land": "idle", "block_hit": "block", "block": "idle", "hit_heavy": "hit",
	"hit": "idle", "punch_heavy": "jab", "kick_spin": "kick", "kick_front": "kick", "grapple": "jab",
	"taunt": "idle", "jump": "idle", "ko": "idle", "kick": "jab", "jab": "idle",
}
## Attack variants (from move data poses) that use the heavy-punch clip.
const HEAVY_PUNCHES := ["cross", "hook", "rear_hook", "uppercut", "overhand", "backfist", "body_hook"]
const LOOPING := ["idle", "walk", "walk_back", "sidestep", "sidestep_left", "sidestep_right", "run", "dash", "backdash", "block", "injured"]
## Movement that keeps the guard up on the upper body.
const GUARDED := ["walk", "walk_back", "sidestep", "sidestep_left", "sidestep_right", "dash", "backdash"]
## Bones the guard overlay drives (substring match on the bone name).
const UPPER_BODY := ["Spine", "Neck", "Head", "Shoulder", "Arm", "Hand"]
## Playback speed limits for locomotion: beyond these the legs look frantic
## (too fast) or floaty (too slow), so a little foot slide is accepted.
const MOVE_SPEED_RANGE := {"walk": [0.6, 2.4], "walk_back": [0.6, 2.4], "sidestep": [0.6, 2.4],
	"sidestep_left": [0.6, 2.4], "sidestep_right": [0.6, 2.4],
	"run": [0.6, 1.8], "injured": [0.6, 2.0], "dash": [1.0, 2.2], "backdash": [1.2, 3.0]}
## Health fraction at or below which forward movement limps.
const INJURED_HEALTH := 0.25
## Clips allowed to move the hips across the floor. Everything else plays in
## place: the game moves the fighter, so baked-in travel (a walk, a flip kick,
## a diving catch) would drift away from the body and snap back.
const TRAVELLING := ["ko"]
## Attack-like clips driven by the fighter's attack timer.
const SCRUBBED := ["jab", "punch_heavy", "uppercut", "kick", "kick_spin", "kick_front", "grapple", "taunt"]
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
## Metres per second each locomotion clip travels at normal speed, keyed by
## animation name (measured before its hips are pinned).
var clip_pace: Dictionary = {}
var skeleton: Skeleton3D
var guard_clip: Animation
## [track, bone] pairs of the idle clip's upper-body rotation tracks.
var guard_tracks: Array = []
var guard_weight := 0.0
var guard_time := 0.0

func configure(owner_visual: Node, profile: Dictionary) -> void:
	visual = owner_visual
	if is_instance_valid(root):
		root.get_parent().remove_child(root)
		root.queue_free()
	root = null
	active = false
	current = ""
	# Switching fighters starts from a clean slate: no clips, paces or guard
	# bones may carry over from the previous character.
	clip_names.clear()
	clip_pace.clear()
	guard_tracks.clear()
	guard_clip = null
	skeleton = null
	guard_weight = 0.0
	_last_state = -1
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
	# Advanced by hand in update(), so the guard overlay lands after the clip.
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if str(config.get("body", "")) != "":
		_graft_body(config.body)
	_add_clip_files()
	_resolve_clips()
	_prepare_guard()
	_fit(float(config.get("height", 1.8)))
	_tint(config.get("tint", []))
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
	var width: float = config.get("width", 1.0)
	character.scale = Vector3(width, 1.0, width) * (height / model_height) * units
	character.position.y = -bounds.position.y * (height / model_height) * units - (64.0 if visual.world_root == null else 0.0)

## Swaps the shared body's meshes for a generated one (body.glb from
## tools/build_fighter_body.py). It is skinned to the same Mixamo rig, so its
## binds are re-expressed against this skeleton's rest pose and every clip
## plays on it unchanged.
func _graft_body(path: String) -> void:
	var packed: PackedScene = load(path) if ResourceLoader.exists(path) else null
	var targets := character.find_children("*", "Skeleton3D", true, false)
	if packed == null or targets.is_empty():
		return
	var target: Skeleton3D = targets[0]
	var scene := packed.instantiate()
	var sources := scene.find_children("*", "Skeleton3D", true, false)
	if sources.is_empty():
		scene.free()
		return
	var source: Skeleton3D = sources[0]
	var bones := {}
	for bone in target.get_bone_count():
		bones[_bone_key(target.get_bone_name(bone))] = bone
	# Same rig in both files, so one similarity transform maps the body's
	# skeleton space onto this one; found from the hips, head and hands.
	var mapping := _skeleton_mapping(source, target, bones)
	for mesh in target.find_children("*", "MeshInstance3D", true, false):
		mesh.get_parent().remove_child(mesh)
		mesh.free()
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin == null:
			continue
		var skin := Skin.new()
		var placed := Transform3D()
		for i in mesh.skin.get_bind_count():
			var name := String(mesh.skin.get_bind_name(i))
			if name == "":
				name = source.get_bone_name(mesh.skin.get_bind_bone(i))
			var from := source.find_bone(name)
			var key := _bone_key(name)
			if from < 0 or not bones.has(key):
				continue
			var to: int = bones[key]
			var rest_space := mapping * source.get_bone_global_rest(from) * mesh.skin.get_bind_pose(i)
			placed = rest_space
			skin.add_named_bind(target.get_bone_name(to), target.get_bone_global_rest(to).affine_inverse() * rest_space)
		mesh.owner = null
		mesh.get_parent().remove_child(mesh)
		target.add_child(mesh)
		# Skinning ignores the node's own transform; this only places its
		# bounds, which _fit measures.
		mesh.transform = placed
		mesh.skin = skin
		mesh.skeleton = NodePath("..")
	scene.free()

static func _bone_key(name: String) -> String:
	return name.get_slice(":", name.get_slice_count(":") - 1).trim_prefix("mixamorig_").to_lower()

func _skeleton_mapping(source: Skeleton3D, target: Skeleton3D, bones: Dictionary) -> Transform3D:
	var frames: Array[Transform3D] = []
	for skeleton: Skeleton3D in [source, target]:
		var point := func(bone_name: String) -> Vector3:
			for bone in skeleton.get_bone_count():
				if _bone_key(skeleton.get_bone_name(bone)) == bone_name:
					return skeleton.get_bone_global_rest(bone).origin
			return Vector3.ZERO
		var hips: Vector3 = point.call("hips")
		var up: Vector3 = point.call("head") - hips
		var across: Vector3 = point.call("lefthand") - point.call("righthand")
		var size := up.length()
		var basis := Basis(across.normalized(), up.normalized(), across.cross(up).normalized()).orthonormalized()
		frames.append(Transform3D(basis.scaled(Vector3.ONE * size), hips))
	return frames[1] * frames[0].affine_inverse()

## Paints the shared body in the fighter's colours: [body, joints]. Meshes
## named like joints or trims take the second colour.
func _tint(colors: Array) -> void:
	if colors.size() < 2:
		return
	for mesh in character.find_children("*", "MeshInstance3D", true, false):
		var paint := StandardMaterial3D.new()
		var joint: bool = String(mesh.name).to_lower().contains("joint")
		paint.albedo_color = colors[1] if joint else colors[0]
		paint.roughness = 0.45 if joint else 0.7
		paint.metallic = 0.35 if joint else 0.0
		mesh.material_override = paint

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
				if not key in TRAVELLING:
					clip_pace["files/" + key] = _pin_hips(animation)
				library.add_animation(key, animation)
				break
		scene.free()
	player.add_animation_library("files", library)

## Holds the root bone's horizontal position at its first key (keeping the
## up-down bob), making a travelling clip play in place. Returns how fast
## the clip travelled, in metres per second.
func _pin_hips(animation: Animation) -> float:
	var pace := 0.0
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		var bone := String(animation.track_get_path(track).get_concatenated_subnames())
		if not bone.to_lower().ends_with("hips") and bone != "root":
			continue
		var first: Vector3 = animation.track_get_key_value(track, 0)
		var last: Vector3 = animation.track_get_key_value(track, animation.track_get_key_count(track) - 1)
		pace = Vector2(last.x - first.x, last.z - first.z).length() / maxf(animation.length, 0.01)
		for key in animation.track_get_key_count(track):
			var value: Vector3 = animation.track_get_key_value(track, key)
			animation.track_set_key_value(track, key, Vector3(first.x, value.y, first.z))
	return pace

## Finds the idle clip's upper-body rotation tracks for the guard overlay.
func _prepare_guard() -> void:
	var skeletons := character.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty() or not clip_names.has("idle"):
		return
	skeleton = skeletons[0]
	guard_clip = player.get_animation(clip_names.idle)
	for track in guard_clip.get_track_count():
		if guard_clip.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := String(guard_clip.track_get_path(track).get_concatenated_subnames())
		if UPPER_BODY.any(func(part): return bone_name.contains(part)):
			var bone := skeleton.find_bone(bone_name)
			if bone >= 0:
				guard_tracks.append([track, bone])

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
			logical = "dash" if fighter._dash_dir == fighter.facing else "backdash"
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
	# The winner celebrates over a knocked-out rival.
	var rival = fighter.get("opponent")
	if state == S.IDLE and rival != null and rival.state == rival.State.KO:
		logical = "victory"
	var clip: String = clip_names.get(logical, clip_names.get("idle", ""))
	if clip.is_empty():
		return
	var entered := state != _last_state
	_last_state = state
	if logical in SCRUBBED:
		guard_weight = 0.0
		_scrub_attack(fighter, logical, clip)
		return
	if clip != current or (entered and not logical in LOOPING):
		player.play(clip, 0.12)
		current = clip
	player.speed_scale = 0.0 if frozen else _loop_speed(fighter, logical, clip)
	player.advance(delta)
	if not frozen:
		guard_time += delta
		guard_weight = move_toward(guard_weight, 1.0 if logical in GUARDED else 0.0, delta * 8.0)
	_apply_guard()

## Blends the upper body toward the idle clip's boxing guard.
func _apply_guard() -> void:
	if guard_weight <= 0.0 or guard_clip == null:
		return
	var t := fmod(guard_time, guard_clip.length)
	for pair in guard_tracks:
		var guard: Quaternion = guard_clip.rotation_track_interpolate(pair[0], t)
		var pose := skeleton.get_bone_pose_rotation(pair[1])
		skeleton.set_bone_pose_rotation(pair[1], pose.slerp(guard, guard_weight))

func _attack_clip(fighter: Node) -> String:
	var variant: String = fighter.attack_variant
	if variant in ["grapple"]:
		return "grapple"
	if variant == "taunt":
		return "taunt"
	if fighter.state == fighter.State.KICK or variant in ["kick", "finisher", "front_kick"]:
		if variant in ["spin", "finisher"]:
			return "kick_spin"
		return "kick_front" if variant == "front_kick" else "kick"
	if variant == "spin":
		return "kick_spin"
	if variant in ["uppercut", "overhand", "body_hook"]:
		return "uppercut"
	return "punch_heavy" if variant in HEAVY_PUNCHES else "jab"

func _move_clip(fighter: Node) -> String:
	# Menu portraits use the 2D fighter, which has no physics body.
	var body = fighter.get("body")
	if body == null:
		return "walk"
	var velocity: Vector3 = body.velocity
	velocity.y = 0.0
	var hurt: bool = clip_names.has("injured") and fighter.health <= fighter.max_health * INJURED_HEALTH
	if fighter.running:
		return "injured" if hurt else "run"
	var ahead: float = velocity.dot(fighter.get("forward") if fighter.get("forward") != null else Vector3.RIGHT)
	var across := velocity.length() - absf(ahead)
	if across > absf(ahead):
		# The fighter's right is forward x up; +z when facing +x.
		var forward: Vector3 = fighter.get("forward") if fighter.get("forward") != null else Vector3.RIGHT
		var right := Vector3(-forward.z, 0.0, forward.x)
		return "sidestep_right" if velocity.dot(right) > 0.0 else "sidestep_left"
	if ahead < -0.05:
		return "walk_back"
	return "injured" if hurt else "walk"

## Locomotion plays at the speed that matches the fighter's ground speed;
## walking back plays the walk reversed when there's no dedicated clip.
func _loop_speed(fighter: Node, logical: String, clip: String) -> float:
	var body = fighter.get("body")
	if body == null or not MOVE_SPEED_RANGE.has(logical):
		return 1.0
	# Body velocity is in combat time; the fight runs at COMBAT_TEMPO.
	var tempo: float = fighter.get_script().get_script_constant_map().get("COMBAT_TEMPO", 1.0)
	var pace: float = Vector3(body.velocity.x, 0.0, body.velocity.z).length() * tempo
	var native: float = clip_pace.get(clip, 0.0)
	var limits: Array = MOVE_SPEED_RANGE[logical]
	var speed: float = clampf(pace / native if native > 0.2 else pace / 1.6, limits[0], limits[1])
	var reversed: bool = logical in ["walk_back", "backdash"] and clip_names.get(logical) == clip_names.get("walk")
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
