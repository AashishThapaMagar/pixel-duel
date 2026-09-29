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
	"cross": "punch_heavy", "hook": "punch_heavy",
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
const MOVE_SPEED_RANGE := {"walk": [0.7, 1.7], "walk_back": [0.7, 1.7], "sidestep": [0.7, 1.7],
	"sidestep_left": [0.7, 1.7], "sidestep_right": [0.7, 1.7],
	"run": [0.7, 1.5], "injured": [0.7, 1.6], "dash": [1.0, 1.9], "backdash": [1.0, 2.2]}
## Health fraction at or below which forward movement limps.
const INJURED_HEALTH := 0.25
## Clips allowed to move the hips across the floor. Everything else plays in
## place: the game moves the fighter, so baked-in travel (a walk, a flip kick,
## a diving catch) would drift away from the body and snap back.
const TRAVELLING := ["ko"]
## Attack-like clips driven by the fighter's attack timer.
const SCRUBBED := ["jab", "cross", "hook", "punch_heavy", "uppercut", "kick", "kick_spin", "kick_front", "grapple", "taunt"]
## Meshy's biped skeleton names -> Mixamo bone keys (see _bone_key); every
## other bone already shares the Mixamo name.
const MESHY_BONES := {"spine02": "spine", "spine01": "spine1", "spine": "spine2", "neck": "neck",
	"head_end": "headtop_end", "lefthand_end": "", "righthand_end": "", "headfront": "",
	"lefttoe_end": "lefttoe_end", "righttoe_end": "righttoe_end"}
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
## Cutscenes (story_dialogue.gd) pose a fighter directly: this logical clip
## plays as-is whatever the fight state says. Empty leaves the fight in charge.
var pose_override := ""
var guard_time := 0.0
## Blend into a scrubbed attack from whatever pose the rig was in, so a
## jab never snaps from the guard to the clip's first frame.
var _blend_from: Dictionary = {}
var _blend_time := 0.0
const ATTACK_BLEND := 0.09
## Procedural layers on top of the clips: a knee tuck for rigs with no
## jump clip and a lean back for guarded hits. Bones are found by name and
## their bend direction is calibrated once, so any humanoid rig works.
var _tuck := 0.0
var _lean := 0.0
var _legs: Array = []      # [[upper bone, knee bone, upper sign, knee sign, axis], ...]
var _spine: Array = []     # [[bone, sign, axis], ...]

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
	character = _load_character(config.scene)
	if character == null:
		push_warning("Fighter model %s missing; using the procedural rig." % config.scene)
		visual.model.visible = true
		return
	root = Node3D.new()
	root.name = "AnimatedFighter"
	visual.model.get_parent().add_child(root)
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
	_polish_materials()
	_calibrate()
	visual.model.visible = false
	active = true
	var fighter: Node = visual.fighter
	if fighter != null and fighter.has_signal("impact") and not fighter.impact.is_connected(_on_impact):
		fighter.impact.connect(_on_impact)

## The character scene: the imported resource when the editor has seen
## the file, otherwise a glTF decoded on the spot (a rig dropped into the
## folder plays without opening the editor first).
static func _load_character(path: String) -> Node3D:
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path)
		if packed != null and packed.can_instantiate():
			return packed.instantiate() as Node3D
	if path.get_extension().to_lower() in ["glb", "gltf"] and FileAccess.file_exists(path):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(path, state) == OK:
			return document.generate_scene(state) as Node3D
	return null

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
	var meshy: Dictionary = config.get("meshy", {})
	if not meshy.is_empty() and ResourceLoader.exists(meshy.file):
		_add_meshy_clips(library, meshy.file, meshy.clips, skeleton[0], to_skeleton)
	player.add_animation_library("files", library)

