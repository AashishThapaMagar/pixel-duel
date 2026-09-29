extends SceneTree
## A rigged model dropped into a fighter's folder is picked up without a
## table entry, and its animation names are matched to the game's clips.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	var models = load("res://scripts/fighter_models.gd")
	var animated = load("res://scripts/fighter_animated.gd")
	check(models.dropped_scene("anug") == "", "No dropped rig means the usual pipeline")
	# The Kenney dummy's clip names, as a stand-in for a downloaded rig.
	var names := ["Take 001", "idle", "walk", "sprint", "jump", "fall", "attack-melee-right", "attack-melee-left",
		"attack-kick-right", "attack-kick-left", "die", "emote-no", "crouch", "emote-yes", "pick-up"]
	check(animated.match_clip("idle", names) == "idle", "Idle matches by name")
	check(animated.match_clip("run", names) == "sprint", "Run matches a sprint")
	check(animated.match_clip("jab", names) == "attack-melee-right", "A jab matches a melee attack")
	check(animated.match_clip("kick", names) == "attack-kick-right", "A kick matches a kick")
	check(animated.match_clip("ko", names) == "die", "Knockout matches a death clip")
	check(animated.match_clip("land", names) == "fall", "Landing matches a fall")
	check(animated.match_clip("taunt", names) == "", "Nothing matches when no name fits")
	var meshy := ["Armature|mixamo.com|Layer0", "Boxing Idle", "Walking", "Walking Backwards", "Running", "Jab Cross", "Hook Punch", "Roundhouse Kick", "Head Hit", "Knocked Out", "Victory"]
	check(animated.match_clip("idle", meshy) == "Boxing Idle", "Boxing idle wins over the bind take")
	check(animated.match_clip("walk_back", meshy) == "Walking Backwards" and animated.match_clip("walk", meshy) == "Walking", "Walk and walk back are told apart")
	check(animated.match_clip("punch_heavy", meshy) == "Hook Punch" and animated.match_clip("jab", meshy) == "Jab Cross", "Jab and heavy punch are told apart")
	check(animated.match_clip("kick_spin", meshy) == "Roundhouse Kick" and animated.match_clip("hit", meshy) == "Head Hit" and animated.match_clip("ko", meshy) == "Knocked Out", "Kicks, hits and knockouts match Mixamo names")
	# A dropped rig entry: the test dummy stands in via a temporary copy.
	var folder := "res://assets/fighters/bib/"
	DirAccess.make_dir_recursive_absolute(folder)
	var placed := DirAccess.copy_absolute("res://assets/fighters/test-kenney/character-male-a.glb", folder + "meshy_rig.glb") == OK
	if placed:
		var entry: Dictionary = models.entry("bib")
		check(entry.get("scene", "") == folder + "meshy_rig.glb" and entry.get("enabled", false), "A dropped rig replaces the fighter's model")
		check(entry.get("clips", {}).is_empty(), "A dropped rig relies on name matching")
		# End to end: a match with that fighter runs on the dropped model,
		# decoded straight from the file, with its clips matched by name.
		root.get_node("MatchSetup").vs_ai = false
		root.get_node("MatchSetup").selected_fighters[0] = 3
		root.get_node("MatchSetup").selected_fighters[1] = 1
		var arena: Node = load("res://scenes/Arena3D.tscn").instantiate()
		root.add_child(arena)
		current_scene = arena
		for i in 3:
			await process_frame
		var live = arena.player1.visual.get("animated")
		check(live != null and live.active and live.character != null, "The dropped rig is on the fighter in a live match")
		if live != null and live.active:
			check(live.clip_names.get("idle", "") == "idle" and String(live.clip_names.get("kick", "")).begins_with("attack-kick") and live.clip_names.get("ko", "") == "die", "Its clips were matched by name")
			check(not arena.player1.visual.model.visible, "The procedural rig is hidden behind it")
		var other = arena.player2.visual.get("animated")
		check(other == null or not other.active, "Fighters without a dropped rig keep the procedural model")
		arena.queue_free()
		await process_frame
		DirAccess.remove_absolute(folder + "meshy_rig.glb")
		DirAccess.remove_absolute(folder)
	# The procedural layers on a Mixamo-shaped skeleton: the calibration
	# must find the legs and spine and bend them the right way, whatever
	# axis convention the rig uses.
	var rig := Node3D.new()
	root.add_child(rig)
	rig.rotation.y = 0.0
	var character := Node3D.new()
	rig.add_child(character)
	var skeleton := Skeleton3D.new()
	character.add_child(skeleton)
	var chain := [["mixamorig_Hips", -1, Transform3D(Basis(), Vector3(0, 1.0, 0))],
		["mixamorig_Spine", 0, Transform3D(Basis(), Vector3(0, 0.15, 0))], ["mixamorig_Spine1", 1, Transform3D(Basis(), Vector3(0, 0.15, 0))],
		["mixamorig_Spine2", 2, Transform3D(Basis(), Vector3(0, 0.15, 0))], ["mixamorig_Neck", 3, Transform3D(Basis(), Vector3(0, 0.12, 0))],
		["mixamorig_Head", 4, Transform3D(Basis(), Vector3(0, 0.12, 0))]]
	for side in ["Left", "Right"]:
		var x := 0.1 if side == "Left" else -0.1
		# Leg bones point down: their local Y is turned to world -Y, as Mixamo rigs do.
		chain.append(["mixamorig_%sUpLeg" % side, 0, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(x, 0, 0))])
		chain.append(["mixamorig_%sLeg" % side, chain.size() - 1, Transform3D(Basis(), Vector3(0, 0.45, 0))])
		chain.append(["mixamorig_%sFoot" % side, chain.size() - 1, Transform3D(Basis(), Vector3(0, 0.45, 0))])
	for bone in chain:
		var index := skeleton.add_bone(bone[0])
		if bone[1] >= 0:
			skeleton.set_bone_parent(index, bone[1])
		skeleton.set_bone_rest(index, bone[2])
		skeleton.set_bone_pose_position(index, bone[2].origin)
		skeleton.set_bone_pose_rotation(index, bone[2].basis.get_rotation_quaternion())
	var layers = animated.new()
	layers.root = rig
	layers.character = character
	layers.skeleton = skeleton
	layers._calibrate()
	check(layers._legs.size() == 2 and layers._spine.size() == 3, "Calibration finds both legs and the spine on a Mixamo-shaped rig")
	var foot := skeleton.find_bone("mixamorig_LeftFoot")
	var head := skeleton.find_bone("mixamorig_Head")
	skeleton.force_update_all_bone_transforms()
	var foot_before: Vector3 = skeleton.get_bone_global_pose(foot).origin
	var head_before: Vector3 = skeleton.get_bone_global_pose(head).origin
	layers._tuck = 1.0
	layers._apply_layers()
	skeleton.force_update_all_bone_transforms()
	var foot_after: Vector3 = skeleton.get_bone_global_pose(foot).origin
	check(foot_after.x <= foot_before.x + 0.02 and foot_after.y > foot_before.y + 0.08, "A jump tuck lifts the foot without swinging it forward (rig faces +X)")
	layers._tuck = 0.0
	layers._lean = 0.3
	layers._apply_layers()
	skeleton.force_update_all_bone_transforms()
	var head_after: Vector3 = skeleton.get_bone_global_pose(head).origin
	check(head_after.x < head_before.x - 0.03, "A guarded hit leans the head back")
	rig.queue_free()
	print("DROPPED_MODEL_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
