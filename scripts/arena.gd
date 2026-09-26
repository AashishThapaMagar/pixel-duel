extends Node2D
## Match/round manager: wires the two fighters together, drives the round
## timer, shows health bars, and handles round-over / restart.
##
## Four rounds retain each fighter's action moveset. Most round wins takes
## the match. Arcade victories advance through the roster to Anant.

const ACTION := preload("res://resources/styles/action.tres")
const MOVES := preload("res://scripts/move_catalog.gd")
const ARENAS := preload("res://scripts/arena_catalog.gd")
const AI_CONTROLLER := preload("res://scripts/ai_controller.gd")
const ROSTER := preload("res://scripts/fighter_roster.gd")

@onready var player1: CharacterBody2D = $Player1
@onready var player2: CharacterBody2D = $Player2
@onready var background: Sprite2D = $Background
@onready var ground: Node2D = $Ground
@onready var health_bar1: ProgressBar = $UI/HealthBar1
@onready var health_bar2: ProgressBar = $UI/HealthBar2
@onready var timer_label: Label = $UI/TimerLabel
@onready var result_label: Label = $UI/ResultLabel
@onready var round_label: Label = $UI/RoundLabel
@onready var pips1: Label = $UI/Pips1
@onready var pips2: Label = $UI/Pips2
@onready var banner: Control = $UI/StyleBanner
@onready var banner_round: Label = $UI/StyleBanner/BannerRound
@onready var banner_name: Label = $UI/StyleBanner/BannerName
@onready var banner_tagline: Label = $UI/StyleBanner/BannerTagline

const ROUND_TIME := 99.0
const INTRO_TIME := 2.2

var round_styles: Array = [ACTION, ACTION, ACTION, ACTION]
var round_index: int = 0          # 0-based into round_styles
var round_wins: Array = [0, 0]    # [player1 wins, player2 wins]
var time_remaining: float = ROUND_TIME
var round_active: bool = false
var intro_timer: float = 0.0
var match_over: bool = false
## Seconds the round winner is shown before the next round starts itself.
const ROUND_PAUSE := 2.2
var advance_timer := 0.0

var p1_start_pos: Vector2
var p2_start_pos: Vector2
var combat_effects: Node2D
var ai_controller: Node
var move_guide: PanelContainer
var guide_title: Label
var guide_text: Label
var combo_labels: Array[Label] = []
var _resume_physics: Array[bool] = [false, false]

func _ready() -> void:
	var arena_data: Dictionary = ARENAS.arena(MatchSetup.selected_arena)
	background.texture = load(arena_data.texture)
	background.scale = Vector2(960.0, 540.0) / background.texture.get_size()
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# The painting supplies the visible terrace; collision stays at y=450.
	$Ground/GroundVisual.hide()
	$Ground/GroundLip.hide()
	ground.modulate = arena_data.ground_tint
	var ambience := preload("res://scripts/arena_ambience.gd").new()
	ambience.name = "ArenaAmbience"
	ambience.arena_index = MatchSetup.selected_arena
	add_child(ambience)
	move_child(ambience, background.get_index() + 1)

	player1.opponent = player2
	player2.opponent = player1
	p1_start_pos = player1.position
	p2_start_pos = player2.position
	player1.apply_character(MatchSetup.selected_fighters[0])
	player2.apply_character(MatchSetup.selected_fighters[1])
	$UI/P1Label.text = "P1 / " + player1.character_profile.name
	$UI/P2Label.text = "P2 / " + player2.character_profile.name + (" · AI" if MatchSetup.vs_ai else "")

	if MatchSetup.vs_ai:
		ai_controller = AI_CONTROLLER.new()
		ai_controller.fighter = player2
		ai_controller.opponent = player1
		add_child(ai_controller)
	combat_effects = Node2D.new()
	combat_effects.set_script(preload("res://scripts/combat_effects.gd"))
	combat_effects.z_index = 2
	add_child(combat_effects)
	combat_effects.fighters = [player1, player2]
	combat_effects.camera = $Camera2D
	player1.impact.connect(combat_effects.add_impact)
	player2.impact.connect(combat_effects.add_impact)

	health_bar1.max_value = player1.max_health
	health_bar2.max_value = player2.max_health

	player1.health_changed.connect(func(h, mh): health_bar1.value = h)
	player2.health_changed.connect(func(h, mh): health_bar2.value = h)
	player1.ko.connect(func(): _end_round(2))
	player2.ko.connect(func(): _end_round(1))
	_build_move_ui()
	add_child(preload("res://scripts/match_hud.gd").new())
	# Only instantiated when the player has opted in (see settings.gd); it
	# lays itself out for 1 or 2 touch players on its own in _ready().
	if Settings.touch_controls:
		add_child(preload("res://scripts/touch_controls.gd").new())

	result_label.visible = false
	_update_pips()
	_begin_round(0)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("move_list"):
		_toggle_move_guide()
	if Input.is_action_just_pressed("ui_cancel"):
		if move_guide.visible:
			_toggle_move_guide()
			return
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		return
	_update_combo_ui()
	if move_guide.visible:
		return

	if intro_timer > 0.0:
		intro_timer -= delta
		if intro_timer <= 0.0:
			_hide_banner()
		return

	if round_active:
		if player1.hitstop_remaining > 0.0 or player2.hitstop_remaining > 0.0:
			return
		time_remaining = max(0.0, time_remaining - delta)
		timer_label.text = str(int(ceil(time_remaining)))
		if time_remaining <= 0.0:
			_time_up()
	else:
		if Input.is_action_just_pressed("restart"):
			if match_over:
				_start_new_match()
			else:
				_begin_round(round_index + 1)
		elif not match_over and advance_timer > 0.0:
			# Rounds flow into each other: winner callout, then ROUND N.
			advance_timer -= delta
			if advance_timer <= 0.0:
				_begin_round(round_index + 1)