## Meshy's own animations (its "Merged Animations" download) retargeted onto
## this skeleton. The two rigs share a hierarchy but not bone names, rest
## orientations or scale, so each frame is rebuilt: a bone's world rotation
## keeps the same offset from its rest that the Meshy bone has from its own
## rest, and the hips' travel is scaled by the ratio of hip heights.
func _add_meshy_clips(library: AnimationLibrary, path: String, wanted: Dictionary, target: Skeleton3D, to_skeleton: NodePath) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	var sources := scene.find_children("*", "Skeleton3D", true, false)
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	if sources.is_empty() or players.is_empty():
		scene.free()
		return
	var source: Skeleton3D = sources[0]
	var from: AnimationPlayer = players[0]
	# Source bone -> target bone.
	var pairs := {}
	var target_keys := {}
	for bone in target.get_bone_count():
		target_keys[_bone_key(target.get_bone_name(bone))] = bone
	for bone in source.get_bone_count():
		var key := _bone_key(source.get_bone_name(bone))
		key = MESHY_BONES.get(key, key)
		if key != "" and target_keys.has(key):
			pairs[bone] = target_keys[key]
	var source_hips := source.find_bone(source.get_bone_name(0))
	for bone in pairs:
		if _bone_key(source.get_bone_name(bone)) == "hips":
			source_hips = bone
	var target_hips: int = target_keys.get("hips", 0)
	# The rigs rest in different poses (Meshy's A-pose, Mixamo's T-pose), so
	# bones are matched by where they point, not by their rest rotation: each
	# mapped bone gets a frame built from its direction in the rest pose, and
	# the target bone is turned so its frame follows the source bone's.
	var s_node := _node_rotation(source, scene)
	var t_node := _node_rotation(target, character)
	var inverse_pairs := {}
	for bone in pairs:
		inverse_pairs[pairs[bone]] = bone
	var s_frame := {}  # source bone -> frame in bone-local space
	var t_frame := {}
	for bone in pairs:
		var target_bone: int = pairs[bone]
		var s_dir := _rest_direction(source, s_node, bone, pairs.keys())
		var t_dir := _rest_direction(target, t_node, target_bone, inverse_pairs.keys())
		s_frame[bone] = (s_node * source.get_bone_global_rest(bone).basis.get_rotation_quaternion()).inverse() * _frame(s_dir)
		t_frame[target_bone] = (t_node * target.get_bone_global_rest(target_bone).basis.get_rotation_quaternion()).inverse() * _frame(t_dir)
	var s_height := source.get_bone_global_rest(source_hips).origin.length()
	var t_height := target.get_bone_global_rest(target_hips).origin.length()
	var scale := t_height / maxf(s_height, 0.0001)
	var names := from.get_animation_list()
	for logical in wanted:
		var clip_name := ""
		for candidate in names:
			if String(candidate).ends_with(String(wanted[logical])):
				clip_name = candidate
		if clip_name == "":
			continue
		var clip := from.get_animation(clip_name)
		var rotation_tracks := {}
		var position_track := -1
		for track in clip.get_track_count():
			var bone := source.find_bone(String(clip.track_get_path(track).get_concatenated_subnames()))
			if bone < 0:
				continue
			if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
				rotation_tracks[bone] = track
			elif clip.track_get_type(track) == Animation.TYPE_POSITION_3D and bone == source_hips:
				position_track = track
		var out := Animation.new()
		out.length = clip.length
		var out_tracks := {}
		for bone in pairs.values():
			var track := out.add_track(Animation.TYPE_ROTATION_3D)
			out.track_set_path(track, NodePath(str(to_skeleton) + ":" + target.get_bone_name(bone)))
			out_tracks[bone] = track
		var hips_track := out.add_track(Animation.TYPE_POSITION_3D)
		out.track_set_path(hips_track, NodePath(str(to_skeleton) + ":" + target.get_bone_name(target_hips)))
		var step := 1.0 / 30.0
		var time := 0.0
		while time <= clip.length + 0.0001:
			var at := minf(time, clip.length)
			# Source world rotations, parents before children.
			var s_world := {}
			for bone in source.get_bone_count():
				var local := source.get_bone_rest(bone).basis.get_rotation_quaternion()
				if rotation_tracks.has(bone):
					local = clip.rotation_track_interpolate(rotation_tracks[bone], at)
				var parent := source.get_bone_parent(bone)
				s_world[bone] = (s_world[parent] if parent >= 0 else s_node) * local
			var t_world := {}
			for bone in target.get_bone_count():
				var parent := target.get_bone_parent(bone)
				var parent_world: Quaternion = t_world[parent] if parent >= 0 else t_node
				var source_bone = pairs.find_key(bone)
				if source_bone != null:
					t_world[bone] = (s_world[source_bone] as Quaternion) * (s_frame[source_bone] as Quaternion) * (t_frame[bone] as Quaternion).inverse()
					out.rotation_track_insert_key(out_tracks[bone], at, (parent_world.inverse() * t_world[bone]).normalized())
				else:
					t_world[bone] = parent_world * target.get_bone_rest(bone).basis.get_rotation_quaternion()
			var hips := target.get_bone_rest(target_hips).origin
			if position_track >= 0:
				var moved: Vector3 = clip.position_track_interpolate(position_track, at) - source.get_bone_rest(source_hips).origin
				hips += t_node.inverse() * (s_node * moved) * scale
			out.position_track_insert_key(hips_track, at, hips)
			time += step
		var key: String = "meshy_" + logical
		clip_pace["files/" + key] = _pin_hips(out)
		library.add_animation(key, out)
	scene.free()

