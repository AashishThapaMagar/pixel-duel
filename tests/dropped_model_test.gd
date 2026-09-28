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
	print("DROPPED_MODEL_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
