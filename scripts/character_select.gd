extends Control
const ROSTER := preload("res://scripts/fighter_roster.gd")
const PLAYER := preload("res://scenes/Player.tscn")
const UI := preload("res://scripts/ui_kit.gd")
var selections: Array[int] = [0, 1]
var ready_players: Array[bool] = [false, false]
var previews: Array[Node] = []
var cards: Array[Button] = []
var markers: Array[Label] = []
var selectors: Array[OptionButton] = []
var ready_buttons: Array[Button] = []
var player_tabs: Array[Button] = []
var start_button: Button
var status_label: Label
var editing_player: int = 0
var transitioning: bool = false

func _ready() -> void:
	theme = UI.theme()
	selections.assign(MatchSetup.selected_fighters)
	add_child(preload("res://scripts/menu_backdrop.gd").new())
	UI.label(self, "W / W", Vector2(32, 19), Vector2(70, 28), 22, UI.LIME)
	UI.label(self, "01  SELECT     /     02  LOCK IN     /     03  FIGHT", Vector2(114, 25), Vector2(630, 22), 12, UI.MUTED)
	UI.button(self, "BACK / ESC", Vector2(814, 18), Vector2(114, 32)).pressed.connect(_back)
	UI.label(self, "PICK YOUR SIDE.", Vector2(30, 72), Vector2(660, 45), 34)
	status_label = UI.label(self, "", Vector2(34, 120), Vector2(890, 22), 12, UI.LIME)
	for i in ROSTER.PROFILES.size():
		var profile: Dictionary = ROSTER.profile(i)
		var x := 32.0 + i * 226.0
		var card := UI.button(self, "", Vector2(x, 157), Vector2(218, 235))
		card.focus_mode = Control.FOCUS_NONE
		card.pressed.connect(_choose.bind(i))
		cards.append(card)
		UI.label(self, profile.name, Vector2(x + 14, 174), Vector2(160, 30), 24)
		UI.label(self, profile.title, Vector2(x + 14, 207), Vector2(195, 20), 11, UI.MUTED)
		var preview := PLAYER.instantiate()
		add_child(preview)
		preview.set_physics_process(false)
		preview.controls_enabled = false
		preview.collision_layer = 0
		preview.hurtbox.collision_layer = 0
		preview.position = Vector2(x + 108, 354)
		preview.scale = Vector2.ONE * 1.04
		preview.apply_character(i)
		preview.apply_style(load("res://resources/styles/karate.tres"))
		preview._update_animation()
		previews.append(preview)
		var trait_label := UI.label(self, profile.trait, Vector2(x + 12, 359), Vector2(194, 29), 10, UI.MUTED)
		trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		markers.append(UI.label(self, "", Vector2(x + 142, 162), Vector2(70, 20), 11, UI.LIME))
	for player in 2:
		var x := 32.0 if player == 0 else 642.0
		var tab := UI.button(self, "P%d / SELECTING" % (player + 1), Vector2(x, 402), Vector2(280, 27))
		tab.add_theme_font_size_override("font_size", 11)
		tab.focus_mode = Control.FOCUS_NONE
		tab.pressed.connect(func():
			editing_player = player
			_refresh())
		player_tabs.append(tab)
		var selector := OptionButton.new()
		selector.position = Vector2(x, 437)
		selector.size = Vector2(151, 36)
		selector.focus_mode = Control.FOCUS_NONE
		selector.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for profile in ROSTER.PROFILES:
			selector.add_item(profile.name)
		selector.item_selected.connect(_select_for_player.bind(player))
		selector.pressed.connect(func(): editing_player = player)
		add_child(selector)
		selectors.append(selector)
		var ready_button := UI.button(self, "LOCK IN", Vector2(x + 159, 437), Vector2(121, 36))
		ready_button.focus_mode = Control.FOCUS_NONE
		ready_button.pressed.connect(_toggle_ready.bind(player))
		ready_buttons.append(ready_button)
	start_button = UI.button(self, "FIGHT  /  ENTER  >", Vector2(344, 431), Vector2(272, 42), true)
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.pressed.connect(_start_match)
	UI.label(self, "LOCAL VERSUS / 4 ROUNDS", Vector2(366, 404), Vector2(245, 20), 11, UI.MUTED)
	UI.label(self, "P1   A / D  select    F  lock in", Vector2(34, 501), Vector2(325, 24), 12, UI.LIME)
	UI.label(self, "P2   Left / Right  select    K  lock in", Vector2(360, 501), Vector2(370, 24), 12, UI.VIOLET)
	UI.label(self, "ENTER   Start match", Vector2(784, 501), Vector2(160, 24), 12, UI.MUTED)
	_refresh()
	UI.enter(self)