## Where a bone points in the rest pose (world space): toward its main
## mapped child (the spine, neck or head over the shoulders and legs), or on
## from its parent for end bones.
static func _rest_direction(skeleton: Skeleton3D, node: Quaternion, bone: int, mapped: Array) -> Vector3:
	var here := skeleton.get_bone_global_rest(bone).origin
	var best := -1
	for child in skeleton.get_bone_children(bone):
		if not mapped.has(child):
			continue
		var key := _bone_key(skeleton.get_bone_name(child))
		if best < 0 or key.contains("spine") or key.contains("neck") or key.contains("head"):
			best = child
	var direction := Vector3.ZERO
	if best >= 0:
		direction = skeleton.get_bone_global_rest(best).origin - here
	elif skeleton.get_bone_parent(bone) >= 0:
		direction = here - skeleton.get_bone_global_rest(skeleton.get_bone_parent(bone)).origin
	if direction.length() < 0.00001:
		direction = Vector3.UP
	return (node * direction).normalized()

## A rotation whose Y axis runs along direction, twist fixed by the
## character's forward (+Z), or up when the bone points forward.
static func _frame(direction: Vector3) -> Quaternion:
	var reference := Vector3.BACK
	if absf(direction.dot(reference)) > 0.9:
		reference = Vector3.UP
	var x := direction.cross(reference).normalized()
	var z := x.cross(direction).normalized()
	return Basis(x, direction, z).get_rotation_quaternion()

static func _node_rotation(skeleton: Skeleton3D, top: Node) -> Quaternion:
	var rotation := Quaternion.IDENTITY
	var node: Node = skeleton
	while node != null and node != top:
		if node is Node3D:
			rotation = (node as Node3D).transform.basis.get_rotation_quaternion() * rotation
		node = node.get_parent()
	return rotation

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

## What a clip is usually called in a downloaded rig, per logical clip;
## the first keyword that appears in an animation's name wins, earlier
## keywords first. Lets a rigged model dropped into a fighter's folder play
## without a hand-written clip table.
const CLIP_KEYWORDS := {
	"idle": ["fight_idle", "boxing_idle", "idle", "stand", "breath"],
	"walk": ["walk_forward", "walking", "walk"],
	"walk_back": ["walk_back", "walking_back", "backward", "backwards"],
	"sidestep_left": ["strafe_left", "step_left", "side_left"],
	"sidestep_right": ["strafe_right", "step_right", "side_right"],
	"run": ["run", "sprint", "jog"],
	"dash": ["dash"], "backdash": ["dodge", "evade"],
	"jump": ["jump"], "land": ["land", "fall"],
	"block": ["block", "guard", "defend"], "block_hit": ["block_hit", "guard_hit"],
	"hit": ["head_hit", "hit_react", "hit", "hurt", "impact", "damage", "react", "flinch"],
	"hit_heavy": ["body_hit", "big_hit", "heavy_hit", "knockback", "stagger"],
	"ko": ["knocked_out", "knockout", "death", "dying", "die", "dead", "ko", "defeat"],
	"jab": ["jab", "left_punch", "punch", "attack-melee", "melee", "attack"],
	"punch_heavy": ["hook", "haymaker", "heavy_punch", "right_punch", "cross", "punch"],
	"uppercut": ["upper"], "kick": ["kick"], "kick_spin": ["spin", "roundhouse", "flip"],
	"kick_front": ["front_kick", "push_kick"], "grapple": ["throw", "grab", "grapple", "slam"],
	"taunt": ["taunt"], "victory": ["victory", "win", "cheer", "celebrat", "dance"],
	"injured": ["injured", "limp"],
}

