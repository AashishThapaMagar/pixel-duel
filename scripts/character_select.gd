extends Control
const ROSTER := preload("res://scripts/fighter_roster.gd")
const PLAYER := preload("res://scenes/Player.tscn")
var selections: Array[int] = [0, 1]
var ready_players: Array[bool] = [false, false]
var previews: Array[Node] = []
var cards: Array[Button] = []
var markers: Array[Label] = []
var selectors: Array[OptionButton] = []
var ready_buttons: Array[Button] = []
var start_button: Button
var editing_player: int = 0

func _ready() -> void:
	selections.assign(MatchSetup.selected_fighters)
	var background := ColorRect.new()
	background.color = Color("101622")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_label("CHOOSE YOUR FIGHTER", Vector2(32, 25), Vector2(700, 44), 32, Color("f1e7d5"))
	_label("4 ORIGINAL FIGHTERS  /  4 DISCIPLINES  /  ONE MATCH", Vector2(34, 74), Vector2(850, 22), 13, Color("98a9bd"))
	var back := _button("BACK", Vector2(830, 33), Vector2(96, 34))
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	for i in ROSTER.PROFILES.size():
		var profile: Dictionary = ROSTER.profile(i)
		var x := 32.0 + i * 226.0
		var card := _button("", Vector2(x, 113), Vector2(218, 282))
		card.pressed.connect(_choose.bind(i))
		cards.append(card)
		_label(profile.name, Vector2(x + 14, 131), Vector2(185, 32), 24, profile.accent)
		_label(profile.title, Vector2(x + 14, 165), Vector2(195, 22), 12, Color("d0d9e4"))
		var preview := PLAYER.instantiate()
		add_child(preview)
		preview.set_physics_process(false)
		preview.collision_layer = 0
		preview.hurtbox.collision_layer = 0
		preview.position = Vector2(x + 105, 345)
		preview.scale = Vector2.ONE * 1.15
		preview.apply_character(i)
		preview.apply_style(load("res://resources/styles/karate.tres"))
		preview._update_animation()
		previews.append(preview)
		var trait_label := _label(profile.trait, Vector2(x + 12, 360), Vector2(192, 30), 11, Color("a6b7c9"))
		trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		markers.append(_label("", Vector2(x + 144, 119), Vector2(70, 20), 12, Color("f6d275")))
	for player in 2:
		var x := 32.0 if player == 0 else 642.0
		var color := Color("71b2ff") if player == 0 else Color("ff8a83")
		_label("PLAYER " + str(player + 1), Vector2(x, 410), Vector2(250, 20), 13, color)
		var selector := OptionButton.new()
		selector.position = Vector2(x, 436)
		selector.size = Vector2(157, 36)
		selector.focus_mode = Control.FOCUS_NONE
		for profile in ROSTER.PROFILES:
			selector.add_item(profile.name)
		selector.item_selected.connect(_select_for_player.bind(player))
		selector.pressed.connect(func(): editing_player = player)
		add_child(selector)
		selectors.append(selector)
		var ready_button := _button("READY", Vector2(x + 165, 436), Vector2(115, 36))
		ready_button.pressed.connect(_toggle_ready.bind(player))
		ready_buttons.append(ready_button)
	start_button = _button("START MATCH", Vector2(360, 424), Vector2(240, 48))
	start_button.pressed.connect(_start_match)
	_label("P1: A / D select, F ready     |     P2: Left / Right select, K ready     |     Enter: start     |     Esc: back", Vector2(32, 505), Vector2(904, 24), 12, Color("98a9bd"))
	_refresh()

func _label(text: String, pos: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _button(text: String, pos: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = dimensions
	button.focus_mode = Control.FOCUS_NONE
	add_child(button)
	return button

func _choose(index: int) -> void:
	_select_for_player(index, editing_player)

func _select_for_player(index: int, player: int) -> void:
	selections[player] = posmod(index, ROSTER.PROFILES.size())
	ready_players[player] = false
	editing_player = player
	_refresh()

func _toggle_ready(player: int) -> void:
	ready_players[player] = not ready_players[player]
	editing_player = 1 - player
	_refresh()

func _refresh() -> void:
	for i in cards.size():
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color("1b2637")
		panel.border_color = Color("354255")
		panel.set_border_width_all(1)
		panel.set_corner_radius_all(8)
		markers[i].text = ""
		for player in 2:
			if selections[player] == i:
				markers[i].text += "P%d " % (player + 1)
				panel.border_color = Color("71b2ff") if player == 0 else Color("ff8a83")
				panel.set_border_width_all(2)
		cards[i].add_theme_stylebox_override("normal", panel)
	for player in 2:
		selectors[player].select(selections[player])
		ready_buttons[player].text = "READY ✓" if ready_players[player] else "READY"
	start_button.disabled = not (ready_players[0] and ready_players[1])

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
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
	if not (ready_players[0] and ready_players[1]):
		return
	MatchSetup.selected_fighters.assign(selections)
	get_tree().change_scene_to_file("res://scenes/Arena.tscn")