func _time_up() -> void:
	if player1.health == player2.health:
		_end_round(0)
	elif player1.health > player2.health:
		_end_round(1)
	else:
		_end_round(2)

# winner: 0 = draw, 1 = player1, 2 = player2
func _end_round(winner: int) -> void:
	if not round_active:
		return
	round_active = false
	for fighter in [player1, player2]:
		fighter.controls_enabled = false
		fighter.hitbox.set_active(false)
		if fighter.state != fighter.State.KO:
			fighter.state = fighter.State.IDLE

	if winner == 1:
		round_wins[0] += 1
	elif winner == 2:
		round_wins[1] += 1
	_update_pips()

	var round_no := round_index + 1
	var winner_text := "DRAW"
	if winner == 1:
		winner_text = "%s WINS" % player1.character_profile.name
	elif winner == 2:
		winner_text = "%s WINS" % player2.character_profile.name

	if round_no >= round_styles.size():
		match_over = true
		var match_winner := "DRAW"
		if round_wins[0] > round_wins[1]:
			match_winner = player1.character_profile.name
		elif round_wins[1] > round_wins[0]:
			match_winner = player2.character_profile.name
		result_label.text = "MATCH DRAW" if match_winner == "DRAW" else match_winner + " TAKES THE MATCH"
	else:
		result_label.text = winner_text
		advance_timer = ROUND_PAUSE

	result_label.visible = true

func _start_new_match() -> void:
	if MatchSetup.arcade:
		# A win advances to the next rival (or restarts the run fresh after
		# beating Anant); a loss or draw retries the same rival unchanged.
		# The scene reload re-reads MatchSetup's updated fighters/arena.
		var won: bool = round_wins[0] > round_wins[1]
		var was_final_boss: bool = MatchSetup.is_final_boss()
		# Captured before selected_fighters[1] advances below, so it still
		# names the rival this match was actually against.
		var opponent_id: String = ROSTER.profile(MatchSetup.selected_fighters[1]).id
		if won:
			if was_final_boss:
				# Story mode shows the finale before resetting the run; plain
				# Arcade just starts a fresh one immediately.
				if not MatchSetup.story:
					MatchSetup.begin_arcade()
			else:
				MatchSetup.arcade_index += 1
				MatchSetup.selected_fighters[1] = MatchSetup.arcade_opponents[MatchSetup.arcade_index]
				MatchSetup.selected_arena = (MatchSetup.selected_arena + 1) % ARENAS.ARENAS.size()
		if MatchSetup.story:
			StoryDirector.report_result(opponent_id, won, was_final_boss)
			# Resolved here, before ever opening StoryDialogue, so that scene
			# only ever has to open on something to actually say (see its
			# _ready() comment for why resolving from inside it is unsafe).
			var destination: int = StoryDirector.resolve()
			if destination == StoryDirector.Destination.ARENA:
				get_tree().reload_current_scene()
			elif destination == StoryDirector.Destination.MENU:
				get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
			else:
				get_tree().change_scene_to_file("res://scenes/StoryDialogue.tscn")
		else:
			get_tree().reload_current_scene()
		return
	round_wins = [0, 0]
	match_over = false
	_update_pips()
	_begin_round(0)