## The animation in `names` that best fits `logical`, or "" when none does.
## Names are compared lower-case with spaces and dashes folded to
## underscores; bind-pose leftovers ("Take 001", "bind") never match.
static func match_clip(logical: String, names: Array) -> String:
	var keywords: Array = CLIP_KEYWORDS.get(logical, [])
	for keyword in keywords:
		var key: String = String(keyword).replace("-", "_")
		for name in names:
			var folded := String(name).to_lower().replace(" ", "_").replace("-", "_").replace("|", "_")
			if folded.begins_with("take_") or folded.contains("bind") or folded.contains("t_pose") or folded.contains("tpose"):
				continue
			if folded.contains(key):
				return String(name)
	return ""

func _resolve_clips() -> void:
	var available := player.get_animation_list()
	var wanted: Dictionary = config.get("clips", {})
	for logical in wanted:
		var name: String = wanted[logical]
		for candidate in [name, "files/" + name]:
			if available.has(candidate):
				clip_names[logical] = candidate
	# Anything the table did not name is matched by keyword, so a rig
	# dropped into the folder with its own animations plays as it is.
	for logical in CLIP_KEYWORDS:
		if not clip_names.has(logical):
			var guess := match_clip(logical, Array(available))
			if guess != "":
				clip_names[logical] = guess
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
	if pose_override != "":
		logical = pose_override
	var clip: String = clip_names.get(logical, clip_names.get("idle", ""))
	if clip.is_empty():
		return
	var entered := state != _last_state
	_last_state = state
	if logical in SCRUBBED and pose_override == "":
		guard_weight = 0.0
		_scrub_attack(fighter, logical, clip, delta, frozen)
		_procedural(fighter, logical, delta, frozen)
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
	_procedural(fighter, logical, delta, frozen)

## Bones by the Mixamo-style key their name ends with (see _bone_key).
func _bone(key: String) -> int:
	if skeleton == null:
		return -1
	for bone in skeleton.get_bone_count():
		if _bone_key(skeleton.get_bone_name(bone)) == key:
			return bone
	return -1

## Finds the spine and leg bones and works out, for each, which local axis
## and sign bends it the way the layers below want: knees folding the foot
## back, hips lifting the knee forward, the spine leaning the head back.
func _calibrate() -> void:
	_legs.clear()
	_spine.clear()
	if skeleton == null:
		var skeletons := character.find_children("*", "Skeleton3D", true, false)
		if skeletons.is_empty():
			return
		skeleton = skeletons[0]
	var forward: Vector3 = skeleton.global_transform.basis.inverse() * root.global_transform.basis.x
	var up: Vector3 = skeleton.global_transform.basis.inverse() * root.global_transform.basis.y
	for side in ["left", "right"]:
		var upper := _bone(side + "upleg")
		var knee := _bone(side + "leg")
		var foot := _bone(side + "foot")
		if upper < 0 or knee < 0 or foot < 0:
			continue
		var knee_axis := _best_axis(knee, foot, -forward)
		var hip_axis := _best_axis(upper, knee, forward + up * 0.5)
		if knee_axis.is_empty() or hip_axis.is_empty():
			continue
		_legs.append([upper, knee, hip_axis[1], knee_axis[1], hip_axis[0], knee_axis[0]])
	var head := _bone("head")
	for key in ["spine", "spine1", "spine2"]:
		var bone := _bone(key)
		if bone < 0 or head < 0:
			continue
		var axis := _best_axis(bone, head, -forward)
		if not axis.is_empty():
			_spine.append([bone, axis[1], axis[0]])

## [axis, sign] for rotating `bone` so that `tip` moves along `want`, or
## [] when no local axis moves it there. Probes with a test rotation and
## restores the pose.
func _best_axis(bone: int, tip: int, want: Vector3) -> Array:
	var rest := skeleton.get_bone_pose_rotation(bone)
	skeleton.force_update_all_bone_transforms()
	var before := skeleton.get_bone_global_pose(tip).origin
	var best: Array = []
	var best_dot := 0.05
	for axis in [Vector3.RIGHT, Vector3.FORWARD, Vector3.UP]:
		skeleton.set_bone_pose_rotation(bone, rest * Quaternion(axis, 0.6))
		skeleton.force_update_all_bone_transforms()
		var moved := skeleton.get_bone_global_pose(tip).origin - before
		var along := moved.dot(want.normalized())
		if absf(along) > best_dot:
			best_dot = absf(along)
			best = [axis, signf(along)]
	skeleton.set_bone_pose_rotation(bone, rest)
	return best

