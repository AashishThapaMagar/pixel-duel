extends Node2D
## Match/round manager: wires the two fighters together, drives the round
## timer, shows health bars, and handles round-over / restart.
##
## A match is four rounds, each fought under a different FightStyle (Karate,
## Muay Thai, Boxing, Freestyle MMA — see scripts/fight_style.gd), applied to
## BOTH fighters so it's a fair fight under that round's rules. Each round
## opens with a style banner, and whoever wins the most of the four rounds
## wins the match; round wins show as pips next to each health bar.

const KARATE := preload("res://resources/styles/karate.tres")
const MUAY_THAI := preload("res://resources/styles/muay_thai.tres")
const BOXING := preload("res://resources/styles/boxing.tres")
const MMA := preload("res://resources/styles/mma.tres")

@onready var player1: CharacterBody2D = $Player1
@onready var player2: CharacterBody2D = $Player2
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

var round_styles: Array = [KARATE, MUAY_THAI, BOXING, MMA]
var round_index: int = 0          # 0-based into round_styles
var round_wins: Array = [0, 0]    # [player1 wins, player2 wins]
var time_remaining: float = ROUND_TIME
var round_active: bool = false
var intro_timer: float = 0.0
var match_over: bool = false

var p1_start_pos: Vector2
var p2_start_pos: Vector2

func _ready() -> void:
	player1.opponent = player2
	player2.opponent = player1
	p1_start_pos = player1.position
	p2_start_pos = player2.position

	health_bar1.max_value = player1.max_health
	health_bar2.max_value = player2.max_health

	player1.health_changed.connect(func(h, mh): health_bar1.value = h)
	player2.health_changed.connect(func(h, mh): health_bar2.value = h)
	player1.ko.connect(func(): _end_round(2))
	player2.ko.connect(func(): _end_round(1))

	result_label.visible = false
	_update_pips()
	_begin_round(0)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		return

	if intro_timer > 0.0:
		intro_timer -= delta
		if intro_timer <= 0.0:
			_hide_banner()
		return

	if round_active:
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

	if winner == 1:
		round_wins[0] += 1
	elif winner == 2:
		round_wins[1] += 1
	_update_pips()

	var style: FightStyle = round_styles[round_index]
	var round_no := round_index + 1
	var winner_text := "DRAW"
	if winner == 1:
		winner_text = "PLAYER 1 WINS"
	elif winner == 2:
		winner_text = "PLAYER 2 WINS"

	if round_no >= round_styles.size():
		match_over = true
		var match_winner := "DRAW"
		if round_wins[0] > round_wins[1]:
			match_winner = "PLAYER 1"
		elif round_wins[1] > round_wins[0]:
			match_winner = "PLAYER 2"
		result_label.text = "ROUND %d (%s): %s\n\n%s WINS THE MATCH %d-%d\nPress R for a new match" % [
			round_no, style.display_name.to_upper(), winner_text, match_winner, round_wins[0], round_wins[1]
		]
	else:
		result_label.text = "ROUND %d (%s): %s\nPress R for Round %d" % [
			round_no, style.display_name.to_upper(), winner_text, round_no + 1
		]

	result_label.visible = true

func _start_new_match() -> void:
	round_wins = [0, 0]
	match_over = false
	_update_pips()
	_begin_round(0)

func _begin_round(index: int) -> void:
	round_index = index
	var fight_style: FightStyle = round_styles[index]

	player1.position = p1_start_pos
	player2.position = p2_start_pos
	player1.apply_style(fight_style)
	player2.apply_style(fight_style)
	player1.reset_for_new_round()
	player2.reset_for_new_round()

	time_remaining = ROUND_TIME
	round_label.text = "ROUND %d / %d" % [index + 1, round_styles.size()]
	result_label.visible = false
	round_active = false

	# Freeze both fighters while the style banner is up so nobody gets a
	# cheap first hit in during the intro.
	player1.set_physics_process(false)
	player2.set_physics_process(false)

	_show_banner(index, fight_style)

func _show_banner(index: int, fight_style: FightStyle) -> void:
	banner_round.text = "ROUND %d" % (index + 1)
	banner_name.text = fight_style.display_name.to_upper()
	banner_name.modulate = fight_style.accent_color
	banner_tagline.text = fight_style.tagline
	banner.visible = true
	intro_timer = INTRO_TIME

func _hide_banner() -> void:
	banner.visible = false
	player1.set_physics_process(true)
	player2.set_physics_process(true)
	round_active = true

func _update_pips() -> void:
	var total := round_styles.size()
	var p1_text := ""
	var p2_text := ""
	for i in total:
		p1_text += "●" if i < round_wins[0] else "○"
		p2_text += "●" if i < round_wins[1] else "○"
	pips1.text = p1_text
	pips2.text = p2_text