func _begin_round(index: int) -> void:
	combat_effects.reset()
	advance_timer = 0.0
	round_index = index
	var fight_style: FightStyle = round_styles[index]

	player1.position = p1_start_pos
	player2.position = p2_start_pos
	player1.apply_style(fight_style)
	player2.apply_style(fight_style)
	guide_title.text = "ROUND %d / FIGHTER MOVEBOOK" % (index + 1)
	guide_text.text = "STAMINA: strikes and dashes spend it; moving or resting restores it. Empty guard can break.\nTHROWS: jump, interrupt startup, or tap Light + Heavy together within 0.16s before contact.\nISH: low strikes deal +25% damage to his weak knee.\nABHI: Back + Heavy taunts; finish uninterrupted for +24 stamina (5s cooldown).\nSUP: Back + Heavy retreats; it is not invincible.\n\n"
	for fighter in [player1, player2]:
		guide_text.text += "%s / %s\n%s\n\n%s\n\n" % [fighter.character_profile.name, fighter.character_profile.title, fighter.character_profile.trait, MOVES.guide("action", fighter.available_moves())]
	player1.reset_for_new_round()
	player2.reset_for_new_round()

	time_remaining = float(MatchSetup.round_seconds)
	timer_label.text = str(MatchSetup.round_seconds)
	round_label.text = "ROUND %d / %d" % [index + 1, round_styles.size()]
	result_label.visible = false
	round_active = false

	# Freeze both fighters while the style banner is up so nobody gets a
	# cheap first hit in during the intro.
	player1.set_physics_process(false)
	player2.set_physics_process(false)

	_show_banner(index, fight_style)
	var p2_hint := "P2 is AI-controlled" if MatchSetup.vs_ai else "P2   Arrows move/jump   Down guard   K/L attack"
	$UI/ControlsHint.text = "P1   A/D move   W jump   S guard   F/G attack        |        %s\nHOLD SHIFT (P1) / CTRL (P2) TO RUN    /    DOUBLE-TAP DASH    /    F1 MOVES    /    ESC MENU" % p2_hint

func _build_move_ui() -> void:
	for player in 2:
		var label := Label.new()
		label.position = Vector2(40 if player == 0 else 620, 93)
		label.size = Vector2(300, 50)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if player == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("ffe0a4"))
		$UI.add_child(label)
		combo_labels.append(label)
	var moves_button := Button.new()
	moves_button.text = "MOVES [F1]"
	moves_button.position = Vector2(418, 92)
	moves_button.size = Vector2(124, 30)
	moves_button.focus_mode = Control.FOCUS_NONE
	moves_button.pressed.connect(_toggle_move_guide)
	$UI.add_child(moves_button)
	move_guide = PanelContainer.new()
	move_guide.position = Vector2(80, 83)
	move_guide.size = Vector2(800, 425)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("131d2d")
	panel.border_color = Color("8aabc4")
	panel.set_border_width_all(2)
	panel.content_margin_left = 20
	panel.content_margin_right = 20
	panel.content_margin_top = 16
	panel.content_margin_bottom = 16
	move_guide.add_theme_stylebox_override("panel", panel)
	$UI.add_child(move_guide)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	move_guide.add_child(column)
	guide_title = Label.new()
	guide_title.add_theme_font_size_override("font_size", 23)
	column.add_child(guide_title)
	var scroll := ScrollContainer.new()
	scroll.name = "MoveScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	guide_text = Label.new()
	guide_text.add_theme_font_size_override("font_size", 13)
	guide_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(guide_text)
	var close_button := Button.new()
	close_button.text = "RESUME / F1"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_toggle_move_guide)
	column.add_child(close_button)
	move_guide.hide()

