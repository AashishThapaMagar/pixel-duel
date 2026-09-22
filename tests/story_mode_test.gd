extends SceneTree
## Story Mode regression, in two parts:
##  1. StoryDirector's phase machine, tested directly with no scene loading
##     at all — report_result/begin_intro/resolve's empty-beat skipping.
##     This is where a mistake in story_script.gd's shape (a typo'd key, a
##     forgotten opponent) would actually break something, so it's covered
##     without needing a real fight to reach it.
##  2. One real scene hop (menu -> prologue -> first opponent's intro ->
##     Arena) to check the actual wiring isn't broken, since #1 alone
##     wouldn't catch a mistyped scene path or the like.
## Deliberately doesn't chain multiple fights through real scene changes —
## seven rapid-fire change_scene_to_file calls in a row (as a full Arcade
## run would need) triggers what looks like an engine-level hang under this
## harness's synchronous test-driven pacing (not seen invoking these one at
## a time), so the phase logic and the scene wiring are checked separately.
var failures: Array[String] = []
const ROSTER := preload("res://scripts/fighter_roster.gd")
const STORY := preload("res://scripts/story_script.gd")

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _is_scene(suffix: String) -> bool:
	return is_instance_valid(current_scene) and current_scene.get_script() != null \
		and current_scene.get_script().resource_path.ends_with(suffix)

func _wait_for_scene(suffix: String) -> void:
	var guard := 0
	while not _is_scene(suffix) and guard < 180:
		await process_frame
		guard += 1
	check(_is_scene(suffix), "Scene became " + suffix + " within 3s")

func _test_phase_machine() -> void:
	var director: Node = root.get_node("StoryDirector")
	var setup: Node = root.get_node("MatchSetup")
	setup.selected_fighters.assign([0, 1])
	setup.arcade_opponents.assign([1, 2, 3, 4, 5, 6])
	setup.arcade_index = 0

	director.start_run()
	check(director.phase == director.Phase.PROLOGUE, "start_run begins on the prologue")

	# A win that isn't the final boss shows a victory beat.
	director.report_result("ish", true, false)
	check(director.phase == director.Phase.VICTORY, "A non-boss win shows the victory beat")
	check(director.opponent_id == "ish", "report_result records who was fought")

	# A loss (boss or not) always shows the defeat beat, never the finale.
	director.report_result("anant", false, true)
	check(director.phase == director.Phase.DEFEAT, "A loss never counts as the finale, even against Anant")

	# Only a WIN over the final boss triggers the finale.
	director.report_result("anant", true, true)
	check(director.phase == director.Phase.FINALE, "Beating Anant shows the finale")

	# resolve() must skip forward through every beat story_script.gd left
	# empty and land on a real destination.
	director.begin_intro("sup")
	check(STORY.CHAPTERS.sup.defeat.is_empty(), "This check assumes sup's defeat beat is still empty in story_script.gd")
	director.phase = director.Phase.DEFEAT
	director.opponent_id = "sup"
	check(director.resolve() == director.Destination.ARENA, "An empty defeat beat resolves straight to the fight")

	director.opponent_id = "anant"
	director.phase = director.Phase.DEFEAT
	check(not STORY.CHAPTERS.anant.defeat.is_empty(), "This check assumes Anant's defeat beat has text in story_script.gd")
	check(director.resolve() == director.Destination.DIALOGUE, "A written defeat beat resolves to dialogue, not straight to the fight")

	director.phase = director.Phase.FINALE
	if STORY.FINALE.is_empty():
		check(director.resolve() == director.Destination.MENU, "An empty finale resolves straight to the menu")
	else:
		check(director.resolve() == director.Destination.DIALOGUE, "A written finale resolves to dialogue")

	# begin_intro/resolve is what PROLOGUE/VICTORY hand off to once their own
	# (non-empty) beat has been read: the *current* opponent's intro.
	setup.selected_fighters[1] = 1
	director.begin_intro(ROSTER.profile(1).id)
	check(director.phase == director.Phase.INTRO, "begin_intro sets the intro phase")
	check(director.opponent_id == ROSTER.profile(1).id, "...for whichever opponent MatchSetup currently points at")
	check(not STORY.CHAPTERS[ROSTER.profile(1).id].intro.is_empty(), "This check assumes that fighter's intro has text in story_script.gd")
	check(director.resolve() == director.Destination.DIALOGUE, "A written intro resolves to dialogue")

func _run() -> void:
	_test_phase_machine()

	# One real hop through the actual scenes, matching what a player sees
	# starting a run: menu -> prologue -> first opponent's intro -> fight.
	var setup: Node = root.get_node("MatchSetup")
	var director: Node = root.get_node("StoryDirector")
	setup.selected_fighters.assign([0, 1])
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	setup.story = true
	setup.arcade = true
	setup.vs_ai = true
	menu._start_fight()
	await _wait_for_scene("character_select.gd")
	current_scene.ready_players.assign([true, true])
	current_scene._start_match()
	await _wait_for_scene("story_dialogue.gd")
	check(director.phase == director.Phase.PROLOGUE, "A fresh run opens on the prologue")
	var dialogue: Node = current_scene
	check(not dialogue.lines.is_empty(), "StoryDialogue is only ever opened with something to show")

	var guard := 0
	while _is_scene("story_dialogue.gd") and guard < 40:
		current_scene._next_line()
		guard += 1
		await process_frame
	check(guard < 40, "Clicking through the prologue and first intro reaches the fight within 40 lines")
	await _wait_for_scene("arena_3d.gd")
	check(ROSTER.profile(setup.selected_fighters[1]).id == ROSTER.profile(setup.arcade_opponents[0]).id, "The fight that starts is against the first arcade opponent")

	print("STORY_MODE_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
