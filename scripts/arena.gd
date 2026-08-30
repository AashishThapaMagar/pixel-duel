extends Node2D
## Match/round manager: wires the two fighters together, drives the round
## timer, shows health bars, and handles round-over / restart.

@onready var player1: CharacterBody2D = $Player1
@onready var player2: CharacterBody2D = $Player2
@onready var health_bar1: ProgressBar = $UI/HealthBar1
@onready var health_bar2: ProgressBar = $UI/HealthBar2
@onready var timer_label: Label = $UI/TimerLabel
@onready var result_label: Label = $UI/ResultLabel

var time_remaining: float = 99.0
var round_active: bool = true

var p1_start_pos: Vector2
var p2_start_pos: Vector2

func _ready() -> void:
	player1.opponent = player2
	player2.opponent = player1
	p1_start_pos = player1.position
	p2_start_pos = player2.position

	health_bar1.max_value = player1.max_health
	health_bar2.max_value = player2.max_health
	health_bar1.value = player1.health
	health_bar2.value = player2.health

	player1.health_changed.connect(func(h, mh): health_bar1.value = h)
	player2.health_changed.connect(func(h, mh): health_bar2.value = h)
	player1.ko.connect(func(): _end_round("PLAYER 2 WINS"))
	player2.ko.connect(func(): _end_round("PLAYER 1 WINS"))

	result_label.visible = false

func _process(delta: float) -> void:
	if round_active:
		time_remaining = max(0.0, time_remaining - delta)
		timer_label.text = str(int(ceil(time_remaining)))
		if time_remaining <= 0.0:
			_time_up()
	else:
		if Input.is_action_just_pressed("restart"):
			_start_new_round()

func _time_up() -> void:
	if player1.health == player2.health:
		_end_round("DRAW")
	elif player1.health > player2.health:
		_end_round("PLAYER 1 WINS")
	else:
		_end_round("PLAYER 2 WINS")

func _end_round(text: String) -> void:
	if not round_active:
		return
	round_active = false
	result_label.text = text + "\nPress R to restart"
	result_label.visible = true

func _start_new_round() -> void:
	player1.position = p1_start_pos
	player2.position = p2_start_pos
	player1.reset_for_new_round()
	player2.reset_for_new_round()
	time_remaining = 99.0
	round_active = true
	result_label.visible = false
