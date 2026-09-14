extends SceneTree
const ROSTER := preload("res://scripts/fighter_roster.gd")
var failures: Array[String] = []
var arena: Node
var p1: Node
var p2: Node
var capture := false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func reset(a: int, b: int) -> void:
	p1.apply_character(a)
	p2.apply_character(b)
	p1.reset_for_new_round()
	p2.reset_for_new_round()
	p1.position = Vector2(400, 450)
	p2.position = Vector2(451, 450)
	p1.facing = 1
	p2.facing = -1

func snap(name: String) -> void:
	if capture and DisplayServer.get_name() != "headless":
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/action-" + name + ".png")

func run() -> void:
	var setup: Node = root.get_node("MatchSetup")
	setup.arcade = false
	setup.vs_ai = false
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu._show_roster()
	await process_frame
	var pickers: Array[Node] = menu.modal_content.find_children("*", "OptionButton", true, false)
	check(pickers.size() == 2 and pickers[0].item_count == 7, "Both players can select all seven fighters")
	pickers[0].item_selected.emit(5)
	pickers[1].item_selected.emit(6)
	check(setup.selected_fighters == [5, 6], "Roster controls persist independent choices")
	await snap("roster")
	menu.queue_free()
	await process_frame
	arena = load("res://scenes/Arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.set_process(false)
	arena.intro_timer = 0
	arena._hide_banner()
	p1 = arena.player1
	p2 = arena.player2
	for i in 8:
		await physics_frame
		await process_frame
	p1.set_physics_process(false)
	p2.set_physics_process(false)
	check(p1.is_on_floor() and p2.is_on_floor(), "Test fighters are grounded")
	for i in 7:
		reset(i, 6)
		check(p1.max_health == 100, "Every fighter including boss has 100 health")
		var moves: Dictionary = p1.available_moves()
		for key in moves:
			p1.reset_for_new_round()
			p2.reset_for_new_round()
			var initial: float = p1.stamina
			p1._start_style_move(key)
			check(not p1.current_move.is_empty(), "Every roster move starts: %s / %s" % [i, key])
			check(p1.stamina == initial - moves[key].cost, "Each move charges stamina once")
			check(moves[key].recovery > 0.0, "Every attack has recovery")
			p1._process_attack(p1.attack_startup())
			for frame in 4:
				await physics_frame
				await process_frame
			check(p2.health < 100 if moves[key].get("utility", "").is_empty() else p2.health == 100, "Real hitboxes match strike or utility: %s / %s" % [i, key])
		p1.reset_for_new_round()
		p1.stamina = 0
		p1._start_style_move("drive")
		check(p1.state == p1.State.IDLE, "Exhaustion denies expensive attacks")
		p1._physics_process(0.2)
		check(p1.stamina > 0, "Rest restores stamina")
		# Every fighter can damage Anant; no boss immunity or inflated HP.
		p1.reset_for_new_round()
		p2.reset_for_new_round()
		p1._start_style_move("jab")
		p2.take_hit(p1.punch_damage, 0, 1, p1)
		check(p2.health < 100, "Every fighter can hurt Anant")
		p1.reset_for_new_round()
		p2.reset_for_new_round()
		p1.position = Vector2(330, 450)
		p2.position = Vector2(680, 450)
		arena.get_node("UI/P1Label").text = "P1 / " + p1.character_profile.name
		p1._start_style_move("drive")
		p1.attack_timer = p1.attack_startup()
		p1._update_animation()
		await snap(ROSTER.profile(i).id)
	reset(2, 0)
	p1._start_style_move("forward_heavy")
	p2.state = p2.State.BLOCK
	p2.block_hold_time = 1
	check(p2.take_hit(20, 100, 1, p1) and p2.health == 80, "Sab grab beats held guard")
	reset(2, 0)
	p1._start_style_move("forward_heavy")
	p2.throw_tech_until = p2.combat_time + 0.16
	check(not p2.take_hit(20, 100, 1, p1) and p2.health == 100, "Timed escape stops a grab")
	reset(5, 1)
	p1._start_style_move("kick")
	p2.take_hit(12, 0, 1, p1, "kick")
	check(p2.health == 85, "Ish takes 25 percent extra low-strike damage")
	reset(0, 4)
	p1._start_style_move("jab")
	p2.state = p2.State.BLOCK
	p2.block_hold_time = 1
	p2.stamina = 0
	p2.take_hit(10, 0, 1, p1)
	check(p2.state == p2.State.HITSTUN and p2.stun_timer >= 0.55, "Empty guard breaks and can be punished")
	reset(4, 0)
	p1.stamina = 20
	p1._start_style_move("back_heavy")
	p1._process_attack(p1.attack_duration() + 0.01)
	check(p1.stamina == 44, "Completed taunt recovers stamina")
	p1._start_style_move("back_heavy")
	check(p1.state == p1.State.IDLE, "Taunt cooldown prevents repeated recovery")
	reset(4, 0)
	p1.stamina = 20
	p1._start_style_move("back_heavy")
	p1._process_attack(0.24)
	check(not p1.hitbox.active, "Taunt never creates an attacking hitbox")
	p1.take_hit(10, 0, -1, p2)
	check(p1.stamina == 20 and p1.state == p1.State.HITSTUN, "Interrupting a taunt prevents recovery")
	for round_index in 4:
		arena._begin_round(round_index)
		check(p1.is_action_fight() and p1.character_profile.id == "abhi", "Fighter and action moves persist all four rounds")
		check(p1.stamina == p1.character_profile.stamina, "Round reset replenishes stamina")
		arena.intro_timer = 0
		arena._hide_banner()
		arena._end_round(1)
	check(arena.match_over, "Match finishes after exactly four rounds")
	setup.arcade = true
	setup.selected_fighters[0] = 0
	setup.begin_arcade()
	check(setup.arcade_opponents == [1, 2, 3, 4, 5, 6], "Arcade excludes chosen fighter and ends with Anant")
	arena.round_wins = [3, 1]
	arena._start_new_match()
	await create_timer(0.15).timeout
	arena = current_scene
	check(setup.arcade_index == 1 and arena.player2.character_index == 2, "Winning advances to the next actual opponent")
	arena.round_wins = [1, 3]
	arena._start_new_match()
	await create_timer(0.15).timeout
	check(setup.arcade_index == 1, "Losing retries the current rival")
	setup.arcade_index = setup.arcade_opponents.size() - 1
	check(setup.is_final_boss(), "Anant is identified as the final boss")
	print("ACTION_ROSTER_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