func _back() -> void:
	if not transitioning:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _choose(index: int) -> void:
	_select_for_player(index, editing_player)

func _select_for_player(index: int, player: int) -> void:
	if transitioning:
		return
	selections[player] = posmod(index, ROSTER.PROFILES.size())
	ready_players[player] = false
	editing_player = player
	_refresh()

func _toggle_ready(player: int) -> void:
	if transitioning:
		return
	ready_players[player] = not ready_players[player]
	editing_player = 1 - player
	_refresh()

func _refresh() -> void:
	for i in cards.size():
		var border := UI.LINE
		var selected := false
		markers[i].text = ""
		for player in 2:
			if selections[player] == i:
				markers[i].text += "P%d " % (player + 1)
				border = UI.LIME if player == 0 else UI.VIOLET
				selected = true
		if selections[0] == i and selections[1] == i:
			border = UI.WHITE
		markers[i].add_theme_color_override("font_color", border)
		cards[i].add_theme_stylebox_override("normal", UI.box(Color("202735") if selected else UI.PANEL, border, 2 if selected else 1))
		previews[i].modulate = Color.WHITE if selected else Color(0.65, 0.68, 0.75)
	for player in 2:
		var color := UI.LIME if player == 0 else UI.VIOLET
		selectors[player].select(selections[player])
		ready_buttons[player].text = "LOCKED / OK" if ready_players[player] else "LOCK IN"
		ready_buttons[player].add_theme_stylebox_override("normal", UI.box(Color("29352b") if ready_players[player] else UI.PANEL, color))
		ready_buttons[player].add_theme_color_override("font_color", color)
		player_tabs[player].text = "P%d / %s" % [player + 1, "READY" if ready_players[player] else ("SELECTING  >" if editing_player == player else "CLICK TO SELECT")]
		player_tabs[player].add_theme_color_override("font_color", color)
		player_tabs[player].add_theme_stylebox_override("normal", UI.box(UI.PANEL, color if editing_player == player else UI.LINE))
	start_button.disabled = not (ready_players[0] and ready_players[1])
	status_label.text = "BOTH FIGHTERS LOCKED. THE ARENA IS YOURS." if not start_button.disabled else "SELECTING FOR P%d  /  Choose a fighter, then lock in. Both players must be ready." % (editing_player + 1)

func _input(event: InputEvent) -> void:
	if transitioning or (event is InputEventKey and event.echo):
		return
	for selector in selectors:
		if selector.get_popup().visible:
			return
	if event.is_action_pressed("ui_cancel"):
		_back()
		return
	for player in 2:
		var prefix := "p1_" if player == 0 else "p2_"
		if event.is_action_pressed(prefix + "left"):
			_select_for_player(selections[player] - 1, player)
		elif event.is_action_pressed(prefix + "right"):
			_select_for_player(selections[player] + 1, player)
		elif event.is_action_pressed(prefix + "punch"):
			_toggle_ready(player)
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ENTER:
		_start_match()

func _start_match() -> void:
	if transitioning or not (ready_players[0] and ready_players[1]):
		return
	transitioning = true
	MatchSetup.selected_fighters.assign(selections)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/Arena3D.tscn"))