## Jump tuck (only when the rig has no jump clip of its own) and the lean
## back of a guarded hit, both eased so they read as weight, not a switch.
func _procedural(fighter: Node, logical: String, delta: float, frozen: bool) -> void:
	if skeleton == null:
		return
	var S: Dictionary = fighter.State
	var tuck_target := 0.0
	if clip_names.get("jump", "") == clip_names.get("idle", "") and pose_override == "":
		match fighter.state:
			S.JUMP_START:
				tuck_target = 0.35
			S.JUMP:
				tuck_target = 0.9 if fighter.velocity.y < 0.0 else 0.55
			S.LAND:
				tuck_target = 0.4
	var lean_target := 0.0
	if fighter.state == S.BLOCKSTUN and clip_names.get("block_hit", "") == clip_names.get("block", ""):
		lean_target = 0.32 * visual._recoil()
	if not frozen:
		_tuck = move_toward(_tuck, tuck_target, delta * 9.0)
		_lean = move_toward(_lean, lean_target, delta * 12.0)
	_apply_layers()

## Bends the calibrated bones by the current tuck and lean amounts.
func _apply_layers() -> void:
	if skeleton == null:
		return
	if _tuck > 0.001:
		for leg in _legs:
			var hip := skeleton.get_bone_pose_rotation(leg[0])
			skeleton.set_bone_pose_rotation(leg[0], hip * Quaternion(leg[4], leg[2] * 0.5 * _tuck))
			var knee := skeleton.get_bone_pose_rotation(leg[1])
			skeleton.set_bone_pose_rotation(leg[1], knee * Quaternion(leg[5], leg[3] * 1.05 * _tuck))
	if _lean > 0.001:
		for part in _spine:
			var pose := skeleton.get_bone_pose_rotation(part[0])
			skeleton.set_bone_pose_rotation(part[0], pose * Quaternion(part[2], part[1] * _lean / _spine.size()))

## Imported bodies arrive with whatever finish their exporter chose, often
## a metallic, glossy plastic. Bring them to a matte skin-and-cloth look
## that sits in the arena lighting: no metal, a soft rim, sharp mipmaps.
func _polish_materials() -> void:
	for mesh: MeshInstance3D in character.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count() if mesh.mesh != null else 0:
			var material := mesh.get_active_material(surface)
			if not material is StandardMaterial3D or material.has_meta("polished"):
				continue
			material.set_meta("polished", true)
			material.metallic = minf(material.metallic, 0.12)
			material.roughness = maxf(material.roughness, 0.72)
			material.metallic_specular = 0.28
			material.rim_enabled = true
			material.rim = 0.12
			material.rim_tint = 0.5
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

## Restarts the current clip on the next update (cutscenes repeating a move).
func replay() -> void:
	if player != null:
		player.stop()
	current = ""

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
	# Punch chains show a different strike for each hit when the fighter
	# has them (they fall back to the heavy punch otherwise).
	if variant == "cross":
		return "cross"
	if variant in ["hook", "rear_hook", "backfist"]:
		return "hook"
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
func _scrub_attack(fighter: Node, logical: String, clip: String, delta: float, frozen: bool) -> void:
	var animation := player.get_animation(clip)
	if animation == null:
		return
	# The player is held at speed 0 while scrubbing, so its own cross-fade
	# would never finish. Instead the pose the rig was in is captured and
	# blended toward the clip by hand over the first few frames.
	if clip != current:
		_capture_pose()
		_blend_time = 0.0
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
	if not frozen:
		_blend_time += delta
	if _blend_time < ATTACK_BLEND and skeleton != null and not _blend_from.is_empty():
		var k := smoothstep(0.0, 1.0, _blend_time / ATTACK_BLEND)
		for bone in _blend_from:
			skeleton.set_bone_pose_rotation(bone, (_blend_from[bone] as Quaternion).slerp(skeleton.get_bone_pose_rotation(bone), k))

func _capture_pose() -> void:
	_blend_from.clear()
	if skeleton == null:
		return
	for bone in skeleton.get_bone_count():
		_blend_from[bone] = skeleton.get_bone_pose_rotation(bone)