func _toggle_move_guide() -> void:
	if move_guide.visible:
		player1.combat_paused = false
		player2.combat_paused = false
		move_guide.hide()
		player1.set_physics_process(_resume_physics[0])
		player2.set_physics_process(_resume_physics[1])
	else:
		_resume_physics.assign([player1.is_physics_processing(), player2.is_physics_processing()])
		player1.combat_paused = true
		player2.combat_paused = true
		player1.set_physics_process(false)
		player2.set_physics_process(false)
		move_guide.show()

func _update_combo_ui() -> void:
	var fighters := [player1, player2]
	for i in 2:
		var fighter: Node = fighters[i]
		var text := ""
		if fighter.state in [fighter.State.PUNCH, fighter.State.KICK]:
			text = fighter.move_name()
		if fighter.combo_hits > 1 and fighter.combat_time - fighter._last_land_time < 1.1:
			text += "\n%d HITS / %d DAMAGE" % [fighter.combo_hits, fighter.combo_damage]
		if fighter.combat_time < fighter.notice_until:
			text += "\n" + fighter.combat_notice
		combo_labels[i].text = text

func _show_banner(index: int, fight_style: FightStyle) -> void:
	banner_round.text = "FINAL ROUND" if index == round_styles.size() - 1 else "ROUND %d" % (index + 1)
	banner_name.text = "%s  VS  %s" % [player1.character_profile.name, player2.character_profile.name]
	banner_name.modulate = fight_style.accent_color
	banner_tagline.text = fight_style.tagline
	if MatchSetup.arcade:
		banner_tagline.text = "FINAL BOSS / ANANTA" if MatchSetup.is_final_boss() else "ARCADE / RIVAL %d OF %d" % [MatchSetup.arcade_index + 1, MatchSetup.arcade_opponents.size()]
	banner.visible = true
	banner.modulate.a = 0.0
	banner.position.x = 106.0
	# The round call slams in large and settles, arcade-style.
	banner_round.pivot_offset = banner_round.size * 0.5
	banner_round.scale = Vector2.ONE * 1.8
	var entrance := create_tween().set_parallel(true)
	entrance.tween_property(banner, "modulate:a", 1.0, 0.15)
	entrance.tween_property(banner, "position:x", 130.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	entrance.tween_property(banner_round, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	preload("res://scripts/sfx.gd").fire("round")
	intro_timer = INTRO_TIME

func _hide_banner() -> void:
	if banner.visible:
		_flash_fight()
	banner.visible = false
	player1.set_physics_process(true)
	player2.set_physics_process(true)
	round_active = true

## "FIGHT!" bursts onto the screen as control is handed to the players.
func _flash_fight() -> void:
	var call := Label.new()
	call.text = "FIGHT!"
	call.position = Vector2(180, 180)
	call.size = Vector2(600, 130)
	call.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	call.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	call.mouse_filter = Control.MOUSE_FILTER_IGNORE
	call.z_index = 6
	call.add_theme_font_override("font", preload("res://scripts/ui_kit.gd").display_font())
	call.add_theme_font_size_override("font_size", 110)
	call.add_theme_color_override("font_color", Color("ffc53d"))
	call.add_theme_color_override("font_shadow_color", Color("d7263d"))
	call.add_theme_constant_override("shadow_offset_x", 5)
	call.add_theme_constant_override("shadow_offset_y", 5)
	call.add_theme_color_override("font_outline_color", Color("07080f"))
	call.add_theme_constant_override("outline_size", 8)
	call.pivot_offset = call.size * 0.5
	call.scale = Vector2.ONE * 0.4
	$UI.add_child(call)
	preload("res://scripts/sfx.gd").fire("fight")
	var burst := call.create_tween()
	burst.tween_property(call, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	burst.tween_interval(0.45)
	burst.parallel().tween_property(call, "modulate:a", 0.0, 0.25).set_delay(0.45)
	burst.parallel().tween_property(call, "scale", Vector2.ONE * 1.25, 0.25).set_delay(0.45)
	burst.tween_callback(call.queue_free)

func _update_pips() -> void:
	var total := round_styles.size()
	var p1_text := ""
	var p2_text := ""
	for i in total:
		p1_text += "●" if i < round_wins[0] else "○"
		p2_text += "●" if i < round_wins[1] else "○"
	pips1.text = p1_text
	pips2.text = p2_text
